import UIKit

class MeasurementOverlay: UIView {
    
    // MARK: - Properties
    private var measurements: [Measurement] = []
    private var highlightedCorner: Int?
    private var measurementPoints: [CGPoint] = []
    private var currentTransform = CanvasTransform()
    
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
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }
    
    // MARK: - Drawing
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Apply transform
        context.saveGState()
        context.translateBy(x: currentTransform.offset.x, y: currentTransform.offset.y)
        context.scaleBy(x: currentTransform.scale, y: currentTransform.scale)
        
        // Draw measurements
        drawMeasurements(in: context)
        
        // Draw measurement tool lines
        drawMeasurementTool(in: context)
        
        // Draw highlighted corner
        drawHighlightedCorner(in: context)
        
        context.restoreGState()
    }
    
    private func drawMeasurements(in context: CGContext) {
        for measurement in measurements {
            drawMeasurement(measurement, in: context)
        }
    }
    
    private func drawMeasurement(_ measurement: Measurement, in context: CGContext) {
        // Draw dimension line
        context.setStrokeColor(UIColor.systemOrange.cgColor)
        context.setLineWidth(1.0 / currentTransform.scale)
        context.setLineDash(phase: 0, lengths: [5 / currentTransform.scale, 3 / currentTransform.scale])
        
        context.move(to: measurement.start)
        context.addLine(to: measurement.end)
        context.strokePath()
        
        // Draw end caps
        context.setLineDash(phase: 0, lengths: [])
        let capLength: CGFloat = 10 / currentTransform.scale
        
        // Calculate perpendicular direction
        let dx = measurement.end.x - measurement.start.x
        let dy = measurement.end.y - measurement.start.y
        let length = hypot(dx, dy)
        let perpX = -dy / length * capLength
        let perpY = dx / length * capLength
        
        // Start cap
        context.move(to: CGPoint(x: measurement.start.x - perpX, y: measurement.start.y - perpY))
        context.addLine(to: CGPoint(x: measurement.start.x + perpX, y: measurement.start.y + perpY))
        context.strokePath()
        
        // End cap
        context.move(to: CGPoint(x: measurement.end.x - perpX, y: measurement.end.y - perpY))
        context.addLine(to: CGPoint(x: measurement.end.x + perpX, y: measurement.end.y + perpY))
        context.strokePath()
        
        // Draw measurement text
        let midPoint = CGPoint(
            x: (measurement.start.x + measurement.end.x) / 2,
            y: (measurement.start.y + measurement.end.y) / 2
        )
        
        let distance = hypot(dx, dy) / 100 // Convert to meters
        let text = String(format: "%.2f m", distance)
        
        let font = UIFont.boldSystemFont(ofSize: 14 / currentTransform.scale)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.systemOrange
        ]
        
        let textSize = text.size(withAttributes: attributes)
        let textRect = CGRect(
            x: midPoint.x - textSize.width / 2,
            y: midPoint.y - textSize.height / 2 - 5 / currentTransform.scale,
            width: textSize.width,
            height: textSize.height
        )
        
        // Draw background
        context.setFillColor(UIColor.systemBackground.withAlphaComponent(0.9).cgColor)
        context.fill(textRect.insetBy(dx: -4 / currentTransform.scale, dy: -2 / currentTransform.scale))
        
        // Draw text
        text.draw(in: textRect, withAttributes: attributes)
    }
    
    private func drawMeasurementTool(in context: CGContext) {
        guard measurementPoints.count > 0 else { return }
        
        context.setStrokeColor(UIColor.systemPurple.cgColor)
        context.setLineWidth(2.0 / currentTransform.scale)
        
        if measurementPoints.count == 1 {
            // Draw crosshair at first point
            let point = measurementPoints[0]
            let size: CGFloat = 20 / currentTransform.scale
            
            context.move(to: CGPoint(x: point.x - size, y: point.y))
            context.addLine(to: CGPoint(x: point.x + size, y: point.y))
            context.move(to: CGPoint(x: point.x, y: point.y - size))
            context.addLine(to: CGPoint(x: point.x, y: point.y + size))
            context.strokePath()
        } else if measurementPoints.count == 2 {
            // Draw line between points
            context.move(to: measurementPoints[0])
            context.addLine(to: measurementPoints[1])
            context.strokePath()
            
            // Draw distance
            let distance = hypot(
                measurementPoints[1].x - measurementPoints[0].x,
                measurementPoints[1].y - measurementPoints[0].y
            ) / 100
            
            let text = String(format: "%.2f m", distance)
            let midPoint = CGPoint(
                x: (measurementPoints[0].x + measurementPoints[1].x) / 2,
                y: (measurementPoints[0].y + measurementPoints[1].y) / 2
            )
            
            let font = UIFont.boldSystemFont(ofSize: 16 / currentTransform.scale)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.systemPurple
            ]
            
            text.draw(at: midPoint, withAttributes: attributes)
        }
    }
    
    private func drawHighlightedCorner(in context: CGContext) {
        // Implement corner highlighting if needed
    }
    
    // MARK: - Public Methods
    func updateMeasurements(for geometry: RoomGeometry) {
        measurements.removeAll()
        
        let corners = geometry.corners2D
        guard corners.count >= 2 else { return }
        
        // Create measurements for each wall
        for i in 0..<corners.count {
            let start = corners[i]
            let end = corners[(i + 1) % corners.count]
            
            if !geometry.isClosed && i == corners.count - 1 {
                continue
            }
            
            let measurement = Measurement(start: start, end: end)
            measurements.append(measurement)
        }
        
        setNeedsDisplay()
    }
    
    func updateTransform(_ transform: CanvasTransform) {
        currentTransform = transform
        setNeedsDisplay()
    }
    
    func highlightCorner(at index: Int) {
        highlightedCorner = index
        setNeedsDisplay()
    }
    
    func addMeasurementPoint(_ point: CGPoint) {
        if measurementPoints.count >= 2 {
            measurementPoints.removeAll()
        }
        measurementPoints.append(point)
        setNeedsDisplay()
    }
}

// MARK: - Measurement Structure
struct Measurement {
    let start: CGPoint
    let end: CGPoint
}