import RealityKit
import ARKit
import SwiftUI

// MARK: - Tap Handler for Wall Interaction
@MainActor
class WallTapHandler: NSObject {
    weak var arView: ARView?
    
    init(arView: ARView) {
        self.arView = arView
        super.init()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
        print("[WallInteraction] Tap gesture added to ARView")
    }
    
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let arView = arView else { return }
        
        // Ignore tap location - always use screen center for raycast
        let screenCenter = CGPoint(x: arView.bounds.width / 2, y: arView.bounds.height / 2)
        print("[WallInteraction] Tap detected, using screen center: \(screenCenter)")
        
        // Use ARKit raycast from CENTER OF SCREEN to find ALL planes
        let results = arView.raycast(from: screenCenter,
                                    allowing: .existingPlaneGeometry,
                                    alignment: .any)  // Hit walls, floors, and ceilings
        
        print("[WallInteraction] ARKit raycast found \(results.count) vertical planes")
        
        if let hit = results.first,
           let planeAnchor = hit.anchor as? ARPlaneAnchor {
            // Log what type of surface was hit
            let classificationString: String
            switch planeAnchor.classification {
            case .wall:
                classificationString = "WALL"
            case .window:
                classificationString = "WINDOW"
            case .door:
                classificationString = "DOOR"
            default:
                classificationString = "OTHER"
            }
            
            print("[WallInteraction] Hit plane: \(planeAnchor.identifier)")
            print("[WallInteraction] - Classification: \(classificationString)")
            
            // Check if already tracked BEFORE looking for anchor
            if WallInteractionSystem.trackedWalls.contains(planeAnchor.identifier) {
                print("[WallInteraction] Already tracked (ID: \(planeAnchor.identifier))")
                return
            }
            
            // PERFORMANCE: Check cache first
            if let anchorEntity = WallInteractionSystem.anchorCache[planeAnchor.identifier] {
                print("[WallInteraction] Tracking new wall (from cache)")
                trackWall(anchorEntity: anchorEntity, planeAnchor: planeAnchor)
                return
            }
            
            // If not in cache, search (should rarely happen)
            for anchor in arView.scene.anchors {
                if let anchorEntity = anchor as? AnchorEntity {
                    // Check if this anchor's UUID matches
                    if anchorEntity.name.contains(planeAnchor.identifier.uuidString) {
                        print("[WallInteraction] Tracking new wall (found via search)")
                        // Cache it for next time
                        WallInteractionSystem.anchorCache[planeAnchor.identifier] = anchorEntity
                        trackWall(anchorEntity: anchorEntity, planeAnchor: planeAnchor)
                        return
                    }
                }
            }
            
            print("[WallInteraction] Warning: No anchor entity found for plane \(planeAnchor.identifier)")
        } else {
            print("[WallInteraction] No vertical plane found at tap location")
        }
    }
    
    private func trackWall(anchorEntity: AnchorEntity, planeAnchor: ARPlaneAnchor) {
        // No limit - track unlimited walls!
        
        // Update tracking component on collision entity
        if let collisionEntity = anchorEntity.children.first(where: { $0.name.starts(with: "Collision_") }) {
            var trackingComponent = collisionEntity.components[UserTrackedComponent.self] ?? UserTrackedComponent()
            trackingComponent.isTracked = true
            trackingComponent.trackingColor = WallInteractionSystem.wallColors[WallInteractionSystem.colorIndex % WallInteractionSystem.wallColors.count]
            collisionEntity.components[UserTrackedComponent.self] = trackingComponent
        }
        
        // Add to tracked set
        WallInteractionSystem.trackedWalls.insert(planeAnchor.identifier)
        let wallColor = WallInteractionSystem.wallColors[WallInteractionSystem.colorIndex % WallInteractionSystem.wallColors.count]
        WallInteractionSystem.colorIndex += 1
        
        // Store position for merge detection
        let worldPos = SIMD3<Float>(
            planeAnchor.transform.columns.3.x,
            planeAnchor.transform.columns.3.y,
            planeAnchor.transform.columns.3.z
        )
        WallInteractionSystem.trackedWallPositions[planeAnchor.identifier] = worldPos
        
        // CACHE EVERYTHING for instant access!
        WallInteractionSystem.anchorCache[planeAnchor.identifier] = anchorEntity
        WallInteractionSystem.colorCache[planeAnchor.identifier] = wallColor
        WallInteractionSystem.updateWallGeometryCache(for: planeAnchor)
        WallInteractionSystem.minimapDirty = true  // Mark minimap for update
        PlaneIntersectionSystem.polygonDirty = true  // Mark polygon for recomputation
        PlaneIntersectionSystem.intersectionsDirty = true  // Update intersections too
        
        // Store initial size to prevent unnecessary updates
        WallDetectionCoordinator.lastLoggedSizes[planeAnchor.identifier] = (planeAnchor.planeExtent.width, planeAnchor.planeExtent.height)
        
        // Create full geometry mesh for this wall
        WallInteractionSystem.createFullGeometryMesh(for: planeAnchor, in: anchorEntity)
        
        // Log what we're tracking
        let classificationString: String
        switch planeAnchor.classification {
        case .wall:
            classificationString = "WALL"
        case .window:
            classificationString = "WINDOW" 
        case .door:
            classificationString = "DOOR"
        default:
            classificationString = "OTHER"
        }
        
        print("[WallInteraction] Tracked \(classificationString). Total: \(WallInteractionSystem.trackedWalls.count)")
        print("[WallInteraction] - ID: \(planeAnchor.identifier)")
        print("[WallInteraction] - Size: \(planeAnchor.planeExtent.width)x\(planeAnchor.planeExtent.height)m")
        
        // PERFORMANCE: Publish update event
        WallInteractionSystem.coordinator?.wallUpdatePublisher.send()
    }
    
    private func addEdgeVisualization(to modelEntity: ModelEntity, color: UIColor) {
        // Remove existing edges if any
        removeEdgeVisualization(from: modelEntity)
        
        // Get dimensions from parent anchor
        guard let anchorEntity = modelEntity.parent as? AnchorEntity else { return }
        
        // Extract plane ID from anchor name
        guard anchorEntity.name.starts(with: "Anchor_") else { return }
        
        // Get dimensions from existing mesh or use defaults
        let edgeThickness: Float = 0.03
        let edgeMaterial = SimpleMaterial(color: color, roughness: 0.5, isMetallic: false)
        
        // Get the dimensions from the geometry entity if it exists
        var width: Float = 2.0  // Default width
        var height: Float = 2.0 // Default height
        
        if let geometryEntity = anchorEntity.children.first(where: { $0.name.starts(with: "Geometry_") }),
           let modelComponent = (geometryEntity as? ModelEntity)?.model {
            let bounds = modelComponent.mesh.bounds
            width = bounds.max.x - bounds.min.x
            height = bounds.max.y - bounds.min.y
        }
        
        let edges = [
            // Top
            ModelEntity(
                mesh: .generateBox(width: width, height: edgeThickness, depth: 0.01),
                materials: [edgeMaterial]
            ),
            // Bottom
            ModelEntity(
                mesh: .generateBox(width: width, height: edgeThickness, depth: 0.01),
                materials: [edgeMaterial]
            ),
            // Left
            ModelEntity(
                mesh: .generateBox(width: edgeThickness, height: height, depth: 0.01),
                materials: [edgeMaterial]
            ),
            // Right
            ModelEntity(
                mesh: .generateBox(width: edgeThickness, height: height, depth: 0.01),
                materials: [edgeMaterial]
            )
        ]
        
        // Position edges
        edges[0].position = SIMD3<Float>(0, height/2, 0.001)
        edges[1].position = SIMD3<Float>(0, -height/2, 0.001)
        edges[2].position = SIMD3<Float>(-width/2, 0, 0.001)
        edges[3].position = SIMD3<Float>(width/2, 0, 0.001)
        
        // Add as children
        edges.forEach { edge in
            edge.name = "edge"
            edge.components[OpacityComponent.self] = OpacityComponent(opacity: 1.0)
            modelEntity.addChild(edge)
        }
    }
    
    private func removeEdgeVisualization(from modelEntity: ModelEntity) {
        modelEntity.children.filter { $0.name == "edge" }.forEach { $0.removeFromParent() }
    }
}

