import UIKit

class GridManager {
    
    // MARK: - Properties
    var gridSize: CGFloat
    var isSnapEnabled: Bool = true
    var majorGridInterval: Int = 5
    
    // MARK: - Initialization
    init(gridSize: CGFloat = 20) {
        self.gridSize = gridSize
    }
    
    // MARK: - Snapping
    func snapToGrid(_ point: CGPoint) -> CGPoint {
        guard isSnapEnabled else { return point }
        
        let snappedX = round(point.x / gridSize) * gridSize
        let snappedY = round(point.y / gridSize) * gridSize
        
        return CGPoint(x: snappedX, y: snappedY)
    }
    
    func snapToGrid(_ value: CGFloat) -> CGFloat {
        guard isSnapEnabled else { return value }
        return round(value / gridSize) * gridSize
    }
    
    // MARK: - Grid Calculations
    func nearestGridPoint(to point: CGPoint) -> CGPoint {
        return snapToGrid(point)
    }
    
    func distanceToNearestGridLine(from point: CGPoint) -> CGFloat {
        let snapped = snapToGrid(point)
        return hypot(point.x - snapped.x, point.y - snapped.y)
    }
    
    func isMajorGridLine(at position: CGFloat) -> Bool {
        let gridIndex = Int(position / gridSize)
        return gridIndex % majorGridInterval == 0
    }
}