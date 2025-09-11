import RealityKit
import ARKit
import SwiftUI
import Combine

// MARK: - AR Session Coordinator
/// Simple coordinator that manages AR session setup and configuration
/// Everything else is handled by ECS Systems
class WallDetectionCoordinator: NSObject, ObservableObject {
    
    // MARK: - Published State
    @Published var trackingState: ARCamera.TrackingState = .notAvailable
    @Published var isReady = false
    
    // MARK: - Properties
    var arView: ARView?  // Made accessible for minimap
    private var cancellables = Set<AnyCancellable>()
    private var lastLoggedState: ARCamera.TrackingState?
    private var detectedPlanes: Set<UUID> = []
    static var lastLoggedSizes: [UUID: (Float, Float)] = [:]
    static var sphereEntity: ModelEntity?
    static var sphereAnchor: AnchorEntity?
    
    // MARK: - Setup
    @MainActor
    func setupARView(_ arView: ARView) {
        self.arView = arView
        print("[WallDetectionCoordinator] Setting up ARView")
        
        // MAXIMUM PERFORMANCE MODE - Only collision for tap detection
        // arView.environment.sceneUnderstanding.options.insert(.occlusion)   // DISABLED - for max performance
        // arView.environment.sceneUnderstanding.options.insert(.physics)     // DISABLED - not needed
        arView.environment.sceneUnderstanding.options.insert(.collision)      // Keep for tap detection ONLY
        // arView.environment.sceneUnderstanding.options.insert(.receivesLighting) // DISABLED - not needed
        
        // CONFIGURATION WITH FLOOR/CEILING DETECTION
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.vertical, .horizontal]  // Detect walls, floors, and ceilings
        // NO scene reconstruction - maximum performance!
        // NO environment texturing - save GPU/CPU
        // NO mesh generation - just plane detection
        
        print("[WallDetectionCoordinator] 🚀 MAXIMUM PERFORMANCE MODE")
        print("[WallDetectionCoordinator] - Plane detection: vertical only")
        print("[WallDetectionCoordinator] - Scene reconstruction: DISABLED")
        print("[WallDetectionCoordinator] - Occlusion: DISABLED")
        print("[WallDetectionCoordinator] - Ready for high-quality graphics!")
        
        // Set delegate to monitor plane detection
        arView.session.delegate = self
        
        arView.session.run(config)
        print("[WallDetectionCoordinator] AR session started")
        
        // Setup systems with ARView (registration already done in WallDetectionARView)
        setupSystems(in: arView)
        
        // Create the sphere indicator ONCE if not already created
        if WallDetectionCoordinator.sphereEntity == nil {
            // DISABLED - Sphere indicator not working properly
            // createPersistentSphereIndicator(in: arView)
        }
        
        // Subscribe to tracking state changes
        Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateTrackingState()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - System Setup (after registration)
    @MainActor
    private func setupSystems(in arView: ARView) {
        print("[AR] Setting up ECS systems with ARView...")
        
        // Setup systems with ARView (registration already done before ARView creation)
        WallClassificationSystem.setupSystem(arView: arView)
        WallInteractionSystem.setupSystem(arView: arView)
        WallCircleIndicatorSystem.setupSystem(arView: arView)
        PlaneIntersectionSystem.setupSystem(arView: arView)
        
        print("[AR] ✅ All systems setup complete - ECS will handle everything")
    }
    
    // MARK: - Tracking State
    private func updateTrackingState() {
        guard let frame = arView?.session.currentFrame else { return }
        
        trackingState = frame.camera.trackingState
        
        // Log tracking state changes
        if lastLoggedState != trackingState {
            print("[WallDetectionCoordinator] Tracking state: \(trackingState)")
            lastLoggedState = trackingState
        }
        
        switch trackingState {
        case .normal:
            isReady = true
        case .limited(_):
            isReady = false
        case .notAvailable:
            isReady = false
        }
    }
    