// MARK: - Wall Interaction System
/// ECS System that handles user interactions with walls (tap to track)
@MainActor
class WallInteractionSystem: RealityKit.System {
    
    // MARK: - Static Properties
    static var trackedWalls: Set<UUID> = []
    static var wallColors: [UIColor] = [.systemBlue, .systemGreen, .systemOrange, .systemPurple, .systemRed, .systemYellow]
    static var colorIndex = 0
    private static var tapHandler: WallTapHandler?
    static weak var coordinator: WallDetectionCoordinator?
    
    // Store wall positions to detect merged planes
    static var trackedWallPositions: [UUID: SIMD3<Float>] = [:]
    
    // PERFORMANCE CACHES - Instant lookups instead of searching!
    static var anchorCache: [UUID: AnchorEntity] = [:]  // planeID -> AnchorEntity
    static var colorCache: [UUID: UIColor] = [:]  // planeID -> Color
    static var wallGeometryCache: [UUID: (center: SIMD3<Float>, start: SIMD3<Float>, end: SIMD3<Float>, width: Float)] = [:]
    static var minimapModels: [WallModel] = []  // Pre-calculated minimap data
    static var minimapDirty = false  // Only update when needed
    
    // MARK: - Queries
    private static let allWallsQuery = EntityQuery(where: .has(UserTrackedComponent.self))
    
