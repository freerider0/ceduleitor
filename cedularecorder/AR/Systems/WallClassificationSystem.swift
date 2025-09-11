import RealityKit
import ARKit
import Combine

// MARK: - Wall Classification System
/// ECS System that classifies and filters walls vs other surfaces
@MainActor
class WallClassificationSystem: RealityKit.System {
    
    // MARK: - Queries
    private static let wallQuery = EntityQuery(where: .has(UserTrackedComponent.self))
    
    // MARK: - Properties
    private static weak var sharedARView: ARView?
    private var subscriptions: [Cancellable] = []
    private var isSetup = false
    
    // Statistics
    static var detectedWallCount = 0
    static var ignoredSurfaceCount: [String: Int] = [:]  // Use String keys instead of Classification
    
    // MARK: - Initialization
    required init(scene: RealityKit.Scene) {
        print("[WallClassificationSystem] Initialized")
        // Subscriptions will be set up on first update if needed
    }
    
    // MARK: - Setup
    static func setARView(_ arView: ARView) {
        sharedARView = arView
    }
    
    private func setupSubscriptions(scene: RealityKit.Scene) {
        guard let arView = Self.sharedARView else { return }
        
        // Subscribe to anchor updates
        let anchorUpdates = scene.subscribe(to: SceneEvents.AnchoredStateChanged.self) { [weak self] event in
            self?.handleAnchorStateChange(event)
        }
        subscriptions.append(anchorUpdates)
    }
    
    // MARK: - Update Loop
    func update(context: SceneUpdateContext) {
        // Setup subscriptions on first update
        if !isSetup {
            isSetup = true
            setupSubscriptions(scene: context.scene)
        }
        
        // DISABLED - Processing every entity every frame kills performance
        // Walls don't need continuous updates once tracked
        /*
        // Process all wall entities each frame
        for entity in context.entities(matching: Self.wallQuery, updatingSystemWhen: .rendering) {
            guard let _ = entity.components[UserTrackedComponent.self] else { continue }
            
            // Update visualization if needed
            if let anchorEntity = entity.parent as? AnchorEntity,
               let planeAnchor = anchorEntity.anchor as? ARPlaneAnchor {
                updateVisualization(for: entity, classification: planeAnchor.classification)
            }
        }
        */
    }
    
    // MARK: - Event Handlers
    private func handleAnchorStateChange(_ event: SceneEvents.AnchoredStateChanged) {
        print("[WallClassification] Anchor state changed event received")
        guard let anchorEntity = event.anchor as? AnchorEntity else { 
            print("[WallClassification] Not an AnchorEntity")
            return 
        }
        
        // Check if this is a plane anchor
        if let anchor = anchorEntity.anchor,
           let planeAnchor = anchor as? ARPlaneAnchor,
           planeAnchor.alignment == .vertical {
            
            // Process based on classification
            processPlaneClassification(planeAnchor, anchorEntity: anchorEntity)
        }
    }
    
    // MARK: - Classification Processing
    private func processPlaneClassification(_ planeAnchor: ARPlaneAnchor, anchorEntity: AnchorEntity) {
        switch planeAnchor.classification {
        case .wall, .none:
            // Process as wall
            Self.detectedWallCount += 1
            createWallEntity(for: planeAnchor, in: anchorEntity)
            
        case .door:
            Self.ignoredSurfaceCount["door", default: 0] += 1
            print("[Classification] Ignored door")
            
        case .window:
            Self.ignoredSurfaceCount["window", default: 0] += 1
            print("[Classification] Ignored window")
            
        case .floor, .ceiling, .table, .seat:
            // These shouldn't appear as vertical planes, but handle them anyway
            let className = String(describing: planeAnchor.classification)
            Self.ignoredSurfaceCount[className, default: 0] += 1
            print("[Classification] Ignored \(className)")
            
        @unknown default:
            print("[Classification] Unknown classification")
        }
    }
    
    // MARK: - Entity Creation
    private func createWallEntity(for planeAnchor: ARPlaneAnchor, in anchorEntity: AnchorEntity) {
        // Check if entity already exists
        if anchorEntity.children.contains(where: { $0.components.has(UserTrackedComponent.self) }) {
            return
        }
        
        // Don't create visible mesh - just collision for detection
        // The visible mesh will be created by WallInteractionSystem when tracked
        print("[WallClassification] Wall classified! ID: \(planeAnchor.identifier)")
        print("[WallClassification] Size: \(planeAnchor.planeExtent.width)x\(planeAnchor.planeExtent.height)")
        print("[WallClassification] Total walls detected: \(Self.detectedWallCount)")
    }
    
    // MARK: - Visualization Updates
    private func updateVisualization(for entity: Entity, classification: ARPlaneAnchor.Classification) {
        guard let modelEntity = entity as? ModelEntity else { return }
        
        // Keep visualization simple - just update if classification changes
        // The actual visualization is handled by WallInteractionSystem when user tracks
    }
    
    // MARK: - Setup Helper
    static func setupSystem(arView: ARView) {
        setARView(arView)
        print("[WallClassificationSystem] Setup complete")
    }
}
