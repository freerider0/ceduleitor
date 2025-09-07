import UIKit
import CoreGraphics

// MARK: - Protocols
protocol CADCanvasDataSource: AnyObject {
    func roomGeometry(for canvas: CADCanvasView) -> RoomGeometry
    func isGridEnabled(for canvas: CADCanvasView) -> Bool
    func rooms(for canvas: CADCanvasView) -> [CADRoom]
    func selectedRoom(for canvas: CADCanvasView) -> CADRoom?
    func drawingCorners(for canvas: CADCanvasView) -> [CGPoint]
    func draggedVertexIndex(for canvas: CADCanvasView) -> Int?
}

protocol CADCanvasDelegate: AnyObject {
    func canvasDidUpdateTransform(_ canvas: CADCanvasView)
    func canvas(_ canvas: CADCanvasView, didSelectCornerAt index: Int)
}

// MARK: - Transform Structure
struct CanvasTransform {
    var scale: CGFloat = 1.0
    var offset: CGPoint = .zero
    
    func apply(to point: CGPoint) -> CGPoint {
        return CGPoint(
            x: point.x * scale + offset.x,
            y: point.y * scale + offset.y
        )
    }
    
    func inverse(to point: CGPoint) -> CGPoint {
        return CGPoint(
            x: (point.x - offset.x) / scale,
            y: (point.y - offset.y) / scale
        )
    }
}

// MARK: - CADCanvasView
class CADCanvasView: UIView {
    
    // MARK: - Properties
    weak var dataSource: CADCanvasDataSource?
    weak var delegate: CADCanvasDelegate?
    
    var gridManager: GridManager?
    var selectedCornerIndex: Int?
    
    private(set) var currentTransform = CanvasTransform()
    
    // MARK: - Drawing Properties
    private let cornerRadius: CGFloat = 8
    private let lineWidth: CGFloat = 2
    private let selectedLineWidth: CGFloat = 3
    
    // MARK: - Colors
    private let gridColor = UIColor.systemGray5
    private let wallColor = UIColor.label
    private let cornerColor = UIColor.systemBlue
    private let selectedColor = UIColor.systemOrange
    private let dimensionColor = UIColor.systemGray
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = .systemBackground
        contentMode = .redraw
        gridManager = GridManager(gridSize: 20)
        
