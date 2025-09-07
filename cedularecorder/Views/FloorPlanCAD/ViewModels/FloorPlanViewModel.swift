import Foundation
import UIKit
import Combine
// TODO: PlaneGCS package exists but needs to be properly linked to target
// import PlaneGCS

// MARK: - Floor Plan View Model
/// Main business logic for floor plan editor
class FloorPlanViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var floorPlan: FloorPlan
    @Published var currentMode: CADMode = .viewing
    @Published var selectedRoom: CADRoom?
    @Published var drawingCorners: [CGPoint] = []
    @Published var isGridEnabled: Bool = true
    @Published var isSnapEnabled: Bool = true
    
    // MARK: - Properties
    private var cancellables = Set<AnyCancellable>()
    private let snapThreshold: CGFloat = 20
    private let solver = PlaneGCSAdapter()  // Using adapter that will use real PlaneGCS when linked
    
    // MARK: - Computed Properties
    
    /// All rooms on current floor
    var currentRooms: [CADRoom] {
        floorPlan.currentFloor?.rooms ?? []
    }
    
    /// Check if can close current drawing
    var canCloseDrawing: Bool {
        drawingCorners.count >= 3
    }
    
    // MARK: - Initialization
    init() {
        self.floorPlan = FloorPlan()
        setupBindings()
    }
    
    private func setupBindings() {
        // Auto-save when floor plan changes
        $floorPlan
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveFloorPlan()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Mode Management
    
    /// Start drawing a new room
    func startDrawingRoom() {
        drawingCorners.removeAll()
        currentMode = .drawingRoom
        selectedRoom = nil
    }
    
    /// Add corner to current drawing
    func addDrawingCorner(_ point: CGPoint) {
        guard case .drawingRoom = currentMode else { return }
        
        let snappedPoint = isSnapEnabled ? snapToGrid(point) : point
        
        // Check if closing the shape
        if drawingCorners.count >= 3 {
            let firstCorner = drawingCorners[0]
            let distance = hypot(snappedPoint.x - firstCorner.x, snappedPoint.y - firstCorner.y)
            
            if distance < snapThreshold {
                // Close the shape
                finishDrawingRoom()
                return
            }
        }
        
        drawingCorners.append(snappedPoint)
    }
    
    /// Finish drawing current room
    func finishDrawingRoom() {
        guard drawingCorners.count >= 3 else { return }
        
        let room = CADRoom(corners: drawingCorners)
        room.name = "Room \(currentRooms.count + 1)"
        
        // Apply auto-snap to existing rooms
        if isSnapEnabled {
            snapRoomToExisting(room)
        }
        
        floorPlan.addRoom(room)
        drawingCorners.removeAll()
        
        // Select the new room
        selectRoom(room)
    }
    
    /// Cancel current drawing
    func cancelDrawing() {
        drawingCorners.removeAll()
        currentMode = .viewing
    }
    
    // MARK: - Room Selection
    
    /// Select a room for editing
    func selectRoom(_ room: CADRoom?) {
        selectedRoom = room
        if let room = room {
            currentMode = .editingRoom(room)
        } else {
            currentMode = .viewing
        }
    }
    
    /// Find room at point
    func roomAt(point: CGPoint) -> CADRoom? {
        for room in currentRooms.reversed() {
            if room.contains(point: point) {
                return room
            }
        }
        return nil
    }
    
    // MARK: - Room Transformation
    
    /// Move selected room
    func moveSelectedRoom(by delta: CGPoint) {
        guard let room = selectedRoom else { return }
        
        room.transform.position.x += delta.x
        room.transform.position.y += delta.y
        
        // Apply auto-snap
        if isSnapEnabled {
            snapRoomToExisting(room)
        }
    }
    
    /// Rotate selected room
    func rotateSelectedRoom(by angle: CGFloat) {
        guard let room = selectedRoom else { return }
        room.transform.rotation += angle
    }
    
    /// Add a vertex to the room polygon
    func addVertexToRoom(_ room: CADRoom, at point: CGPoint) {
        // Convert world point to local room coordinates
        let localPoint = CGPoint(
            x: point.x - room.transform.position.x,
            y: point.y - room.transform.position.y
        )
        
        // Find the closest edge to insert the vertex
        var closestEdgeIndex = 0
        var closestDistance = CGFloat.greatestFiniteMagnitude
        
        for i in 0..<room.corners.count {
            let j = (i + 1) % room.corners.count
            let p1 = room.corners[i]
            let p2 = room.corners[j]
            
            // Calculate distance from point to line segment
            let distance = distanceFromPoint(localPoint, toLineSegment: (p1, p2))
            
            if distance < closestDistance {
                closestDistance = distance
                closestEdgeIndex = i
            }
        }
        
        // Insert the new vertex after the closest edge's first vertex
        room.corners.insert(localPoint, at: closestEdgeIndex + 1)
        
        // Trigger update
        objectWillChange.send()
    }
    
    /// Calculate distance from a point to a line segment
    private func distanceFromPoint(_ point: CGPoint, toLineSegment segment: (CGPoint, CGPoint)) -> CGFloat {
        let (p1, p2) = segment
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        
        if dx == 0 && dy == 0 {
            // The segment is a point
            return hypot(point.x - p1.x, point.y - p1.y)
        }
        
        // Calculate the t parameter for the projection
        let t = max(0, min(1, ((point.x - p1.x) * dx + (point.y - p1.y) * dy) / (dx * dx + dy * dy)))
        
        // Find the closest point on the segment
        let projection = CGPoint(x: p1.x + t * dx, y: p1.y + t * dy)
        
        // Return the distance
        return hypot(point.x - projection.x, point.y - projection.y)
    }
    
    /// Move a vertex to a new position
    func moveVertex(at index: Int, in room: CADRoom, to worldPoint: CGPoint) {
        guard index >= 0 && index < room.corners.count else { return }
        
        // Convert world point to local room coordinates
        let localPoint = CGPoint(
            x: worldPoint.x - room.transform.position.x,
            y: worldPoint.y - room.transform.position.y
        )
        
        // Apply snapping if enabled
        let snappedPoint = isSnapEnabled ? snapToGrid(localPoint) : localPoint
        
        // Update the vertex position
        room.corners[index] = snappedPoint
        
        // Trigger update
        objectWillChange.send()
    }
    
    /// Delete a vertex from the room polygon
    func deleteVertexFromRoom(_ room: CADRoom, at point: CGPoint) {
        // Don't allow deletion if room has 3 or fewer vertices (minimum for a polygon)
        guard room.corners.count > 3 else { return }
        
        // Convert world point to local room coordinates
        let localPoint = CGPoint(
            x: point.x - room.transform.position.x,
            y: point.y - room.transform.position.y
        )
        
        // Find the closest vertex to delete
        var closestVertexIndex = -1
        var closestDistance = CGFloat.greatestFiniteMagnitude
        let threshold: CGFloat = 30 // Touch threshold
        
        for (index, corner) in room.corners.enumerated() {
            let distance = hypot(localPoint.x - corner.x, localPoint.y - corner.y)
            if distance < closestDistance && distance < threshold {
                closestDistance = distance
                closestVertexIndex = index
            }
        }
        
        // Delete the closest vertex if found
        if closestVertexIndex >= 0 {
            room.corners.remove(at: closestVertexIndex)
            objectWillChange.send()
        }
    }
    
    /// Delete selected room
    func deleteSelectedRoom() {
        guard let room = selectedRoom else { return }
        floorPlan.removeRoom(room)
        selectedRoom = nil
        currentMode = .viewing
    }
    
    // MARK: - Preset Shapes
    
    /// Add a preset shape room
    func addPresetRoom(_ preset: RoomShapePreset, at position: CGPoint = CGPoint(x: 200, y: 200)) {
        let corners = preset.generateCorners()
        let room = CADRoom(
            name: preset.suggestedRoomType.rawValue,
            type: preset.suggestedRoomType,
            corners: corners
        )
        room.transform.position = position
        
        floorPlan.addRoom(room)
        selectRoom(room)
    }
    
    // MARK: - Snapping
    
    private func snapToGrid(_ point: CGPoint) -> CGPoint {
        let gridSize: CGFloat = 20
        return CGPoint(
            x: round(point.x / gridSize) * gridSize,
            y: round(point.y / gridSize) * gridSize
        )
    }
    
    private func snapRoomToExisting(_ room: CADRoom) {
        // Find nearby walls and snap
        let snapDistance: CGFloat = 15
        
        for existingRoom in currentRooms where existingRoom.id != room.id {
            // Check each wall of the room against existing room walls
            // This is simplified - full implementation would check wall alignment
            let roomBox = room.boundingBox
            let existingBox = existingRoom.boundingBox
            
            // Snap horizontally
            if abs(roomBox.minX - existingBox.maxX) < snapDistance {
                room.transform.position.x += existingBox.maxX - roomBox.minX
            } else if abs(roomBox.maxX - existingBox.minX) < snapDistance {
                room.transform.position.x += existingBox.minX - roomBox.maxX
            }
            
            // Snap vertically
            if abs(roomBox.minY - existingBox.maxY) < snapDistance {
                room.transform.position.y += existingBox.maxY - roomBox.minY
            } else if abs(roomBox.maxY - existingBox.minY) < snapDistance {
                room.transform.position.y += existingBox.minY - roomBox.maxY
            }
        }
    }
    
    // MARK: - Edge Constraints
    
    /// Set a length constraint for an edge
    func setLengthConstraint(for room: CADRoom, edgeIndex: Int, length: CGFloat, isLocked: Bool = false) {
        guard edgeIndex >= 0 && edgeIndex < room.corners.count else { return }
        
        print("\n🔨 Setting LENGTH constraint for edge \(edgeIndex): \(length) in room \(room.name)")
        
        // Only remove existing LENGTH constraint for this edge (keep horizontal/vertical!)
        room.edgeConstraints.removeAll { 
            $0.edgeIndex == edgeIndex && $0.type == .length 
        }
        print("  Removed existing length constraint for edge \(edgeIndex) if any")
        
        // Add new constraint using the comprehensive init
        let constraint = EdgeConstraint(
            edgeIndex: edgeIndex,
            type: .length,
            targetValue: length,
            referenceEdgeIndex: nil,
            isLocked: isLocked
        )
        room.edgeConstraints.append(constraint)
        print("  Total constraints now: \(room.edgeConstraints.count)")
        
        // Apply constraints immediately
        applyConstraints(to: room)
    }
    
    /// Remove a length constraint for an edge
    func removeLengthConstraint(for room: CADRoom, edgeIndex: Int) {
        room.edgeConstraints.removeAll { 
            $0.edgeIndex == edgeIndex && $0.type == .length 
        }
        objectWillChange.send()
    }
    
    /// Apply all constraints to a room using the solver
    func applyConstraints(to room: CADRoom) {
        print("\n📐 FloorPlanViewModel: Applying constraints to room: \(room.name)")
        let result = solver.solveConstraints(for: room)
        
        if result.success {
            print("✅ Constraint solving succeeded")
        } else {
            print("❌ Constraint solving failed: \(result.error ?? "Unknown error")")
        }
        
        // Force UI update
        objectWillChange.send()
        print("📱 UI update triggered")
    }
    
    /// Set a horizontal constraint for an edge
    func setHorizontalConstraint(for room: CADRoom, edgeIndex: Int, isLocked: Bool = false) {
        guard edgeIndex >= 0 && edgeIndex < room.corners.count else { return }
        
        print("\n🔨 Setting HORIZONTAL constraint for edge \(edgeIndex) in room \(room.name)")
        
        // Only remove conflicting constraints for THIS edge (not all constraints!)
        room.edgeConstraints.removeAll { 
            $0.edgeIndex == edgeIndex && 
            ($0.type == .horizontal || $0.type == .vertical || $0.type == .angle)
        }
        print("  Removed conflicting constraints for edge \(edgeIndex)")
        
        // Add horizontal constraint
        let constraint = EdgeConstraint(
            edgeIndex: edgeIndex,
            type: .horizontal,
            isLocked: isLocked
        )
        room.edgeConstraints.append(constraint)
        print("  Total constraints now: \(room.edgeConstraints.count)")
        
        // Apply constraints immediately
        applyConstraints(to: room)
    }
    
    /// Set a vertical constraint for an edge
    func setVerticalConstraint(for room: CADRoom, edgeIndex: Int, isLocked: Bool = false) {
        guard edgeIndex >= 0 && edgeIndex < room.corners.count else { return }
        
        print("\n🔨 Setting VERTICAL constraint for edge \(edgeIndex) in room \(room.name)")
        
        // Only remove conflicting constraints for THIS edge (not all constraints!)
        room.edgeConstraints.removeAll { 
            $0.edgeIndex == edgeIndex && 
            ($0.type == .horizontal || $0.type == .vertical || $0.type == .angle)
        }
        print("  Removed conflicting constraints for edge \(edgeIndex)")
        
        // Add vertical constraint
        let constraint = EdgeConstraint(
            edgeIndex: edgeIndex,
            type: .vertical,
            isLocked: isLocked
        )
        room.edgeConstraints.append(constraint)
        print("  Total constraints now: \(room.edgeConstraints.count)")
        
        // Apply constraints immediately
        applyConstraints(to: room)
    }
    
    /// Set a perpendicular constraint between two edges
    func setPerpendicularConstraint(for room: CADRoom, edgeIndex: Int, referenceEdgeIndex: Int) {
        guard edgeIndex >= 0 && edgeIndex < room.corners.count,
              referenceEdgeIndex >= 0 && referenceEdgeIndex < room.corners.count else { return }
        
        // Only remove existing perpendicular/parallel/angle constraints for this edge
        room.edgeConstraints.removeAll { 
            $0.edgeIndex == edgeIndex && 
            ($0.type == .perpendicular || $0.type == .parallel || $0.type == .angle)
        }
        
        // Add perpendicular constraint
        let constraint = EdgeConstraint(
            edgeIndex: edgeIndex,
            type: .perpendicular,
            referenceEdgeIndex: referenceEdgeIndex
        )
        room.edgeConstraints.append(constraint)
        
        // Apply constraints immediately
        applyConstraints(to: room)
    }
    
    /// Set a parallel constraint between two edges
    func setParallelConstraint(for room: CADRoom, edgeIndex: Int, referenceEdgeIndex: Int) {
        guard edgeIndex >= 0 && edgeIndex < room.corners.count,
              referenceEdgeIndex >= 0 && referenceEdgeIndex < room.corners.count else { return }
        
        // Only remove existing perpendicular/parallel/angle constraints for this edge
        room.edgeConstraints.removeAll { 
            $0.edgeIndex == edgeIndex && 
            ($0.type == .perpendicular || $0.type == .parallel || $0.type == .angle)
        }
        
        // Add parallel constraint
        let constraint = EdgeConstraint(
            edgeIndex: edgeIndex,
            type: .parallel,
            referenceEdgeIndex: referenceEdgeIndex
        )
        room.edgeConstraints.append(constraint)
        
        // Apply constraints immediately
        applyConstraints(to: room)
    }
    
    /// Get the current length of an edge
    func getEdgeLength(for room: CADRoom, edgeIndex: Int) -> CGFloat? {
        guard edgeIndex >= 0 && edgeIndex < room.corners.count else { return nil }
        
        let i = edgeIndex
        let j = (edgeIndex + 1) % room.corners.count
        let p1 = room.corners[i]
        let p2 = room.corners[j]
        
        return hypot(p2.x - p1.x, p2.y - p1.y)
    }
    
    /// Get constraint for an edge if it exists
    func getConstraint(for room: CADRoom, edgeIndex: Int) -> EdgeConstraint? {
        return room.edgeConstraints.first { $0.edgeIndex == edgeIndex }
    }
    
    // MARK: - Point Constraints
    
    /// Add a point-on-line constraint
    func setPointOnLineConstraint(for room: CADRoom, pointIndex: Int, edgeIndex: Int) {
        guard pointIndex >= 0 && pointIndex < room.corners.count,
              edgeIndex >= 0 && edgeIndex < room.corners.count else { return }
        
        // Remove existing point-on-line constraint for this point
        room.pointConstraints.removeAll { 
            $0.pointIndex == pointIndex && $0.type == .pointOnLine 
        }
        
        // Add new constraint
        let constraint = PointConstraint(
            pointIndex: pointIndex,
            type: .pointOnLine,
            referenceEdgeIndex: edgeIndex
        )
        room.pointConstraints.append(constraint)
        
        // Apply constraints immediately
        applyConstraints(to: room)
    }
    
    /// Add a point-to-point distance constraint
    func setPointToPointDistance(for room: CADRoom, point1: Int, point2: Int, distance: CGFloat) {
        guard point1 >= 0 && point1 < room.corners.count,
              point2 >= 0 && point2 < room.corners.count,
              point1 != point2 else { return }
        
        // Remove existing distance constraint between these points
        room.pointConstraints.removeAll { 
            $0.pointIndex == point1 && 
            $0.referencePointIndex == point2 && 
            $0.type == .pointToPointDistance 
        }
        
        // Add new constraint
        let constraint = PointConstraint(
            pointIndex: point1,
            type: .pointToPointDistance,
            targetValue: distance,
            referencePointIndex: point2
        )
        room.pointConstraints.append(constraint)
        
        // Apply constraints immediately
        applyConstraints(to: room)
    }
    
    /// Add a point-to-line distance constraint
    func setPointToLineDistance(for room: CADRoom, pointIndex: Int, edgeIndex: Int, distance: CGFloat) {
        guard pointIndex >= 0 && pointIndex < room.corners.count,
              edgeIndex >= 0 && edgeIndex < room.corners.count else { return }
        
        // Remove existing distance constraint for this point to this edge
        room.pointConstraints.removeAll { 
            $0.pointIndex == pointIndex && 
            $0.referenceEdgeIndex == edgeIndex && 
            $0.type == .pointToLineDistance 
        }
        
        // Add new constraint
        let constraint = PointConstraint(
            pointIndex: pointIndex,
            type: .pointToLineDistance,
            targetValue: distance,
            referenceEdgeIndex: edgeIndex
        )
        room.pointConstraints.append(constraint)
        
        // Apply constraints immediately
        applyConstraints(to: room)
    }
    
    /// Make two points coincident (same location)
    func setCoincidentPoints(for room: CADRoom, point1: Int, point2: Int) {
        guard point1 >= 0 && point1 < room.corners.count,
              point2 >= 0 && point2 < room.corners.count,
              point1 != point2 else { return }
        
        // Remove existing coincident constraint between these points
        room.pointConstraints.removeAll { 
            $0.pointIndex == point1 && 
            $0.referencePointIndex == point2 && 
            $0.type == .coincident 
        }
        
        // Add new constraint
        let constraint = PointConstraint(
            pointIndex: point1,
            type: .coincident,
            referencePointIndex: point2
        )
        room.pointConstraints.append(constraint)
        
        // Apply constraints immediately
        applyConstraints(to: room)
    }
    
    // MARK: - Media Attachments
    
    /// Add media attachment to selected room
    func addMediaAttachment(_ attachment: MediaAttachment) {
        guard let room = selectedRoom else { return }
        room.mediaAttachments.append(attachment)
    }
    
    // MARK: - Persistence
    
    private func saveFloorPlan() {
        // Save to UserDefaults or CoreData
        print("Saving floor plan...")
    }
    
    func loadFloorPlan() {
        // Load from storage
        print("Loading floor plan...")
    }
}