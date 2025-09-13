import RealityKit
import ARKit
import SwiftUI

// MARK: - Plane Intersection System
/// ECS System that creates bright lines where planes meet (walls with floor/ceiling)
@MainActor
class PlaneIntersectionSystem: RealityKit.System {
    
    // MARK: - Static Properties
    static var intersectionLines: [String: ModelEntity] = [:]  // Key: "planeID1_planeID2"
    private static weak var sharedARView: ARView?
    
    // PERFORMANCE CACHES
    static var trackedVerticalPlanes: [UUID: ARPlaneAnchor] = [:]
    static var trackedHorizontalPlanes: [UUID: ARPlaneAnchor] = [:]
    static var intersectionsDirty = false
    
    // MARK: - Diamond Solid Polygon Completion
    static var roomPolygon: [SIMD3<Float>] = []  // Completed polygon vertices
    static var polygonDirty = false  // Only recompute when walls change
    static var floorHeight: Float = 0  // Detected floor height
    static var floorPolygonEntity: ModelEntity?  // Floor visualization
    static var vertexEntities: [ModelEntity] = []  // Vertex visualization
    static var connectionEntities: [ModelEntity] = []  // Connection line visualization
    
    // MARK: - Initialization
    required init(scene: RealityKit.Scene) {
        print("[PlaneIntersectionSystem] Initialized")
    }
    
    // MARK: - Properties
    private var frameCount = 0
    
    // MARK: - Update Loop
    func update(context: SceneUpdateContext) {
        frameCount += 1
        
        // PERFORMANCE: Only update when planes change or every 60 frames
        guard Self.intersectionsDirty || Self.polygonDirty || frameCount % 60 == 0 else { return }
        
        guard let arView = Self.sharedARView else { return }
        
        // OPTIMIZED: Use cached planes instead of searching
        if Self.intersectionsDirty {
            // Update plane caches from session
            Self.trackedVerticalPlanes.removeAll()
            Self.trackedHorizontalPlanes.removeAll()
            
            if let anchors = arView.session.currentFrame?.anchors {
                for anchor in anchors {
                    if let planeAnchor = anchor as? ARPlaneAnchor,
                       WallInteractionSystem.trackedWalls.contains(planeAnchor.identifier) {
                        if planeAnchor.alignment == .vertical {
                            Self.trackedVerticalPlanes[planeAnchor.identifier] = planeAnchor
                        } else if planeAnchor.alignment == .horizontal {
                            Self.trackedHorizontalPlanes[planeAnchor.identifier] = planeAnchor
                        }
                    }
                }
            }
            Self.intersectionsDirty = false
        }
        
        // Compute room polygon when walls change
        if Self.polygonDirty && !Self.trackedVerticalPlanes.isEmpty {
            print("[PlaneIntersection] 🔄 Polygon dirty, computing with \(Self.trackedVerticalPlanes.count) walls")
            Self.computeRoomPolygon()
            Self.polygonDirty = false
        }
        
        // Early exit if no intersections possible
        if Self.trackedVerticalPlanes.isEmpty || Self.trackedHorizontalPlanes.isEmpty {
            return
        }
        
        // Update intersections using cached data
        for (wallID, wall) in Self.trackedVerticalPlanes {
            // Get cached anchor entity
            guard let wallEntity = WallInteractionSystem.anchorCache[wallID] else { continue }
            
            for (horizID, horizontal) in Self.trackedHorizontalPlanes {
                guard let horizEntity = WallInteractionSystem.anchorCache[horizID] else { continue }
                
                updateIntersectionLine(wall: wall, wallEntity: wallEntity,
                                     horizontal: horizontal, horizEntity: horizEntity,
                                     in: arView)
            }
        }
    }
    