        // Optimize drawing performance
        layer.drawsAsynchronously = true
        layer.shouldRasterize = false // Don't cache, we're constantly redrawing
        clearsContextBeforeDrawing = true
        isOpaque = true // Helps performance
    }
    
    // MARK: - Drawing
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Apply transform
        context.saveGState()
        context.translateBy(x: currentTransform.offset.x, y: currentTransform.offset.y)
        context.scaleBy(x: currentTransform.scale, y: currentTransform.scale)
        
        // Draw grid
        if dataSource?.isGridEnabled(for: self) == true {
            drawGrid(in: context, rect: rect)
        }
        
        // Draw all rooms
        if let rooms = dataSource?.rooms(for: self) {
            let selectedRoom = dataSource?.selectedRoom(for: self)
            for room in rooms {
                let isSelected = room === selectedRoom
                drawCADRoom(room, in: context, isSelected: isSelected)
            }
        }
        
        // Draw drawing corners if in drawing mode
        if let drawingCorners = dataSource?.drawingCorners(for: self), !drawingCorners.isEmpty {
            drawDrawingCorners(drawingCorners, in: context)
        }
        
        // Draw old room geometry if still provided (for backward compatibility)
        if let geometry = dataSource?.roomGeometry(for: self) {
            drawRoom(geometry, in: context)
            drawDimensions(geometry, in: context)
            drawCorners(geometry, in: context)
        }
        
        context.restoreGState()
        
        // Draw UI overlays (not affected by transform)
        drawOverlays(in: context, rect: rect)
    }
    
    private func drawGrid(in context: CGContext, rect: CGRect) {
        guard let gridManager = gridManager else { return }
        
        let gridSize = gridManager.gridSize
        let bounds = self.bounds
        
        // Calculate visible grid range
        let startX = Int((-currentTransform.offset.x / currentTransform.scale) / gridSize) * Int(gridSize)
        let endX = Int((bounds.width - currentTransform.offset.x) / currentTransform.scale / gridSize) * Int(gridSize) + Int(gridSize)
        let startY = Int((-currentTransform.offset.y / currentTransform.scale) / gridSize) * Int(gridSize)
        let endY = Int((bounds.height - currentTransform.offset.y) / currentTransform.scale / gridSize) * Int(gridSize) + Int(gridSize)
        
        context.setStrokeColor(gridColor.cgColor)
        context.setLineWidth(0.5 / currentTransform.scale)
        
        // Draw vertical lines
        for x in stride(from: startX, through: endX, by: Int(gridSize)) {
            context.move(to: CGPoint(x: CGFloat(x), y: CGFloat(startY)))
            context.addLine(to: CGPoint(x: CGFloat(x), y: CGFloat(endY)))
        }
        
        // Draw horizontal lines
        for y in stride(from: startY, through: endY, by: Int(gridSize)) {
            context.move(to: CGPoint(x: CGFloat(startX), y: CGFloat(y)))
            context.addLine(to: CGPoint(x: CGFloat(endX), y: CGFloat(y)))
        }
        
        context.strokePath()
        
        // Draw major grid lines
        context.setLineWidth(1.0 / currentTransform.scale)
        context.setStrokeColor(gridColor.withAlphaComponent(0.5).cgColor)
        
        let majorGridSize = gridSize * 5
        for x in stride(from: startX, through: endX, by: Int(majorGridSize)) {
            context.move(to: CGPoint(x: CGFloat(x), y: CGFloat(startY)))
            context.addLine(to: CGPoint(x: CGFloat(x), y: CGFloat(endY)))
        }
        
        for y in stride(from: startY, through: endY, by: Int(majorGridSize)) {
            context.move(to: CGPoint(x: CGFloat(startX), y: CGFloat(y)))
            context.addLine(to: CGPoint(x: CGFloat(endX), y: CGFloat(y)))
        }
        
        context.strokePath()
    }
    
    private func drawRoom(_ geometry: RoomGeometry, in context: CGContext) {
        let corners = geometry.corners2D
        guard corners.count >= 2 else { return }
        
        // Draw walls
        context.setStrokeColor(wallColor.cgColor)
        context.setLineWidth(lineWidth / currentTransform.scale)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        context.beginPath()
        context.move(to: corners[0])
        
        for i in 1..<corners.count {
            context.addLine(to: corners[i])
        }
        
        if geometry.isClosed {
            context.closePath()
            
            // Fill with subtle color
            context.saveGState()
            context.setFillColor(UIColor.systemBlue.withAlphaComponent(0.05).cgColor)
            context.fillPath()
            context.restoreGState()
        }
        
        context.strokePath()
    }
    
    private func drawDimensions(_ geometry: RoomGeometry, in context: CGContext) {
        let corners = geometry.corners2D
        guard corners.count >= 2 else { return }
        
        context.setStrokeColor(dimensionColor.cgColor)
        context.setLineWidth(0.5 / currentTransform.scale)
        
        let font = UIFont.systemFont(ofSize: 12 / currentTransform.scale)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: dimensionColor
        ]
        
        // Draw dimensions for each wall
        for i in 0..<corners.count {
            let start = corners[i]
            let end = corners[(i + 1) % corners.count]
            
            if !geometry.isClosed && i == corners.count - 1 {
                continue
            }
            
            let midPoint = CGPoint(
                x: (start.x + end.x) / 2,
                y: (start.y + end.y) / 2
            )
            
            let distance = hypot(end.x - start.x, end.y - start.y)
            let distanceText = String(format: "%.1f m", distance / 100) // Convert to meters
            
            // Draw dimension text
            let textSize = distanceText.size(withAttributes: attributes)
            let textRect = CGRect(
                x: midPoint.x - textSize.width / 2,
                y: midPoint.y - textSize.height / 2 - 20 / currentTransform.scale,
                width: textSize.width,
                height: textSize.height
            )
            
            // Draw background for text
            context.saveGState()
            context.setFillColor(UIColor.systemBackground.withAlphaComponent(0.8).cgColor)
            context.fill(textRect.insetBy(dx: -2 / currentTransform.scale, dy: -1 / currentTransform.scale))
            context.restoreGState()
            
            // Draw text
            distanceText.draw(in: textRect, withAttributes: attributes)
        }
    }
    
    private func drawCorners(_ geometry: RoomGeometry, in context: CGContext) {
        let corners = geometry.corners2D
        
        for (index, corner) in corners.enumerated() {
            let isSelected = index == selectedCornerIndex
            
            context.setFillColor(isSelected ? selectedColor.cgColor : cornerColor.cgColor)
            
            let radius = (isSelected ? cornerRadius * 1.2 : cornerRadius) / currentTransform.scale
            let cornerRect = CGRect(
                x: corner.x - radius,
                y: corner.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            
            context.fillEllipse(in: cornerRect)
            
            // Draw corner index
            let font = UIFont.boldSystemFont(ofSize: 10 / currentTransform.scale)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white
            ]
            
            let text = "\(index + 1)"
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: corner.x - textSize.width / 2,
                y: corner.y - textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
    
    private func drawCADRoom(_ room: CADRoom, in context: CGContext, isSelected: Bool) {
        let corners = room.transformedCorners
        guard corners.count >= 2 else { return }
        
        // Get the dragged vertex index if this is the selected room
        let draggedIndex = isSelected ? dataSource?.draggedVertexIndex(for: self) : nil
        
        // Set colors based on selection state
        let strokeColor = isSelected ? UIColor.systemOrange : room.type.color
        let fillColor = isSelected ? UIColor.systemOrange.withAlphaComponent(0.1) : room.type.color.withAlphaComponent(0.05)
        
        // Draw filled polygon
        context.saveGState()
        context.setFillColor(fillColor.cgColor)
        context.beginPath()
        context.move(to: corners[0])
        for i in 1..<corners.count {
            context.addLine(to: corners[i])
        }
        context.closePath()
        context.fillPath()
        context.restoreGState()
        
        // Draw edges with enhanced visibility and constraint indicators
        for i in 0..<corners.count {
            let j = (i + 1) % corners.count
            let p1 = corners[i]
            let p2 = corners[j]
            
            // Check if this edge has a constraint
            let hasConstraint = room.edgeConstraints.contains { $0.edgeIndex == i }
            
            // Set edge color based on constraint
            if hasConstraint {
                context.setStrokeColor(UIColor.systemGreen.cgColor)
                context.setLineWidth((isSelected ? 4 : 3) / currentTransform.scale)
            } else {
                context.setStrokeColor(strokeColor.cgColor)
                context.setLineWidth((isSelected ? 3 : 2) / currentTransform.scale)
            }
            
            context.setLineCap(.round)
            context.setLineJoin(.round)
            
            // Draw the edge
            context.beginPath()
            context.move(to: p1)
            context.addLine(to: p2)
            context.strokePath()
            
            // Draw constraint indicator if present
            if hasConstraint, let constraint = room.edgeConstraints.first(where: { $0.edgeIndex == i }) {
                let midPoint = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
                
                // Draw constraint symbol
                let symbolSize: CGFloat = 12 / currentTransform.scale
                let symbolRect = CGRect(
                    x: midPoint.x - symbolSize,
                    y: midPoint.y - symbolSize,
                    width: symbolSize * 2,
                    height: symbolSize * 2
                )
                
                // Background circle
                context.setFillColor(UIColor.systemBackground.cgColor)
                context.fillEllipse(in: symbolRect)
                
                // Constraint type indicator
                context.setStrokeColor(UIColor.systemGreen.cgColor)
                context.setLineWidth(2 / currentTransform.scale)
                context.strokeEllipse(in: symbolRect)
                
                // Draw constraint type symbol
                let font = UIFont.systemFont(ofSize: 10 / currentTransform.scale, weight: .bold)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.systemGreen
                ]
                
                var symbol = ""
                switch constraint.type {
                case .length:
                    symbol = "L"
                case .horizontal:
                    symbol = "H"
                case .vertical:
                    symbol = "V"
                case .perpendicular:
                    symbol = "⊥"
                case .parallel:
                    symbol = "∥"
                default:
                    symbol = "C"
                }
                
                let textSize = symbol.size(withAttributes: attributes)
                let textRect = CGRect(
                    x: midPoint.x - textSize.width / 2,
                    y: midPoint.y - textSize.height / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                
                symbol.draw(in: textRect, withAttributes: attributes)
            }
        }
        
        // Draw vertices
        for (index, corner) in corners.enumerated() {
            let isDragged = draggedIndex == index
            let vertexColor = isDragged ? UIColor.systemGreen : (isSelected ? UIColor.systemOrange : UIColor.systemBlue)
            
            // Draw touch area indicator for selected room
            if isSelected {
                // Draw semi-transparent touch area circle
                let touchRadius: CGFloat = 40 / currentTransform.scale // Match the detection threshold
                let touchAreaRect = CGRect(
                    x: corner.x - touchRadius,
                    y: corner.y - touchRadius,
                    width: touchRadius * 2,
                    height: touchRadius * 2
                )
                
                context.setFillColor(vertexColor.withAlphaComponent(0.1).cgColor)
                context.fillEllipse(in: touchAreaRect)
                
                // Draw touch area border
                context.setStrokeColor(vertexColor.withAlphaComponent(0.2).cgColor)
                context.setLineWidth(1 / currentTransform.scale)
                context.strokeEllipse(in: touchAreaRect)
            }
            
            // Draw the actual vertex
            context.setFillColor(vertexColor.cgColor)
            
            // Make dragged vertex larger
            let baseRadius: CGFloat = isSelected ? 10 : 6
            let radius = (isDragged ? baseRadius * 1.5 : baseRadius) / currentTransform.scale
            let vertexRect = CGRect(
                x: corner.x - radius,
                y: corner.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            
            context.fillEllipse(in: vertexRect)
            
            // Draw white border for all vertices in edit mode
            if isSelected {
                context.setStrokeColor(isDragged ? UIColor.white.cgColor : UIColor.white.withAlphaComponent(0.5).cgColor)
                context.setLineWidth((isDragged ? 3 : 1.5) / currentTransform.scale)
                context.strokeEllipse(in: vertexRect)
            }
            
            // Draw vertex number for selected room
            if isSelected {
                let font = UIFont.boldSystemFont(ofSize: (isDragged ? 12 : 10) / currentTransform.scale)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.white
                ]
                
                let text = "\(index + 1)"
                let textSize = text.size(withAttributes: attributes)
                let textRect = CGRect(
                    x: corner.x - textSize.width / 2,
                    y: corner.y - textSize.height / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                
                text.draw(in: textRect, withAttributes: attributes)
            }
        }
        
        // Draw room name
        if let center = calculateCenter(of: corners) {
            let font = UIFont.systemFont(ofSize: 14 / currentTransform.scale, weight: .medium)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: isSelected ? UIColor.systemOrange : UIColor.label
            ]
            
            let textSize = room.name.size(withAttributes: attributes)
            let textRect = CGRect(
                x: center.x - textSize.width / 2,
                y: center.y - textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            // Draw background for text
            context.saveGState()
            context.setFillColor(UIColor.systemBackground.withAlphaComponent(0.8).cgColor)
            context.fill(textRect.insetBy(dx: -4 / currentTransform.scale, dy: -2 / currentTransform.scale))
            context.restoreGState()
            
            room.name.draw(in: textRect, withAttributes: attributes)
        }
    }
    
    private func drawDrawingCorners(_ corners: [CGPoint], in context: CGContext) {
        guard !corners.isEmpty else { return }
        
        // Draw lines between corners
        context.setStrokeColor(UIColor.systemBlue.cgColor)
        context.setLineWidth(2 / currentTransform.scale)
        context.setLineDash(phase: 0, lengths: [5 / currentTransform.scale, 5 / currentTransform.scale])
        
        context.beginPath()
        context.move(to: corners[0])
        for i in 1..<corners.count {
            context.addLine(to: corners[i])
        }
        
        // Draw dashed line to first corner if we have 3+ corners (to show potential closure)
        if corners.count >= 3 {
            context.setLineDash(phase: 0, lengths: [2 / currentTransform.scale, 4 / currentTransform.scale])
            context.move(to: corners.last!)
            context.addLine(to: corners[0])
        }
        
        context.strokePath()
        context.setLineDash(phase: 0, lengths: [])
        
        // Draw corner points
        for (index, corner) in corners.enumerated() {
            let isFirst = index == 0
            let color = isFirst ? UIColor.systemGreen : UIColor.systemBlue
            
            context.setFillColor(color.cgColor)
            let radius: CGFloat = 5 / currentTransform.scale
            let cornerRect = CGRect(
                x: corner.x - radius,
                y: corner.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            context.fillEllipse(in: cornerRect)
        }
    }
    
    private func calculateCenter(of points: [CGPoint]) -> CGPoint? {
        guard !points.isEmpty else { return nil }
        
        var sumX: CGFloat = 0
        var sumY: CGFloat = 0
        
        for point in points {
            sumX += point.x
            sumY += point.y
        }
        
        return CGPoint(x: sumX / CGFloat(points.count), y: sumY / CGFloat(points.count))
    }
    
    private func drawOverlays(in context: CGContext, rect: CGRect) {
        // Draw scale indicator
        let scaleText = String(format: "Scale: %.0f%%", currentTransform.scale * 100)
        let font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.secondaryLabel
        ]
        
        let textSize = scaleText.size(withAttributes: attributes)
        let textRect = CGRect(
            x: bounds.width - textSize.width - 10,
            y: bounds.height - textSize.height - 10,
            width: textSize.width,
            height: textSize.height
        )
        
        scaleText.draw(in: textRect, withAttributes: attributes)
    }
    
    // MARK: - Transform Methods
    func panBy(_ translation: CGPoint) {
        currentTransform.offset.x += translation.x
        currentTransform.offset.y += translation.y
        setNeedsDisplay()
        delegate?.canvasDidUpdateTransform(self)
    }
    
    func zoomBy(_ scale: CGFloat) {
        let newScale = currentTransform.scale * scale
        currentTransform.scale = max(0.1, min(10.0, newScale))
        setNeedsDisplay()
        delegate?.canvasDidUpdateTransform(self)
    }
    
    func zoomBy(_ scale: CGFloat, at point: CGPoint) {
        // Calculate the point in world coordinates before zoom
        let worldPoint = screenToWorld(point)
        
        // Apply the scale
        let oldScale = currentTransform.scale
        let newScale = oldScale * scale
        currentTransform.scale = max(0.1, min(10.0, newScale))
        
        // Calculate the new screen position of the world point
        let newScreenPoint = worldToScreen(worldPoint)
        
        // Adjust offset to keep the point at the same screen position
        currentTransform.offset.x += point.x - newScreenPoint.x
        currentTransform.offset.y += point.y - newScreenPoint.y
        
        setNeedsDisplay()
        delegate?.canvasDidUpdateTransform(self)
    }
    
    func resetTransform() {
        UIView.animate(withDuration: 0.3) {
            self.currentTransform = CanvasTransform()
            self.setNeedsDisplay()
        }
        delegate?.canvasDidUpdateTransform(self)
    }
    
    // MARK: - Coordinate Conversion
    func screenToWorld(_ point: CGPoint) -> CGPoint {
        return currentTransform.inverse(to: point)
    }
    
    func worldToScreen(_ point: CGPoint) -> CGPoint {
        return currentTransform.apply(to: point)
    }
    
    // MARK: - Selection
    func selectCornerAt(_ worldPoint: CGPoint) {
        guard let geometry = dataSource?.roomGeometry(for: self) else { return }
        
        let corners = geometry.corners2D
        let threshold: CGFloat = 20 / currentTransform.scale
        
        for (index, corner) in corners.enumerated() {
            let distance = hypot(corner.x - worldPoint.x, corner.y - worldPoint.y)
            if distance < threshold {
                selectedCornerIndex = index
                delegate?.canvas(self, didSelectCornerAt: index)
                setNeedsDisplay()
                return
            }
        }
        
        selectedCornerIndex = nil
        setNeedsDisplay()
    }
}