    // MARK: - Persistent Sphere Creation
    @MainActor
    private func createPersistentSphereIndicator(in arView: ARView) {
        // Create sphere mesh and material
        let sphereMesh = MeshResource.generateSphere(radius: 0.25) // 25cm radius
        
        // BRIGHT YELLOW material for maximum visibility
        var material = SimpleMaterial()
        material.color = .init(tint: UIColor.systemYellow)
        material.metallic = 0.0
        material.roughness = 0.3
        
        // Create sphere entity with geometry
        let sphere = ModelEntity(mesh: sphereMesh, materials: [material])
        sphere.name = "WallCenterSphereIndicator"
        
        // Add circle indicator component so system can find it
        sphere.components[CircleIndicatorComponent.self] = CircleIndicatorComponent()
        
        // Create world anchor
        let anchor = AnchorEntity(world: SIMD3<Float>(0, 0, -2))
        anchor.name = "WallSphereAnchor"
        anchor.addChild(sphere)
        
        // Add to scene
        arView.scene.addAnchor(anchor)
        
        // Store static references
        WallDetectionCoordinator.sphereEntity = sphere
        WallDetectionCoordinator.sphereAnchor = anchor
        
        print("[WallDetectionCoordinator] 🟡🟡🟡 PERSISTENT YELLOW SPHERE CREATED 🟡🟡🟡")
        print("[WallDetectionCoordinator] - Radius: 25cm")
        print("[WallDetectionCoordinator] - Color: Bright Yellow")
        print("[WallDetectionCoordinator] - Initial Position: \(anchor.position)")
        print("[WallDetectionCoordinator] - Has CircleIndicatorComponent: true")
    }
    
    // Static method for systems to access the sphere
    @MainActor
    static func getSphereEntity() -> (entity: ModelEntity?, anchor: AnchorEntity?) {
        return (sphereEntity, sphereAnchor)
    }
    
    // MARK: - Cleanup
    func stopSession() {
        arView?.session.pause()
        cancellables.removeAll()
    }
}

// MARK: - ARSessionDelegate
extension WallDetectionCoordinator: ARSessionDelegate {
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                let alignmentString = planeAnchor.alignment == .vertical ? "WALL" : 
                                     planeAnchor.classification == .floor ? "FLOOR" : "CEILING"
                
                print("[WallDetectionCoordinator] 🆕 New \(alignmentString) detected:")
                print("  - ID: \(planeAnchor.identifier)")
                print("  - Classification: \(planeAnchor.classification)")
                print("  - Size: \(planeAnchor.planeExtent.width)x\(planeAnchor.planeExtent.height)")
                
                // Check if this might be a merged plane replacing a tracked wall
                if planeAnchor.alignment == .vertical {
                    DispatchQueue.main.async { [weak self] in
                        self?.checkForMergedPlane(planeAnchor)
                    }
                }
                
                detectedPlanes.insert(planeAnchor.identifier)
                
