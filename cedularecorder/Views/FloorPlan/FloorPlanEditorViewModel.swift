import SwiftUI
import Combine
import simd

enum EditMode {
    case view
    case edit
    case measure
}

enum MeasurementUnit {
    case meters
    case feet
    
    var conversionFactor: Double {
        switch self {
        case .meters: return 1.0
        case .feet: return 3.28084
        }
    }
    
    var symbol: String {
        switch self {
        case .meters: return "m"
        case .feet: return "ft"
        }
    }
}

class FloorPlanEditorViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var corners: [CGPoint] = []
    @Published var editMode: EditMode = .edit
    @Published var measurementUnit: MeasurementUnit = .meters
    @Published var snapToGrid: Bool = true
    @Published var gridSize: CGFloat = 20.0 // Points on screen
    @Published var metersPerPoint: CGFloat = 0.01 // Scale: 1 point = 0.01 meters
    
    // MARK: - Private Properties
    private var undoStack: [[CGPoint]] = []
    private var redoStack: [[CGPoint]] = []
    private var canvasSize: CGSize = .zero
    private let cornerHitRadius: CGFloat = 20.0
    private let wallHitDistance: CGFloat = 10.0
    
    // MARK: - Computed Properties
    
    var area: Double {
        guard corners.count >= 3 else { return 0 }
        
        // Shoelace formula for polygon area
        var sum: Double = 0
        for i in 0..<corners.count {
            let j = (i + 1) % corners.count
            sum += Double(corners[i].x * corners[j].y)
            sum -= Double(corners[j].x * corners[i].y)
        }
        
        let areaInPoints = abs(sum) / 2.0
        let areaInMeters = areaInPoints * Double(metersPerPoint * metersPerPoint)
        return areaInMeters * (measurementUnit == .feet ? 10.764 : 1.0) // Convert to sq ft if needed
    }
    
    var perimeter: Double {
        guard corners.count >= 2 else { return 0 }
        
        var total: Double = 0
        for i in 0..<corners.count {
            let j = (i + 1) % corners.count
            total += distance(from: corners[i], to: corners[j])
        }
        
        let perimeterInMeters = total * Double(metersPerPoint)
        return perimeterInMeters * Double(measurementUnit.conversionFactor)
    }
    
    // MARK: - Initialization
    
    init() {
        // Initialize with a sample rectangle for testing
        setupSampleRoom()
    }
    
    // MARK: - Setup
    
    func setupCanvas(size: CGSize) {
        canvasSize = size
        
        // Calculate scale to fit room in canvas
        if !corners.isEmpty {
            fitToCanvas()
        }
    }
    
    private func setupSampleRoom() {
        // Create a sample 5m x 4m room centered in a 400x400 canvas
        let centerX: CGFloat = 200
        let centerY: CGFloat = 200
        let roomWidth: CGFloat = 250  // 5m at 50 points per meter
        let roomHeight: CGFloat = 200 // 4m at 50 points per meter
        
        corners = [
            CGPoint(x: centerX - roomWidth/2, y: centerY - roomHeight/2),
            CGPoint(x: centerX + roomWidth/2, y: centerY - roomHeight/2),
            CGPoint(x: centerX + roomWidth/2, y: centerY + roomHeight/2),
            CGPoint(x: centerX - roomWidth/2, y: centerY + roomHeight/2)
        ]
    }
    
    // MARK: - Import from AR
    
    func importFromARCapture(_ arCorners: [simd_float3]) {
        guard !arCorners.isEmpty else { return }
        
        saveToUndoStack()
        
        // Find bounds of AR data
        var minX = Float.infinity
        var minZ = Float.infinity
        var maxX = -Float.infinity
        var maxZ = -Float.infinity
        
        for corner in arCorners {
            minX = min(minX, corner.x)
            maxX = max(maxX, corner.x)
            minZ = min(minZ, corner.z)
            maxZ = max(maxZ, corner.z)
        }
        
        let arWidth = maxX - minX
        let arHeight = maxZ - minZ
        
        // Calculate scale to fit in canvas (with margin)
        let margin: CGFloat = 50
        let availableWidth = canvasSize.width - margin * 2
        let availableHeight = canvasSize.height - margin * 2
        
        let scaleX = availableWidth / CGFloat(arWidth)
        let scaleZ = availableHeight / CGFloat(arHeight)
        let scale = min(scaleX, scaleZ)
        
        // Update meters per point based on scale
        metersPerPoint = 1.0 / scale
        
        // Convert AR coordinates to canvas coordinates
        corners = arCorners.map { corner in
            let x = margin + CGFloat(corner.x - minX) * scale
            let y = margin + CGFloat(corner.z - minZ) * scale
            return CGPoint(x: x, y: y)
        }
    }
    
    // MARK: - Corner Management
    
    func addCorner() {
        saveToUndoStack()
        
        // Add new corner at center or offset from last corner
        let newCorner: CGPoint
        if let lastCorner = corners.last {
            newCorner = CGPoint(x: lastCorner.x + 50, y: lastCorner.y)
        } else {
            newCorner = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        }
        
        corners.append(snapToGridIfNeeded(newCorner))
    }
    
    func addCornerOnWall(at point: CGPoint) {
        guard corners.count >= 2 else { return }
        
        saveToUndoStack()
        
        // Find closest wall segment
        var closestWallIndex = 0
        var closestDistance = Double.infinity
        var closestPoint = point
        
        for i in 0..<corners.count {
            let j = (i + 1) % corners.count
            let projectedPoint = projectPointOntoLineSegment(point, lineStart: corners[i], lineEnd: corners[j])
            let dist = distance(from: point, to: projectedPoint)
            
            if dist < closestDistance {
                closestDistance = dist
                closestWallIndex = i
                closestPoint = projectedPoint
            }
        }
        
        // Insert new corner after the closest wall's start corner
        corners.insert(snapToGridIfNeeded(closestPoint), at: closestWallIndex + 1)
    }
    
    func moveCorner(at index: Int, to point: CGPoint) {
        guard index >= 0 && index < corners.count else { return }
        
        if corners[index] != point {
            saveToUndoStack()
            corners[index] = snapToGridIfNeeded(point)
        }
    }
    
    func deleteCorner(at index: Int) {
        guard index >= 0 && index < corners.count && corners.count > 3 else { return }
        
        saveToUndoStack()
        corners.remove(at: index)
    }
    
    // MARK: - Hit Testing
    
    func cornerIndex(at point: CGPoint) -> Int? {
        for (index, corner) in corners.enumerated() {
            if distance(from: point, to: corner) <= cornerHitRadius {
                return index
            }
        }
        return nil
    }
    
    func isOnWall(point: CGPoint) -> Bool {
        guard corners.count >= 2 else { return false }
        
        for i in 0..<corners.count {
            let j = (i + 1) % corners.count
            let projectedPoint = projectPointOntoLineSegment(point, lineStart: corners[i], lineEnd: corners[j])
            
            if distance(from: point, to: projectedPoint) <= wallHitDistance {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Measurements
    
    func wallLength(from index1: Int, to index2: Int) -> Double {
        guard index1 >= 0 && index1 < corners.count,
              index2 >= 0 && index2 < corners.count else { return 0 }
        
        let lengthInPoints = distance(from: corners[index1], to: corners[index2])
        let lengthInMeters = lengthInPoints * Double(metersPerPoint)
        return lengthInMeters * Double(measurementUnit.conversionFactor)
    }
    
    // MARK: - Undo/Redo
    
    func undo() {
        guard !undoStack.isEmpty else { return }
        
        redoStack.append(corners)
        corners = undoStack.removeLast()
    }
    
    func redo() {
        guard !redoStack.isEmpty else { return }
        
        undoStack.append(corners)
        corners = redoStack.removeLast()
    }
    
    private func saveToUndoStack() {
        undoStack.append(corners)
        redoStack.removeAll() // Clear redo stack when new action is performed
        
        // Limit undo stack size
        if undoStack.count > 20 {
            undoStack.removeFirst()
        }
    }
    
    // MARK: - Grid Snapping
    
    private func snapToGridIfNeeded(_ point: CGPoint) -> CGPoint {
        guard snapToGrid else { return point }
        
        let snappedX = round(point.x / gridSize) * gridSize
        let snappedY = round(point.y / gridSize) * gridSize
        
        return CGPoint(x: snappedX, y: snappedY)
    }
    
    // MARK: - Geometry Helpers
    
    private func distance(from p1: CGPoint, to p2: CGPoint) -> Double {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(Double(dx * dx + dy * dy))
    }
    
    private func projectPointOntoLineSegment(_ point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGPoint {
        let lineVec = CGPoint(x: lineEnd.x - lineStart.x, y: lineEnd.y - lineStart.y)
        let pointVec = CGPoint(x: point.x - lineStart.x, y: point.y - lineStart.y)
        
        let lineLength = distance(from: lineStart, to: lineEnd)
        if lineLength == 0 { return lineStart }
        
        let lineLengthSquared = lineLength * lineLength
        var t = (Double(pointVec.x * lineVec.x + pointVec.y * lineVec.y)) / lineLengthSquared
        
        // Clamp t to [0, 1] to keep point on line segment
        t = max(0, min(1, t))
        
        return CGPoint(
            x: lineStart.x + CGFloat(t) * lineVec.x,
            y: lineStart.y + CGFloat(t) * lineVec.y
        )
    }
    
    private func fitToCanvas() {
        guard !corners.isEmpty, canvasSize.width > 0, canvasSize.height > 0 else { return }
        
        // Find bounds
        var minX = CGFloat.infinity
        var minY = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var maxY = -CGFloat.infinity
        
        for corner in corners {
            minX = min(minX, corner.x)
            minY = min(minY, corner.y)
            maxX = max(maxX, corner.x)
            maxY = max(maxY, corner.y)
        }
        
        let roomWidth = maxX - minX
        let roomHeight = maxY - minY
        
        if roomWidth == 0 || roomHeight == 0 { return }
        
        // Calculate scale to fit with margin
        let margin: CGFloat = 50
        let scaleX = (canvasSize.width - margin * 2) / roomWidth
        let scaleY = (canvasSize.height - margin * 2) / roomHeight
        let scale = min(scaleX, scaleY)
        
        // Center and scale corners
        let centerX = canvasSize.width / 2
        let centerY = canvasSize.height / 2
        let roomCenterX = (minX + maxX) / 2
        let roomCenterY = (minY + maxY) / 2
        
        corners = corners.map { corner in
            CGPoint(
                x: centerX + (corner.x - roomCenterX) * scale,
                y: centerY + (corner.y - roomCenterY) * scale
            )
        }
    }
}