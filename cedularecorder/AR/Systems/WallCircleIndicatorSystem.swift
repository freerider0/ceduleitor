import RealityKit
import ARKit
import SwiftUI

// MARK: - Circle Indicator Component
/// Component to mark the circle indicator entity
struct CircleIndicatorComponent: Component {
    var lastHitPoint: SIMD3<Float>?
}

// MARK: - Wall Circle Indicator System
/// ECS System that shows a beautiful circle on walls at screen center
@MainActor
class WallCircleIndicatorSystem: RealityKit.System {
    
    // MARK: - Properties
    private static weak var sharedARView: ARView?
    private var frameCount = 0
    
    // MARK: - Initialization  
    required init(scene: RealityKit.Scene) {
        self.frameCount = 0
        print("[WallCircleIndicatorSystem] ✅ System initialized - will update existing sphere")
    }
    
    // MARK: - Setup
    static func setARView(_ arView: ARView) {
        sharedARView = arView
    }
    
    
    
    // MARK: - Update Loop
    func update(context: SceneUpdateContext) {
        // DISABLED - Sphere indicator not working properly
        return
        
        /*
        frameCount += 1
        
        // Log that update is being called
        if frameCount <= 15 || frameCount % 360 == 0 {
            print("[WallCircleIndicator] 🔄 UPDATE CALLED - Frame \(frameCount)")
        }
        
        // Get ARView
        guard let arView = Self.sharedARView else {
            if frameCount % 60 == 0 {
                print("[WallCircleIndicator] ⚠️ ARView not set")
            }
            return
        }
        
        // Get the persistent sphere from coordinator
        let (sphere, anchor) = WallDetectionCoordinator.getSphereEntity()
        
        guard let sphereEntity = sphere,
              let sphereAnchor = anchor else {
            if frameCount % 60 == 0 {
                print("[WallCircleIndicator] ⚠️ Sphere not created yet")
            }
            return
        }
        
        // ALWAYS use screen center for the indicator
        let screenCenter: CGPoint
        
        // Check if ARView has valid bounds
        if arView.bounds.width <= 0 || arView.bounds.height <= 0 {
            // ARView not ready yet - use main screen bounds as fallback
            let screenBounds = UIScreen.main.bounds
            screenCenter = CGPoint(x: screenBounds.width / 2, y: screenBounds.height / 2)
            
            // Log this issue once per second
            if frameCount % 60 == 0 {
                print("[WallCircleIndicator] ⚠️ ARView bounds not ready: \(arView.bounds), using screen bounds: \(screenBounds)")
            }
        } else {
            // Use ARView center
            screenCenter = CGPoint(x: arView.bounds.width / 2, y: arView.bounds.height / 2)
        }
        
        // Raycast from screen center EVERY FRAME
        let results = arView.raycast(from: screenCenter,
                                    allowing: .existingPlaneGeometry,
                                    alignment: .vertical)
        
        // Log raycast results less frequently
        if frameCount <= 15 || frameCount % 180 == 0 {
            print("[WallCircleIndicator] 🎯 Raycasting from center: \(screenCenter)")
            print("[WallCircleIndicator] - Found \(results.count) hits")
        }
        
        if let hit = results.first {
            // Get hit position from transform
            let hitTransform = hit.worldTransform
            let hitPosition = SIMD3<Float>(
                hitTransform.columns.3.x,
                hitTransform.columns.3.y,
                hitTransform.columns.3.z
            )
            
            // Extract normal from ARKit plane - for vertical planes, normal is in the Z direction of local space
            // which maps to column 2 when transformed to world space
            var normal: SIMD3<Float>
            
            // Get the normal from the plane's orientation
            // For ARKit vertical planes, the normal points outward from the wall
            normal = normalize(SIMD3<Float>(
                hitTransform.columns.2.x,
                hitTransform.columns.2.y,
                hitTransform.columns.2.z
            ))
            
            // Place sphere 31cm from wall (radius + 1cm buffer)
            let spherePosition = hitPosition + normal * 0.31
            
            // Update anchor position
            sphereAnchor.position = spherePosition
            
            // Ensure sphere is visible
            sphereEntity.isEnabled = true
            
            // Log less frequently
            if frameCount % 180 == 0 {
                print("[WallCircleIndicator] 🎯 Sphere at: \(spherePosition)")
                print("[WallCircleIndicator] - Sphere enabled: \(sphereEntity.isEnabled)")
                print("[WallCircleIndicator] - Anchor position: \(sphereAnchor.position)")
                print("[WallCircleIndicator] - Is anchored: \(sphereAnchor.isAnchored)")
            }
            
            // No animation - keep sphere at constant size
            sphereEntity.scale = SIMD3<Float>(repeating: 1.0)
        } else {
            // No wall detected - place sphere 2 meters in front of camera
            if let frame = arView.session.currentFrame {
                let cameraTransform = frame.camera.transform
                
                // Get camera forward direction (negative Z in camera space)
                let forward = SIMD3<Float>(
                    -cameraTransform.columns.2.x,
                    -cameraTransform.columns.2.y,
                    -cameraTransform.columns.2.z
                )
                
                // Get camera position
                let cameraPos = SIMD3<Float>(
                    cameraTransform.columns.3.x,
                    cameraTransform.columns.3.y,
                    cameraTransform.columns.3.z
                )
                
                // Place sphere 2 meters in front
                let spherePosition = cameraPos + normalize(forward) * 2.0
                sphereAnchor.position = spherePosition
                
                // Make it visible
                sphereEntity.isEnabled = true
                
                if frameCount % 120 == 0 {
                    print("[WallCircleIndicator] 📍 No wall - sphere at: \(spherePosition)")
                }
            }
        }
        */
    }
    
    
    // MARK: - Setup Helper
    static func setupSystem(arView: ARView) {
        setARView(arView)
        
        // Check if bounds are valid
        if arView.bounds.width > 0 && arView.bounds.height > 0 {
            print("[WallCircleIndicatorSystem] ✅ Setup complete with valid bounds")
            print("[WallCircleIndicatorSystem] - ARView bounds: \(arView.bounds)")
        } else {
            print("[WallCircleIndicatorSystem] ⚠️ Setup called but bounds invalid: \(arView.bounds)")
        }
        
        print("[WallCircleIndicatorSystem] - ARView set: \(sharedARView != nil)")
    }
}

// MARK: - Helper Extensions

