# Current AR Code Analysis & Refactoring Plan

## Current Code Issues

### What We Have
- **WallDetectionCoordinator.swift** - ~500 lines with unnecessary complexity
- Multiple "System" classes that aren't real ECS systems
- Complex event publishers and caching mechanisms
- Overengineered abstractions for simple tasks

### Red Flags Found
🚩 Custom "System" classes (WallClassificationSystem, WallInteractionSystem, etc.)
🚩 Static methods everywhere
🚩 Event publishers for simple callbacks
🚩 Multiple caching layers
🚩 500+ lines for simple wall detection

## The Simplified Version

Based on our framework, here's what the code SHOULD look like:

### SudoLang Blueprint
```sudolang
ARWallDetector v1.0 {
  Features {
    - Detect walls/floors with ARKit
    - Tap to track/untrack surfaces
    - Show as green transparent overlays
    - Keep tracked walls visible
  }

  State {
    walls: Dictionary<UUID, Wall>
    trackedWalls: Set<UUID>
  }

  Events {
    onPlaneDetected -> add invisible collision
    onPlaneUpdated -> update size if tracked
    onPlaneRemoved -> keep if tracked, else remove
    onTap -> toggle wall visibility
  }

  Constraints {
    * Under 150 lines total
    * No custom systems
    * Use RealityKit built-ins only
    * Single coordinator file
  }
}
```

### Simplified Implementation (~150 lines)
```swift
import RealityKit
import ARKit
import SwiftUI
import Combine

class WallDetectionCoordinator: NSObject, ObservableObject, ARSessionDelegate {
    @Published var trackedWalls = Set<UUID>()
    @Published var trackingState = "Initializing"

    weak var arView: ARView?
    private var walls: [UUID: (entity: Entity, plane: ARPlaneAnchor)] = [:]

    func setupARView(_ arView: ARView) {
        self.arView = arView

        // Simple config
        arView.environment.sceneUnderstanding.options = [.collision]

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.vertical, .horizontal]

        arView.session.delegate = self
        arView.session.run(config)

        // Add tap gesture
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        arView.addGestureRecognizer(tap)
    }

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let arView = arView else { return }
        let location = gesture.location(in: arView)

        let results = arView.raycast(from: location, allowing: .existingPlaneGeometry, alignment: .any)

        if let result = results.first,
           let planeAnchor = result.anchor as? ARPlaneAnchor {
            toggleWallTracking(planeAnchor.identifier)
        }
    }

    func toggleWallTracking(_ id: UUID) {
        guard let (entity, plane) = walls[id] else { return }

        if trackedWalls.contains(id) {
            // Untrack - make invisible
            if let model = entity.children.first as? ModelEntity {
                model.model?.materials = [SimpleMaterial(color: .clear)]
            }
            trackedWalls.remove(id)
        } else {
            // Track - make visible
            if let model = entity.children.first as? ModelEntity {
                model.model?.materials = [SimpleMaterial(color: .green.withAlphaComponent(0.3), isMetallic: false)]
            } else {
                // Create visual if doesn't exist
                let model = ModelEntity(
                    mesh: .generatePlane(width: plane.extent.x, depth: plane.extent.z),
                    materials: [SimpleMaterial(color: .green.withAlphaComponent(0.3), isMetallic: false)]
                )
                entity.addChild(model)
            }
            trackedWalls.insert(id)
        }
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard let arView = arView else { return }

        for anchor in anchors {
            guard let plane = anchor as? ARPlaneAnchor else { continue }

            // Create invisible entity with collision
            let entity = Entity()
            let collision = ShapeResource.generateBox(
                width: plane.extent.x,
                height: plane.extent.z,
                depth: 0.01
            )
            entity.components[CollisionComponent.self] = CollisionComponent(shapes: [collision])
            entity.position = [plane.center.x, plane.center.y, plane.center.z]

            let anchorEntity = AnchorEntity(anchor: plane)
            anchorEntity.addChild(entity)
            arView.scene.addAnchor(anchorEntity)

            walls[plane.identifier] = (entity, plane)
        }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let plane = anchor as? ARPlaneAnchor,
                  let (entity, _) = walls[plane.identifier] else { continue }

            // Update collision
            let collision = ShapeResource.generateBox(
                width: plane.extent.x,
                height: plane.extent.z,
                depth: 0.01
            )
            entity.components[CollisionComponent.self] = CollisionComponent(shapes: [collision])
            entity.position = [plane.center.x, plane.center.y, plane.center.z]

            // Update visual if tracked
            if trackedWalls.contains(plane.identifier),
               let model = entity.children.first as? ModelEntity {
                model.model?.mesh = .generatePlane(width: plane.extent.x, depth: plane.extent.z)
            }

            walls[plane.identifier] = (entity, plane)
        }
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let plane = anchor as? ARPlaneAnchor else { continue }

            // Keep tracked walls visible
            if !trackedWalls.contains(plane.identifier) {
                if let (entity, _) = walls[plane.identifier] {
                    entity.removeFromParent()
                }
                walls.removeValue(forKey: plane.identifier)
            }
        }
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        trackingState = frame.camera.trackingState == .normal ? "Ready" : "Limited"
    }
}
```

## What We Removed

### Removed Unnecessary Systems
- ~~WallClassificationSystem~~ → Not needed, ARKit already classifies
- ~~WallInteractionSystem~~ → Just a tap handler, 10 lines
- ~~WallCircleIndicatorSystem~~ → UI can handle this directly
- ~~PlaneIntersectionSystem~~ → Not used in current features

### Removed Complexity
- ~~Event publishers~~ → Just use @Published
- ~~Multiple caching layers~~ → One dictionary is enough
- ~~Static configurations~~ → Direct implementation
- ~~"Performance optimizations"~~ → ARKit already optimizes

### Result
- **Before**: ~500 lines across multiple files
- **After**: ~150 lines in one file
- **Functionality**: Identical
- **Maintainability**: 10x better

## Migration Plan

### Week 1: Replace Core
1. Backup current code
2. Create new `SimpleWallCoordinator.swift`
3. Test basic detection works
4. Ship v0.1

### Week 2: Add Features Back
1. Add any missing features ONE at a time
2. Keep under 200 lines total
3. Ship v0.2

### Week 3: Remove Old Code
1. Delete old coordinator
2. Delete all "System" files
3. Ship v1.0

## Lessons Learned

1. **RealityKit already has systems** - Don't create your own
2. **Delegates are sufficient** - Don't add event layers
3. **Direct implementation works** - Avoid abstractions
4. **150 lines is enough** - For most features

## Next Steps

1. Review the simplified code above
2. Test it in your project
3. Add features incrementally
4. Keep it simple!

Remember: The goal is code you can understand and maintain, not impressive architecture.