    // MARK: - Intersection Line Creation
    private func updateIntersectionLine(wall: ARPlaneAnchor, wallEntity: AnchorEntity,
                                       horizontal: ARPlaneAnchor, horizEntity: AnchorEntity,
                                       in arView: ARView) {
        // Create unique key for this intersection
        let key = "\(wall.identifier.uuidString)_\(horizontal.identifier.uuidString)"
        
        // Get world transforms
        let wallTransform = wall.transform
        let horizontalTransform = horizontal.transform
        
        // Get plane centers in world space
        let wallCenter = SIMD3<Float>(
            wallTransform.columns.3.x + wall.center.x,
            wallTransform.columns.3.y + wall.center.y,
            wallTransform.columns.3.z + wall.center.z
        )
        
        let horizontalCenter = SIMD3<Float>(
            horizontalTransform.columns.3.x + horizontal.center.x,
            horizontalTransform.columns.3.y + horizontal.center.y,
            horizontalTransform.columns.3.z + horizontal.center.z
        )
        
        // Get wall right vector (X axis in local space)
        let wallRight = normalize(SIMD3<Float>(
            wallTransform.columns.0.x,
            wallTransform.columns.0.y,
            wallTransform.columns.0.z
        ))
        
        // For intersection, we want a line at the height of the horizontal plane
        // running along the width of the wall
        let intersectionHeight = horizontalCenter.y
        
        // Check if wall extends to this height
        let wallTop = wallCenter.y + wall.planeExtent.height / 2
        let wallBottom = wallCenter.y - wall.planeExtent.height / 2
        
        // Only create line if horizontal plane is within wall's vertical range
        if intersectionHeight < wallBottom - 0.1 || intersectionHeight > wallTop + 0.1 {
            // No intersection
            if let existingLine = Self.intersectionLines[key] {
                existingLine.removeFromParent()
                Self.intersectionLines.removeValue(forKey: key)
            }
            return
        }
        
        // Calculate line endpoints at the intersection height
        let halfWidth = wall.planeExtent.width / 2
        let lineCenter = SIMD3<Float>(wallCenter.x, intersectionHeight, wallCenter.z)
        let lineStart = lineCenter - wallRight * halfWidth
        let lineEnd = lineCenter + wallRight * halfWidth
        
        print("[PlaneIntersection] Creating line from \(lineStart) to \(lineEnd)")
        
        // Create or update the line
        if let existingLine = Self.intersectionLines[key] {
            // Update existing line position
            updateLineGeometry(line: existingLine, start: lineStart, end: lineEnd)
        } else {
            // Create new bright line
            let line = createBrightLine(from: lineStart, to: lineEnd)
            arView.scene.addAnchor(line)
            Self.intersectionLines[key] = line.children.first as? ModelEntity
        }
    }
    
