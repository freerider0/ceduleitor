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
    
    // MARK: - Initialization
    required init(scene: RealityKit.Scene) {
        print("[PlaneIntersectionSystem] Initialized")
    }
    
    // MARK: - Properties
    private var frameCount = 0
    
    // MARK: - Update Loop
    func update(context: SceneUpdateContext) {
        frameCount += 1
        
        // Only update every 30 frames for performance
        guard frameCount % 30 == 0 else { return }
        
        // Update intersection lines between tracked planes
        guard let arView = Self.sharedARView else { 
            if frameCount % 120 == 0 {
                print("[PlaneIntersection] No ARView set")
            }
            return 
        }
        
        // Get all tracked walls
        let trackedWallIDs = WallInteractionSystem.trackedWalls
        
        if frameCount % 120 == 0 && !trackedWallIDs.isEmpty {
            print("[PlaneIntersection] Checking intersections for \(trackedWallIDs.count) tracked walls")
        }
        
        // Find all plane anchors - check session anchors instead
        var verticalPlanes: [(ARPlaneAnchor, AnchorEntity)] = []
        var horizontalPlanes: [(ARPlaneAnchor, AnchorEntity)] = []
        
        // Get planes from AR session
        if let anchors = arView.session.currentFrame?.anchors {
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor {
                    // Find the corresponding entity
                    for sceneAnchor in arView.scene.anchors {
                        if let anchorEntity = sceneAnchor as? AnchorEntity,
                           let entityAnchor = anchorEntity.anchor as? ARPlaneAnchor,
                           entityAnchor.identifier == planeAnchor.identifier {
                            
                            if planeAnchor.alignment == .vertical && trackedWallIDs.contains(planeAnchor.identifier) {
                                verticalPlanes.append((planeAnchor, anchorEntity))
                            } else if planeAnchor.alignment == .horizontal {
                                // Check if floor or ceiling is tracked
                                if trackedWallIDs.contains(planeAnchor.identifier) {
                                    horizontalPlanes.append((planeAnchor, anchorEntity))
                                }
                            }
                            break
                        }
                    }
                }
            }
        }
        
        if frameCount % 120 == 0 && (!verticalPlanes.isEmpty || !horizontalPlanes.isEmpty) {
            print("[PlaneIntersection] Found \(verticalPlanes.count) walls, \(horizontalPlanes.count) floors/ceilings")
        }
        
        // Create/update intersection lines between walls and floors/ceilings
        for (wall, wallEntity) in verticalPlanes {
            for (horizontal, horizEntity) in horizontalPlanes {
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
}