    // MARK: - Initialization
    required init(scene: RealityKit.Scene) {
        print("[WallInteractionSystem] Initialized")
    }
    
    // MARK: - Update Loop
    func update(context: SceneUpdateContext) {
        // Don't update anything here - walls should stay as they are once tracked
    }
    
    // MARK: - Setup Helper
    static func setupSystem(arView: ARView) {
        // Setup tap handler
        tapHandler = WallTapHandler(arView: arView)
        print("[WallInteractionSystem] Setup complete")
    }
    
    // MARK: - Public Methods
    static func clearAllTrackedWalls(in scene: RealityKit.Scene) {
        trackedWalls.removeAll()
        colorIndex = 0
        
        // Clear polygon when walls are cleared
        PlaneIntersectionSystem.roomPolygon = []
        PlaneIntersectionSystem.floorPolygonEntity?.removeFromParent()
        PlaneIntersectionSystem.polygonDirty = false
        
        // Clear vertex visualizations
        PlaneIntersectionSystem.vertexEntities.forEach { $0.removeFromParent() }
        PlaneIntersectionSystem.vertexEntities.removeAll()
        PlaneIntersectionSystem.connectionEntities.forEach { $0.removeFromParent() }
        PlaneIntersectionSystem.connectionEntities.removeAll()
        
        // Reset all walls to preview state
        for entity in scene.performQuery(allWallsQuery) {
            if var trackingComponent = entity.components[UserTrackedComponent.self] {
                trackingComponent.isTracked = false
                entity.components[UserTrackedComponent.self] = trackingComponent
            }
            
            // Remove geometry visualization
            if entity.name.starts(with: "Geometry_") {
                entity.removeFromParent()
            }
        }
        
        print("[WallInteraction] All walls cleared")
    }
    
    // MARK: - Cache Management
    static func updateWallGeometryCache(for planeAnchor: ARPlaneAnchor) {
        let transform = planeAnchor.transform
        let localCenter = planeAnchor.center
        let worldCenter = transform * SIMD4<Float>(localCenter.x, localCenter.y, localCenter.z, 1.0)
        let center = SIMD3<Float>(worldCenter.x, worldCenter.y, worldCenter.z)
        
        let wallRight = normalize(SIMD3<Float>(
            transform.columns.0.x,
            transform.columns.0.y,
            transform.columns.0.z
        ))
        
        let halfWidth = planeAnchor.planeExtent.width / 2
        let start = center - wallRight * halfWidth
        let end = center + wallRight * halfWidth
        
        wallGeometryCache[planeAnchor.identifier] = (center, start, end, planeAnchor.planeExtent.width)
    }
    
    // MARK: - Geometry Creation
    