                // Create anchor entity for all planes
                DispatchQueue.main.async { [weak self] in
                    self?.createWallAnchor(for: planeAnchor)
                }
            }
        }
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor,
               planeAnchor.alignment == .vertical {
                
                // Log detailed info about removed plane
                print("[WallDetectionCoordinator] ⚠️ ARKit removing plane:")
                print("  - ID: \(planeAnchor.identifier)")
                print("  - Classification: \(planeAnchor.classification)")
                print("  - Size: \(planeAnchor.planeExtent.width)x\(planeAnchor.planeExtent.height)")
                print("  - Center: \(planeAnchor.center)")
                
                // Handle on main thread to access WallInteractionSystem.trackedWalls
                DispatchQueue.main.async { [weak self] in
                    // Check if this wall was tracked by the user
                    if WallInteractionSystem.trackedWalls.contains(planeAnchor.identifier) {
                        // KEEP the wall tracked and visible - convert to world anchor
                        print("[WallDetectionCoordinator] ✅ PRESERVING tracked wall \(planeAnchor.identifier)")
                        print("  - Converting to world anchor to prevent loss")
                        self?.convertToWorldAnchor(for: planeAnchor)
                    } else {
                        // Not tracked - safe to remove
                        print("[WallDetectionCoordinator] Removing untracked plane \(planeAnchor.identifier)")
                        self?.removeWallAnchor(for: planeAnchor)
                    }
                    
                    // Clean up from detected planes set
                    self?.detectedPlanes.remove(planeAnchor.identifier)
                }
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        // ONLY update the wall at screen center for maximum performance
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let arView = self.arView else { return }
            
            // Raycast from screen center to find which wall is being looked at
            let screenCenter = CGPoint(x: arView.bounds.width / 2, y: arView.bounds.height / 2)
            let results = arView.raycast(from: screenCenter,
                                        allowing: .existingPlaneGeometry,
                                        alignment: .any)
            
            // Get the plane anchor being looked at
            let centerPlaneID = results.first?.anchor?.identifier
            
            // Only update the ONE plane in the center
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor,
                   planeAnchor.identifier == centerPlaneID {
                    // Update ONLY this plane
                    self.updateWallAnchor(for: planeAnchor)
                    break  // Stop after updating the center plane
                }
            }
        }
    }
    
    @MainActor
    private func createWallAnchor(for planeAnchor: ARPlaneAnchor) {
        guard let arView = arView else { return }
        
        // Create anchors for all planes (walls, floors, ceilings)
        // We'll handle them all now
        
        // Don't filter by size - let user decide what to track
        
        // Check if wall already exists for this anchor
        for anchor in arView.scene.anchors {
            if let anchorEntity = anchor as? AnchorEntity,
               anchorEntity.name.contains(planeAnchor.identifier.uuidString) {
                print("[WallDetectionCoordinator] Anchor already exists for plane: \(planeAnchor.identifier)")
                return
            }
        }
        
        // Log classification - wall vs window
        let classificationString: String
        switch planeAnchor.classification {
        case .wall:
            classificationString = "WALL"
        case .window:
            classificationString = "WINDOW"
        case .door:
            classificationString = "DOOR"
        case .floor:
            classificationString = "FLOOR"
        case .ceiling:
            classificationString = "CEILING"
        case .table:
            classificationString = "TABLE"
        case .seat:
            classificationString = "SEAT"
        case .none:
            classificationString = "NONE/UNKNOWN"
        @unknown default:
            classificationString = "UNKNOWN"
        }
        
        print("[WallDetectionCoordinator] Creating invisible anchor for plane: \(planeAnchor.identifier)")
        print("  - Classification: \(classificationString)")
        print("  - Initial size: \(planeAnchor.planeExtent.width)x\(planeAnchor.planeExtent.height)")
        
        // Log warning if it's a window
        if planeAnchor.classification == .window {
            print("  ⚠️ This is a WINDOW, not a wall!")
        }
        
        // Create anchor entity using the plane anchor directly
        let anchorEntity = AnchorEntity(anchor: planeAnchor)
        anchorEntity.name = "Anchor_\(planeAnchor.identifier.uuidString)"
        
        // Create invisible collision entity for hit testing (no mesh)
        let collisionEntity = Entity()
        collisionEntity.name = "Collision_\(planeAnchor.identifier.uuidString)"
        
        // Add tracking component (not tracked initially)
        collisionEntity.components[UserTrackedComponent.self] = UserTrackedComponent(
            isTracked: false,
            trackingColor: .systemGreen
        )
        
        // Add collision for tap detection (invisible)
        let shape = ShapeResource.generateBox(
            width: planeAnchor.planeExtent.width,
            height: planeAnchor.planeExtent.height,
            depth: 0.01
        )
        collisionEntity.components[CollisionComponent.self] = CollisionComponent(shapes: [shape])
        collisionEntity.components[InputTargetComponent.self] = InputTargetComponent()
        
        // Position at plane center (in local anchor space)
        collisionEntity.position = SIMD3(planeAnchor.center.x, planeAnchor.center.y, planeAnchor.center.z)
        
        // Add collision entity to anchor
        anchorEntity.addChild(collisionEntity)
        
        // Add to scene (no preview mesh - walls only visible when tracked)
        arView.scene.addAnchor(anchorEntity)
        
        print("[WallDetectionCoordinator] Invisible anchor created for plane: \(planeAnchor.identifier)")
        print("[WallDetectionCoordinator] Total planes detected: \(detectedPlanes.count)")
    }
    
    @MainActor
    private func checkForMergedPlane(_ newPlane: ARPlaneAnchor) {
        let newPlanePos = SIMD3<Float>(
            newPlane.transform.columns.3.x,
            newPlane.transform.columns.3.y,
            newPlane.transform.columns.3.z
        )
        
        // Check if any tracked wall positions are very close to this new plane
        for (trackedID, trackedPos) in WallInteractionSystem.trackedWallPositions {
            let distance = simd_distance(newPlanePos, trackedPos)
            
            // If within 50cm, this might be a merged/replaced plane
            if distance < 0.5 && !WallInteractionSystem.trackedWalls.contains(newPlane.identifier) {
                print("[WallDetectionCoordinator] ⚠️ POSSIBLE MERGE DETECTED!")
                print("  - New plane \(newPlane.identifier) is close to tracked wall \(trackedID)")
                print("  - Distance: \(distance)m")
                print("  - New plane size: \(newPlane.planeExtent.width)x\(newPlane.planeExtent.height)")
                
                // Mark for auto-tracking after anchor is created
                print("[WallDetectionCoordinator] 🔄 Marking merged plane for auto-tracking")
                
                // TODO: Implement auto-tracking of merged planes
                // For now, just preserve the position
                WallInteractionSystem.trackedWallPositions[newPlane.identifier] = newPlanePos
            }
        }
    }
    
    @MainActor
    private func convertToWorldAnchor(for planeAnchor: ARPlaneAnchor) {
        guard let arView = arView else { return }
        
        // Find the existing anchor entity
        for anchor in arView.scene.anchors {
            if let anchorEntity = anchor as? AnchorEntity,
               anchorEntity.name.contains(planeAnchor.identifier.uuidString) {
                
                // Get the current world transform
                let worldTransform = anchorEntity.transform.matrix
                
                // Remove the old anchor
                arView.scene.removeAnchor(anchorEntity)
                
                // Create a new world anchor at the same position
                let worldAnchor = AnchorEntity(world: worldTransform)
                worldAnchor.name = "WorldAnchor_\(planeAnchor.identifier.uuidString)"
                
                // Transfer all children to the new anchor
                for child in anchorEntity.children {
                    worldAnchor.addChild(child)
                }
                
                // Add the new world anchor to the scene
                arView.scene.addAnchor(worldAnchor)
                
                print("[WallDetectionCoordinator] Converted plane anchor to world anchor for tracked wall: \(planeAnchor.identifier)")
                break
            }
        }
    }
    
    @MainActor
    private func removeWallAnchor(for planeAnchor: ARPlaneAnchor) {
        guard let arView = arView else { return }
        
        // Find and remove the anchor entity
        for anchor in arView.scene.anchors {
            if let anchorEntity = anchor as? AnchorEntity,
               anchorEntity.name.contains(planeAnchor.identifier.uuidString) {
                
                // Remove from scene
                arView.scene.removeAnchor(anchorEntity)
                print("[WallDetectionCoordinator] Removed anchor entity for plane: \(planeAnchor.identifier)")
                break
            }
        }
    }
    
    @MainActor
    private func updateWallAnchor(for planeAnchor: ARPlaneAnchor) {
        guard let arView = arView else { return }
        
        // PERFORMANCE: Double-check this is the wall in the center
        let screenCenter = CGPoint(x: arView.bounds.width / 2, y: arView.bounds.height / 2)
        let results = arView.raycast(from: screenCenter,
                                    allowing: .existingPlaneGeometry,
                                    alignment: .any)
        
        // Skip if this isn't the center wall
        if results.first?.anchor?.identifier != planeAnchor.identifier {
            return
        }
        
        // Find existing anchor entity (could be regular or world anchor)
        for anchor in arView.scene.anchors {
            if let anchorEntity = anchor as? AnchorEntity,
               (anchorEntity.name.contains(planeAnchor.identifier.uuidString) || 
                anchorEntity.name.contains("WorldAnchor_\(planeAnchor.identifier.uuidString)")) {
                
                // Skip world anchors - they don't get updated
                if anchorEntity.name.starts(with: "WorldAnchor_") {
                    print("[WallDetectionCoordinator] Skipping update for world anchor (wall is persisted)")
                    return
                }
                
                // Update collision shape for hit detection
                if let collisionEntity = anchorEntity.children.first(where: { $0.name.starts(with: "Collision_") }) {
                    let shape = ShapeResource.generateBox(
                        width: planeAnchor.planeExtent.width,
                        height: planeAnchor.planeExtent.height,
                        depth: 0.01
                    )
                    collisionEntity.components[CollisionComponent.self] = CollisionComponent(shapes: [shape])
                    // Update position to match plane center
                    collisionEntity.position = SIMD3(planeAnchor.center.x, planeAnchor.center.y, planeAnchor.center.z)
                }
                
                // If tracked, only update if size or position changed significantly
                if WallInteractionSystem.trackedWalls.contains(planeAnchor.identifier) {
                    let lastSize = Self.lastLoggedSizes[planeAnchor.identifier] ?? (0, 0)
                    
                    // Only update if size changed more than 5cm (was 10cm)
                    if abs(lastSize.0 - planeAnchor.planeExtent.width) > 0.05 || 
                       abs(lastSize.1 - planeAnchor.planeExtent.height) > 0.05 {
                        
                        // Update the mesh
                        WallInteractionSystem.updateGeometryMesh(for: planeAnchor, in: anchorEntity)
                        
                        // Update stored size
                        Self.lastLoggedSizes[planeAnchor.identifier] = (planeAnchor.planeExtent.width, planeAnchor.planeExtent.height)
                        
                        // Log only significant changes (>10cm)
                        if abs(lastSize.0 - planeAnchor.planeExtent.width) > 0.1 || 
                           abs(lastSize.1 - planeAnchor.planeExtent.height) > 0.1 {
                            print("[WallDetectionCoordinator] Tracked wall \(planeAnchor.identifier) size changed: \(planeAnchor.planeExtent.width)x\(planeAnchor.planeExtent.height)")
                        }
                    }
                }
                
                break
            }
        }
    }
    
}