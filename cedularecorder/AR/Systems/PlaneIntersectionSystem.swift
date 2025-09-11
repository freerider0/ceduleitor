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
    
    private struct WallFragment {
        let id: UUID
        let start: SIMD3<Float>
        let end: SIMD3<Float>
        
        func directionVector() -> SIMD3<Float> {
            return normalize(end - start)
        }
    }
    
    private struct Ray {
        let fragmentId: UUID
        let origin: SIMD3<Float>
        let direction: SIMD3<Float>
        let fromEnd: Bool
        
        func intersectWith(_ other: Ray, floorHeight: Float) -> SIMD3<Float>? {
            // 2D intersection in XZ plane (ignoring Y for floor projection)
            let o1x = origin.x
            let o1z = origin.z
            let d1x = direction.x
            let d1z = direction.z
            
            let o2x = other.origin.x
            let o2z = other.origin.z
            let d2x = other.direction.x
            let d2z = other.direction.z
            
            let denom = d1x * d2z - d1z * d2x
            if abs(denom) < 1e-10 { return nil }  // Parallel rays
            
            let t1 = ((o2x - o1x) * d2z - (o2z - o1z) * d2x) / denom
            let t2 = ((o2x - o1x) * d1z - (o2z - o1z) * d1x) / denom
            
            // Only accept forward intersections
            if t1 >= 1e-10 && t2 >= 1e-10 {
                return SIMD3<Float>(
                    o1x + t1 * d1x,
                    floorHeight,  // Use passed floor height
                    o1z + t1 * d1z
                )
            }
            
            return nil
        }
    }
    
    static func computeRoomPolygon() {
        print("[PlaneIntersection] Computing room polygon from \(trackedVerticalPlanes.count) walls")
        
        // Convert wall geometry to fragments
        var fragments: [WallFragment] = []
        for (wallID, _) in trackedVerticalPlanes {
            if let geometry = WallInteractionSystem.wallGeometryCache[wallID] {
                fragments.append(WallFragment(
                    id: wallID,
                    start: geometry.start,
                    end: geometry.end
                ))
            }
        }
        
        guard fragments.count >= 2 else {
            roomPolygon = []
            return
        }
        
        // Detect floor height from horizontal planes
        if let firstFloor = trackedHorizontalPlanes.values.first {
            floorHeight = firstFloor.transform.columns.3.y + firstFloor.center.y
        }
        
        // Generate rays from fragment endpoints
        var rays: [Ray] = []
        for fragment in fragments {
            let direction = fragment.directionVector()
            
            // Ray from start going backward
            rays.append(Ray(
                fragmentId: fragment.id,
                origin: fragment.start,
                direction: SIMD3<Float>(-direction.x, 0, -direction.z),  // Project to XZ plane
                fromEnd: false
            ))
            
            // Ray from end going forward
            rays.append(Ray(
                fragmentId: fragment.id,
                origin: fragment.end,
                direction: SIMD3<Float>(direction.x, 0, direction.z),  // Project to XZ plane
                fromEnd: true
            ))
        }
        
        // Pre-expansion phase: find mutual first intersections
        var vertices: [SIMD3<Float>] = []
        var usedRays = Set<Int>()
        
        for i in 0..<rays.count {
            if usedRays.contains(i) { continue }
            
            for j in (i+1)..<rays.count {
                if usedRays.contains(j) { continue }
                if rays[i].fragmentId == rays[j].fragmentId { continue }  // Skip same fragment
                
                if let intersection = rays[i].intersectWith(rays[j], floorHeight: floorHeight) {
                    // Check if this is mutual first intersection (simplified check)
                    let dist1 = distance(rays[i].origin, intersection)
                    let dist2 = distance(rays[j].origin, intersection)
                    
                    // Accept if reasonably close (within room bounds)
                    if dist1 < 20.0 && dist2 < 20.0 {  // Max 20 meters
                        vertices.append(intersection)
                        usedRays.insert(i)
                        usedRays.insert(j)
                        break
                    }
                }
            }
        }
        
        // Handle remaining rays (deadlock resolution)
        let remainingRays = rays.enumerated().compactMap { !usedRays.contains($0.offset) ? $0.element : nil }
        if !remainingRays.isEmpty && vertices.count < fragments.count * 2 {
            // Find closest pairs among remaining rays
            for i in 0..<remainingRays.count {
                for j in (i+1)..<remainingRays.count {
                    if remainingRays[i].fragmentId == remainingRays[j].fragmentId { continue }
                    
                    if let intersection = remainingRays[i].intersectWith(remainingRays[j], floorHeight: floorHeight) {
                        vertices.append(intersection)
                        break
                    }
                }
            }
        }
        
        // Order vertices by angle from centroid to form polygon
        if vertices.count >= 3 {
            let centroid = vertices.reduce(SIMD3<Float>(0, 0, 0), +) / Float(vertices.count)
            vertices.sort { v1, v2 in
                let angle1 = atan2(v1.z - centroid.z, v1.x - centroid.x)
                let angle2 = atan2(v2.z - centroid.z, v2.x - centroid.x)
                return angle1 < angle2
            }
            
            roomPolygon = vertices
            print("[PlaneIntersection] Polygon completed with \(vertices.count) vertices")
            
            // Create floor visualization
            createFloorPolygon()
            
            // Notify minimap to update
            WallInteractionSystem.minimapDirty = true
            WallInteractionSystem.coordinator?.wallUpdatePublisher.send()
        } else {
            roomPolygon = []
            print("[PlaneIntersection] Not enough vertices for polygon")
        }
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
}