    // Optimized update method - only updates mesh, not materials or components
    static func updateGeometryMesh(for planeAnchor: ARPlaneAnchor, in anchorEntity: AnchorEntity) {
        // Find existing wall geometry
        guard let existingWall = anchorEntity.children.first(where: { $0.name.starts(with: "Geometry_") }) as? ModelEntity else {
            // No existing wall, create new one
            createFullGeometryMesh(for: planeAnchor, in: anchorEntity)
            return
        }
        
        // Just update the mesh - don't recreate materials or components
        let mesh = MeshResource.generatePlane(
            width: planeAnchor.planeExtent.width,
            height: planeAnchor.planeExtent.height,
            cornerRadius: 0
        )
        existingWall.model?.mesh = mesh
        
        // Update position to match plane center
        existingWall.position = SIMD3(planeAnchor.center.x, planeAnchor.center.y, planeAnchor.center.z)
        
        // Update cache for minimap
        updateWallGeometryCache(for: planeAnchor)
        minimapDirty = true
        
        // PERFORMANCE: Publish update event
        coordinator?.wallUpdatePublisher.send()
    }
    
    static func createFullGeometryMesh(for planeAnchor: ARPlaneAnchor, in anchorEntity: AnchorEntity) {
        // Check if geometry already exists - if so, just update it instead of recreating
        if let existingWall = anchorEntity.children.first(where: { $0.name.starts(with: "Geometry_") }) as? ModelEntity {
            // Wall already exists, update its mesh and position
            let mesh = MeshResource.generatePlane(
                width: planeAnchor.planeExtent.width,
                height: planeAnchor.planeExtent.height,
                cornerRadius: 0
            )
            existingWall.model?.mesh = mesh
            
            // Update position to match plane center
            existingWall.position = SIMD3(planeAnchor.center.x, planeAnchor.center.y, planeAnchor.center.z)
            
            // Keep the same rotation
            existingWall.orientation = simd_quatf(angle: -.pi/2, axis: SIMD3<Float>(1, 0, 0))
            return
        }
        
        // Create mesh for new wall - use plane for vertical walls
        // generatePlane creates a plane in XY plane (facing +Z)
        let mesh = MeshResource.generatePlane(
            width: planeAnchor.planeExtent.width,
            height: planeAnchor.planeExtent.height,
            cornerRadius: 0
        )
        
        // Get tracking component for color
        let collisionEntity = anchorEntity.children.first { $0.name.starts(with: "Collision_") }
        let trackingComponent: UserTrackedComponent? = collisionEntity?.components[UserTrackedComponent.self]
        let color = trackingComponent?.trackingColor ?? .systemGreen
        
        // Create unlit material for better visibility - doesn't depend on lighting
        var material = UnlitMaterial()
        material.color = .init(tint: color)
        
        // Find and remove existing geometry entity
        anchorEntity.children.forEach { child in
            if child.name.starts(with: "Geometry_") {
                child.removeFromParent()
            }
        }
        
        // Create new geometry entity
        let wallEntity = ModelEntity(mesh: mesh, materials: [material])
        wallEntity.name = "Geometry_\(planeAnchor.identifier.uuidString)"
        
        // Rotate -90 degrees around X-axis to make the plane vertical
        // generatePlane creates a horizontal plane, we need it vertical
        wallEntity.orientation = simd_quatf(angle: -.pi/2, axis: SIMD3<Float>(1, 0, 0))
        
        // Position at plane center (no offset needed with proper occlusion)
        wallEntity.position = SIMD3(planeAnchor.center.x, planeAnchor.center.y, planeAnchor.center.z)
        
        // Set opacity using OpacityComponent
        wallEntity.components[OpacityComponent.self] = OpacityComponent(opacity: 0.7)
        
        // Add to anchor
        anchorEntity.addChild(wallEntity)
        
        print("[WallInteraction] ✅ Full geometry mesh created for wall: \(planeAnchor.identifier)")
        print("[WallInteraction] - Size: \(planeAnchor.planeExtent.width)x\(planeAnchor.planeExtent.height)")
        print("[WallInteraction] - Color: \(color)")
        print("[WallInteraction] - Opacity: 0.7")
        print("[WallInteraction] - Position: Local (0,0,0) in anchor space")
    }
}