    private func createBrightLine(from start: SIMD3<Float>, to end: SIMD3<Float>) -> AnchorEntity {
        let distance = simd_distance(start, end)
        let midpoint = (start + end) / 2
        
        // Create GLOWING material with emission
        var material = UnlitMaterial()
        // Super bright cyan/white color for emission effect
        material.color = .init(tint: .init(red: 0.3, green: 1.0, blue: 1.0, alpha: 1.0))
        material.blending = .transparent(opacity: .init(floatLiteral: 0.9))
        
        // Create rectangular tube (10cm x 10cm cross section)
        let mesh = MeshResource.generateBox(width: distance, height: 0.1, depth: 0.1, cornerRadius: 0.02)
        let tubeEntity = ModelEntity(mesh: mesh, materials: [material])
        tubeEntity.name = "IntersectionTube"
        
        // Add a glow effect with a second slightly larger transparent tube
        var glowMaterial = UnlitMaterial() 
        glowMaterial.color = .init(tint: .init(red: 0.3, green: 1.0, blue: 1.0, alpha: 1.0))
        glowMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.3))
        
        let glowMesh = MeshResource.generateBox(width: distance, height: 0.15, depth: 0.15, cornerRadius: 0.03)
        let glowEntity = ModelEntity(mesh: glowMesh, materials: [glowMaterial])
        glowEntity.name = "IntersectionGlow"
        
        // Position and orient the tube
        let anchor = AnchorEntity(world: midpoint)
        anchor.name = "IntersectionAnchor"
        
        // Calculate rotation to align with the line direction
        let direction = normalize(end - start)
        
        // If the line is horizontal (which it should be for wall-floor intersections)
        if abs(direction.y) < 0.1 {
            // Rotate to align with the horizontal direction
            let angle = atan2(direction.z, direction.x)
            tubeEntity.orientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))
            glowEntity.orientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))
        }
        
        anchor.addChild(glowEntity)  // Add glow first (behind)
        anchor.addChild(tubeEntity)   // Add tube on top
        
        print("[PlaneIntersection] Created glowing tube at \(midpoint)")
        return anchor
    }
    
    private func updateLineGeometry(line: ModelEntity, start: SIMD3<Float>, end: SIMD3<Float>) {
        let distance = simd_distance(start, end)
        let midpoint = (start + end) / 2
        
        // Update mesh for tube
        let mesh = MeshResource.generateBox(width: distance, height: 0.1, depth: 0.1, cornerRadius: 0.02)
        line.model?.mesh = mesh
        
        // Update glow if it exists
        if let anchor = line.parent as? AnchorEntity,
           let glowEntity = anchor.children.first(where: { $0.name == "IntersectionGlow" }) as? ModelEntity {
            let glowMesh = MeshResource.generateBox(width: distance, height: 0.15, depth: 0.15, cornerRadius: 0.03)
            glowEntity.model?.mesh = glowMesh
        }
        
        // Update position
        if let anchor = line.parent as? AnchorEntity {
            anchor.position = midpoint
        }
        
        // Update rotation
        let direction = normalize(end - start)
        if abs(direction.y) < 0.1 {
            let angle = atan2(direction.z, direction.x)
            line.orientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))
            
            // Update glow rotation too
            if let anchor = line.parent as? AnchorEntity,
               let glowEntity = anchor.children.first(where: { $0.name == "IntersectionGlow" }) as? ModelEntity {
                glowEntity.orientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))
            }
        }
    }
    
    // MARK: - Setup Helper
    static func setupSystem(arView: ARView) {
        sharedARView = arView
        print("[PlaneIntersectionSystem] Setup complete")
    }
    
    // MARK: - Diamond Solid Polygon Completion Algorithm
    
    private struct VirtualLine {
        let start: SIMD3<Float>
        let end: SIMD3<Float>
        let segmentId: UUID
        let type: String  // "start" or "end"
    }
    
    private static func getLineIntersection(_ line1Start: SIMD3<Float>, _ line1End: SIMD3<Float>,
                                           _ line2Start: SIMD3<Float>, _ line2End: SIMD3<Float>) -> SIMD3<Float>? {
        // Work in XZ plane (floor projection)
        let x1 = line1Start.x
        let z1 = line1Start.z
        let x2 = line1End.x
        let z2 = line1End.z
        
        let x3 = line2Start.x
        let z3 = line2Start.z
        let x4 = line2End.x
        let z4 = line2End.z
        
        let denominator = (x1 - x2) * (z3 - z4) - (z1 - z2) * (x3 - x4)
        
        // Lines are parallel
        if abs(denominator) < 0.0001 {
            return nil
        }
        
        let t = ((x1 - x3) * (z3 - z4) - (z1 - z3) * (x3 - x4)) / denominator
        
        // Calculate intersection point
        let intersectionX = x1 + t * (x2 - x1)
        let intersectionZ = z1 + t * (z2 - z1)
        
        return SIMD3<Float>(intersectionX, floorHeight, intersectionZ)
    }
    
    private static func getRaySegmentIntersection(_ rayStart: SIMD3<Float>, _ rayEnd: SIMD3<Float>,
                                                 _ segStart: SIMD3<Float>, _ segEnd: SIMD3<Float>) -> SIMD3<Float>? {
        // Work in XZ plane
        let x1 = rayStart.x
        let z1 = rayStart.z
        let x2 = rayEnd.x
        let z2 = rayEnd.z
        
        let x3 = segStart.x
        let z3 = segStart.z
        let x4 = segEnd.x
        let z4 = segEnd.z
        
        let denominator = (x1 - x2) * (z3 - z4) - (z1 - z2) * (x3 - x4)
        
        // Lines are parallel
        if abs(denominator) < 0.0001 {
            return nil
        }
        
        let t = ((x1 - x3) * (z3 - z4) - (z1 - z3) * (x3 - x4)) / denominator
        let s = ((x1 - x3) * (z1 - z2) - (z1 - z3) * (x1 - x2)) / denominator
        
        // Check if intersection is within segment bounds (0 <= s <= 1)
        // and along the ray direction (t can be any value for virtual lines)
        if s >= 0 && s <= 1 {
            let intersectionX = x3 + s * (x4 - x3)
            let intersectionZ = z3 + s * (z4 - z3)
            return SIMD3<Float>(intersectionX, floorHeight, intersectionZ)
        }
        
        return nil
    }
    
    static func computeRoomPolygon() {
        print("[PlaneIntersection] ===== DIAMOND SOLID ALGORITHM START =====")
        
        // Get wall segments 
        var segments: [(id: UUID, start: SIMD3<Float>, end: SIMD3<Float>)] = []
        for (wallID, _) in trackedVerticalPlanes {
            if let geometry = WallInteractionSystem.wallGeometryCache[wallID] {
                segments.append((wallID, geometry.start, geometry.end))
            }
        }
        
        guard segments.count >= 2 else {
            roomPolygon = []
            return
        }
        
        // Detect floor height
        if let firstFloor = trackedHorizontalPlanes.values.first {
            floorHeight = firstFloor.transform.columns.3.y + firstFloor.center.y
        }
        
        // Use Diamond Solid Algorithm
        let algorithm = DiamondSolidAlgorithm()
        
        // Add fragments (convert from 3D to 2D in XZ plane)
        for (i, segment) in segments.enumerated() {
            algorithm.addFragment(Fragment(
                id: segment.id.uuidString,
                start: DSPoint(x: segment.start.x, y: segment.start.z),  // Use X and Z (ignore Y)
                end: DSPoint(x: segment.end.x, y: segment.end.z)
            ))
        }
        
        // Execute algorithm
        let result = algorithm.execute()
        
        print("[PlaneIntersection] 🎯 Diamond Solid Results:")
        print("[PlaneIntersection]   - Vertices: \(result.vertices.count)")
        print("[PlaneIntersection]   - Connections: \(result.connections.count)")
        
        // Convert vertices back to 3D
        var polygonVertices: [SIMD3<Float>] = []
        for vertex in result.vertices {
            let vertex3D = SIMD3<Float>(vertex.x, floorHeight + 1.0, vertex.y)  // Y is floor + 1m, Z is from 2D y
            polygonVertices.append(vertex3D)
            print("[PlaneIntersection]   - Vertex at: (\(vertex.x), \(vertex.y)) -> 3D: \(vertex3D)")
        }
        
        // Create vertex and connection visualizations
        if !polygonVertices.isEmpty {
            createVertexVisualizations(vertices: polygonVertices, connections: result.connections)
        }
        
        // Order vertices by angle from centroid for polygon
        if polygonVertices.count >= 3 {
            let centroid = polygonVertices.reduce(SIMD3<Float>(0, 0, 0), +) / Float(polygonVertices.count)
            polygonVertices.sort { v1, v2 in
                let angle1 = atan2(v1.z - centroid.z, v1.x - centroid.x)
                let angle2 = atan2(v2.z - centroid.z, v2.x - centroid.x)
                return angle1 < angle2
            }
            
            roomPolygon = polygonVertices
            print("[PlaneIntersection] ✅ Diamond Solid found \(polygonVertices.count) vertices from \(segments.count) walls")
            
            // Create floor visualization
            createFloorPolygon()
            
            // Notify minimap to update
            WallInteractionSystem.minimapDirty = true
            WallInteractionSystem.coordinator?.wallUpdatePublisher.send()
        } else {
            roomPolygon = []
            print("[PlaneIntersection] ⚠️ No vertices found by Diamond Solid")
        }
        
        print("[PlaneIntersection] ===== DIAMOND SOLID ALGORITHM END =====")
    }
    
    private static func createFloorPolygon() {
        guard !roomPolygon.isEmpty, let arView = sharedARView else { return }
        
        // Remove existing floor polygon
        floorPolygonEntity?.removeFromParent()
        
        // Create mesh from polygon vertices
        var meshPositions: [SIMD3<Float>] = []
        var meshIndices: [UInt32] = []
        
        // Add center vertex
        let center = roomPolygon.reduce(SIMD3<Float>(0, 0, 0), +) / Float(roomPolygon.count)
        meshPositions.append(center)
        
        // Add polygon vertices
        meshPositions.append(contentsOf: roomPolygon)
        
        // Create triangles from center to each edge
        for i in 0..<roomPolygon.count {
            let next = (i + 1) % roomPolygon.count
            meshIndices.append(contentsOf: [
                0,  // Center
                UInt32(i + 1),  // Current vertex
                UInt32(next + 1)  // Next vertex
            ])
        }
        
        // Create mesh descriptor
        var meshDescriptor = MeshDescriptor()
        meshDescriptor.positions = MeshBuffer(meshPositions)
        meshDescriptor.primitives = .triangles(meshIndices)
        
        // Create mesh and material
        let mesh = try? MeshResource.generate(from: [meshDescriptor])
        var material = UnlitMaterial()
        material.color = .init(tint: UIColor.systemGreen.withAlphaComponent(0.3))
        
        if let mesh = mesh {
            // Create floor entity
            let floorEntity = ModelEntity(mesh: mesh, materials: [material])
            floorEntity.name = "FloorPolygon"
            floorEntity.position = SIMD3<Float>(0, 0, 0)
            
            // Add to scene at world origin
            let anchor = AnchorEntity(world: .zero)
            anchor.addChild(floorEntity)
            arView.scene.addAnchor(anchor)
            
            floorPolygonEntity = floorEntity
            print("[PlaneIntersection] Floor polygon created with \(roomPolygon.count) vertices")
        }
    }
    
    // Mark polygon dirty when walls change
    static func markPolygonDirty() {
        polygonDirty = true
    }
    
    // MARK: - Vertex Visualization
    private static func createVertexVisualizations(vertices: [SIMD3<Float>], connections: [(String, String)]) {
        guard let arView = sharedARView else { return }
        
        // Remove existing visualizations
        vertexEntities.forEach { $0.removeFromParent() }
        vertexEntities.removeAll()
        connectionEntities.forEach { $0.removeFromParent() }
        connectionEntities.removeAll()
        
        // Create bright sphere for each vertex
        var vertexMaterial = UnlitMaterial()
        vertexMaterial.color = .init(tint: UIColor.systemYellow)
        
        for (index, vertex) in vertices.enumerated() {
            let sphereMesh = MeshResource.generateSphere(radius: 0.15)  // 15cm radius spheres
            let sphereEntity = ModelEntity(mesh: sphereMesh, materials: [vertexMaterial])
            sphereEntity.name = "DSVertex_\(index)"
            
            // Create anchor at vertex position
            let anchor = AnchorEntity(world: vertex)
            anchor.addChild(sphereEntity)
            arView.scene.addAnchor(anchor)
            
            vertexEntities.append(sphereEntity)
            
            // Add text label showing vertex index
            print("[PlaneIntersection] Created vertex sphere \(index) at \(vertex)")
        }
        
        // Create connection lines between vertices based on connections
        var connectionMaterial = UnlitMaterial()
        connectionMaterial.color = .init(tint: UIColor.systemOrange.withAlphaComponent(0.8))
        
        for (index, connection) in connections.enumerated() {
            // Find vertices that match this connection (by fragment ID)
            // For now, just connect consecutive vertices
            if index < vertices.count - 1 {
                let start = vertices[index]
                let end = vertices[index + 1]
                
                let distance = simd_distance(start, end)
                let midpoint = (start + end) / 2
                
                // Create cylinder connecting vertices
                let cylinderMesh = MeshResource.generateBox(width: 0.05, height: distance, depth: 0.05)
                let cylinderEntity = ModelEntity(mesh: cylinderMesh, materials: [connectionMaterial])
                cylinderEntity.name = "DSConnection_\(index)"
                
                // Position and orient cylinder
                let anchor = AnchorEntity(world: midpoint)
                
                // Calculate rotation to align with connection direction
                let direction = normalize(end - start)
                let up = SIMD3<Float>(0, 1, 0)
                
                // If direction is not vertical
                if abs(dot(direction, up)) < 0.999 {
                    let axis = normalize(cross(up, direction))
                    let angle = acos(dot(up, direction))
                    cylinderEntity.orientation = simd_quatf(angle: angle, axis: axis)
                }
                
                anchor.addChild(cylinderEntity)
                arView.scene.addAnchor(anchor)
                
                connectionEntities.append(cylinderEntity)
                print("[PlaneIntersection] Created connection \(index): \(connection.0) <-> \(connection.1)")
            }
        }
        
        print("[PlaneIntersection] Created \(vertexEntities.count) vertex spheres and \(connectionEntities.count) connection lines")
    }
}