import UIKit

// MARK: - Floor Plan Canvas Data Source
protocol FloorPlanCanvasDataSource: AnyObject {
    var rooms: [CADRoom] { get }
    var selectedRoom: CADRoom? { get }
    var drawingCorners: [CGPoint] { get }
    var isGridEnabled: Bool { get }
    var currentMode: CADMode { get }
}

// MARK: - Floor Plan Canvas View
/// Main canvas for rendering rooms and handling drawing
class FloorPlanCanvasView: UIView {
    
    // MARK: - Properties
    weak var dataSource: FloorPlanCanvasDataSource?
    private(set) var currentTransform = CanvasTransform()
    
    // Drawing properties
    private let gridSize: CGFloat = 20
    private let cornerRadius: CGFloat = 8
    
    // Colors
    private let gridColor = UIColor.systemGray5
    private let drawingColor = UIColor.systemBlue
    private let selectedColor = UIColor.systemOrange
    
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
    }
    
    // MARK: - Drawing
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Apply transform
        context.saveGState()
        context.translateBy(x: currentTransform.offset.x, y: currentTransform.offset.y)
        context.scaleBy(x: currentTransform.scale, y: currentTransform.scale)
        
        // Draw layers in order
        if dataSource?.isGridEnabled == true {
            drawGrid(in: context, rect: rect)
        }
        
        drawRooms(in: context)
        drawDrawingShape(in: context)
        drawMediaPins(in: context)
        
        context.restoreGState()
        
        // Draw UI overlay (not affected by transform)
        drawModeIndicator(in: context, rect: rect)
    }
    
    // MARK: - Grid Drawing
    private func drawGrid(in context: CGContext, rect: CGRect) {
        let bounds = self.bounds
        
        // Calculate visible grid range
        let startX = Int((-currentTransform.offset.x / currentTransform.scale) / gridSize) * Int(gridSize)
        let endX = Int((bounds.width - currentTransform.offset.x) / currentTransform.scale / gridSize) * Int(gridSize) + Int(gridSize)
        let startY = Int((-currentTransform.offset.y / currentTransform.scale) / gridSize) * Int(gridSize)
        let endY = Int((bounds.height - currentTransform.offset.y) / currentTransform.scale / gridSize) * Int(gridSize) + Int(gridSize)
        
        // Draw minor grid
        context.setStrokeColor(gridColor.cgColor)
        context.setLineWidth(0.5 / currentTransform.scale)
        
        for x in stride(from: startX, through: endX, by: Int(gridSize)) {
            context.move(to: CGPoint(x: CGFloat(x), y: CGFloat(startY)))
            context.addLine(to: CGPoint(x: CGFloat(x), y: CGFloat(endY)))
        }
        
        for y in stride(from: startY, through: endY, by: Int(gridSize)) {
            context.move(to: CGPoint(x: CGFloat(startX), y: CGFloat(y)))
            context.addLine(to: CGPoint(x: CGFloat(endX), y: CGFloat(y)))
        }
        
        context.strokePath()
        
        // Draw major grid
        let majorGridSize = gridSize * 5
        context.setLineWidth(1.0 / currentTransform.scale)
        context.setStrokeColor(gridColor.withAlphaComponent(0.5).cgColor)
        
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
    
    // MARK: - Room Drawing
    private func drawRooms(in context: CGContext) {
        guard let rooms = dataSource?.rooms else { return }
        let selectedRoom = dataSource?.selectedRoom
        
        for room in rooms {
            let isSelected = room.id == selectedRoom?.id
            drawRoom(room, isSelected: isSelected, in: context)
        }
    }
    
    private func drawRoom(_ room: CADRoom, isSelected: Bool, in context: CGContext) {
        let corners = room.transformedCorners
        guard corners.count >= 3 else { return }
        
        // Draw fill
        context.saveGState()
        context.beginPath()
        context.move(to: corners[0])
        for corner in corners.dropFirst() {
            context.addLine(to: corner)
        }
        context.closePath()
        
        // Fill with room color
        let fillColor = room.type.color.withAlphaComponent(isSelected ? 0.3 : 0.15)
        context.setFillColor(fillColor.cgColor)
        context.fillPath()
        context.restoreGState()
        
        // Draw outline
        context.setStrokeColor(isSelected ? selectedColor.cgColor : room.type.color.cgColor)
        context.setLineWidth((isSelected ? 3 : 2) / currentTransform.scale)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        context.beginPath()
        context.move(to: corners[0])
        for corner in corners.dropFirst() {
            context.addLine(to: corner)
        }
        context.closePath()
        context.strokePath()
        
        // Draw room name
        drawRoomLabel(room, at: room.boundingBox.center, in: context)
        
        // Draw corners if selected
        if isSelected {
            drawCorners(corners, in: context)
        }
    }
    
    private func drawRoomLabel(_ room: CADRoom, at point: CGPoint, in context: CGContext) {
        let font = UIFont.systemFont(ofSize: 14 / currentTransform.scale, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.label
        ]
        
        let text = "\(room.name)\n\(String(format: "%.1f m²", room.area))"
        let textSize = text.size(withAttributes: attributes)
        
        let textRect = CGRect(
            x: point.x - textSize.width / 2,
            y: point.y - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        // Draw background
        context.setFillColor(UIColor.systemBackground.withAlphaComponent(0.8).cgColor)
        let bgRect = textRect.insetBy(dx: -4 / currentTransform.scale, dy: -2 / currentTransform.scale)
        context.fill(bgRect)
        
        // Draw text
        text.draw(in: textRect, withAttributes: attributes)
    }
    
    private func drawCorners(_ corners: [CGPoint], in context: CGContext) {
        context.setFillColor(selectedColor.cgColor)
        
        for corner in corners {
            let radius = cornerRadius / currentTransform.scale
            let cornerRect = CGRect(
                x: corner.x - radius,
                y: corner.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            context.fillEllipse(in: cornerRect)
        }
    }
    
    // MARK: - Drawing Shape
    private func drawDrawingShape(in context: CGContext) {
        guard let corners = dataSource?.drawingCorners, !corners.isEmpty else { return }
        
        context.setStrokeColor(drawingColor.cgColor)
        context.setLineWidth(2 / currentTransform.scale)
        context.setLineDash(phase: 0, lengths: [5 / currentTransform.scale, 3 / currentTransform.scale])
        
        context.beginPath()
        context.move(to: corners[0])
        
        for corner in corners.dropFirst() {
            context.addLine(to: corner)
        }
        
        // If can close, show dotted line to first corner
        if corners.count >= 3 {
            context.setLineDash(phase: 0, lengths: [2 / currentTransform.scale, 4 / currentTransform.scale])
            context.addLine(to: corners[0])
        }
        
        context.strokePath()
        
        // Draw corner points
        context.setFillColor(drawingColor.cgColor)
        for corner in corners {
            let radius = cornerRadius / currentTransform.scale
            let cornerRect = CGRect(
                x: corner.x - radius,
                y: corner.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            context.fillEllipse(in: cornerRect)
        }
    }
    
    // MARK: - Media Pins
    private func drawMediaPins(in context: CGContext) {
        guard let rooms = dataSource?.rooms else { return }
        
        for room in rooms {
            for attachment in room.mediaAttachments {
                drawMediaPin(attachment, in: room, context: context)
            }
        }
    }
    
    private func drawMediaPin(_ attachment: MediaAttachment, in room: CADRoom, context: CGContext) {
        let worldPos = room.transform.apply(to: attachment.position)
        let pinSize: CGFloat = 24 / currentTransform.scale
        
        // Draw pin background
        let pinRect = CGRect(
            x: worldPos.x - pinSize / 2,
            y: worldPos.y - pinSize / 2,
            width: pinSize,
            height: pinSize
        )
        
        context.setFillColor(attachment.type.color.cgColor)
        context.fillEllipse(in: pinRect)
        
        // Draw icon (simplified)
        context.setFillColor(UIColor.white.cgColor)
        let iconRect = pinRect.insetBy(dx: pinSize * 0.25, dy: pinSize * 0.25)
        
        switch attachment.type {
        case .photo:
            context.fill(iconRect)
        case .video:
            // Draw triangle
            context.beginPath()
            context.move(to: CGPoint(x: iconRect.minX, y: iconRect.minY))
            context.addLine(to: CGPoint(x: iconRect.maxX, y: iconRect.midY))
            context.addLine(to: CGPoint(x: iconRect.minX, y: iconRect.maxY))
            context.closePath()
            context.fillPath()
        case .note:
            // Draw lines
            let lineHeight = iconRect.height / 3
            for i in 0..<3 {
                let y = iconRect.minY + CGFloat(i) * lineHeight + lineHeight / 2
                context.fill(CGRect(x: iconRect.minX, y: y - 0.5, width: iconRect.width, height: 1))
            }
        case .voiceNote:
            // Draw circle with dot
            context.strokeEllipse(in: iconRect)
            let dotRect = CGRect(x: iconRect.midX - 2, y: iconRect.midY - 2, width: 4, height: 4)
            context.fillEllipse(in: dotRect)
        }
    }
    
    // MARK: - Mode Indicator
    private func drawModeIndicator(in context: CGContext, rect: CGRect) {
        guard let mode = dataSource?.currentMode else { return }
        
        // Draw zoom level
        let zoomText = String(format: "%.0f%%", currentTransform.scale * 100)
        let font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.secondaryLabel
        ]
        
        let textSize = zoomText.size(withAttributes: attributes)
        let textRect = CGRect(
            x: bounds.width - textSize.width - 10,
            y: bounds.height - textSize.height - 10,
            width: textSize.width,
            height: textSize.height
        )
        
        zoomText.draw(in: textRect, withAttributes: attributes)
    }
    
    // MARK: - Transform Methods
    func panBy(_ translation: CGPoint) {
        currentTransform.offset.x += translation.x
        currentTransform.offset.y += translation.y
        setNeedsDisplay()
    }
    
    func zoomBy(_ scale: CGFloat, at point: CGPoint) {
        let worldPoint = screenToWorld(point)
        
        let oldScale = currentTransform.scale
        let newScale = oldScale * scale
        currentTransform.scale = max(0.1, min(10.0, newScale))
        
        let newScreenPoint = worldToScreen(worldPoint)
        currentTransform.offset.x += point.x - newScreenPoint.x
        currentTransform.offset.y += point.y - newScreenPoint.y
        
        setNeedsDisplay()
    }
    
    func resetTransform() {
        UIView.animate(withDuration: 0.3) {
            self.currentTransform = CanvasTransform()
            self.setNeedsDisplay()
        }
    }
    
    // MARK: - Coordinate Conversion
    func screenToWorld(_ point: CGPoint) -> CGPoint {
        return currentTransform.inverse(to: point)
    }
    
    func worldToScreen(_ point: CGPoint) -> CGPoint {
        return currentTransform.apply(to: point)
    }
}

// MARK: - CGRect Extension
private extension CGRect {
    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
}