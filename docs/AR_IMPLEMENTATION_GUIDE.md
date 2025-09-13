# AR Implementation Guide: Building Simple ARKit/RealityKit Apps

## Understanding the iOS AR Stack

### The Minimal Components You Actually Need
```
SwiftUI → Your UI
  ↓
UIViewRepresentable → Bridge to ARView
  ↓
ARView → RealityKit's view
  ↓
ARSession → ARKit's brain
  ↓
ARSessionDelegate → Your event handler
```

### What Each Part Does
- **ARSession**: Detects planes, tracks device
- **ARSessionDelegate**: Tells you what ARKit found
- **RealityKit**: Shows 3D content
- **You**: Decide what to do with detected planes

## The Simplest Possible AR App

### Version 0.1: Just Camera (30 lines)
```swift
// ARApp.swift
import SwiftUI

@main
struct ARApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// ContentView.swift
import SwiftUI
import RealityKit

struct ContentView: View {
    var body: some View {
        ARViewContainer()
            .ignoresSafeArea()
    }
}

struct ARViewContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}
```

### Version 0.2: Add Plane Detection (60 lines)
```swift
// Add to ContentView.swift
class Coordinator: NSObject, ARSessionDelegate {
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let plane = anchor as? ARPlaneAnchor {
                print("Found plane: \(plane.extent)")
            }
        }
    }
}

// Update ARViewContainer
struct ARViewContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = .vertical
        arView.session.delegate = context.coordinator
        arView.session.run(config)
        return arView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}
```

## Key iOS/AR Concepts

### 1. Delegates Are Your Event System
```swift
// ARKit communicates through delegates, not callbacks
class Coordinator: ARSessionDelegate {
    // These get called automatically by ARKit:
    func session(didAdd anchors)      // New plane found
    func session(didUpdate anchors)    // Plane size changed
    func session(didRemove anchors)    // Plane lost
}
```

### 2. RealityKit's Built-in ECS
```swift
// You're always using ECS with RealityKit:
let entity = ModelEntity()                        // Entity
entity.components[ModelComponent.self] = ...      // Component
entity.components[CollisionComponent.self] = ...  // Component

// RealityKit's systems handle these automatically!
// You DON'T write systems - they exist already
```

### 3. Simple Tap Detection
```swift
// Add tap gesture to ARView
let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
arView.addGestureRecognizer(tapGesture)

@objc func handleTap(_ gesture: UITapGestureRecognizer) {
    let location = gesture.location(in: arView)

    // Method 1: Raycast for planes
    let results = arView.raycast(from: location, allowing: .existingPlaneGeometry)
    if let result = results.first {
        // Got a plane!
    }

    // Method 2: Hit test for entities
    if let entity = arView.entity(at: location) {
        // Got an entity!
    }
}
```

## Common AR Features: Simple Implementation

### Wall Detection and Visualization
```swift
class WallCoordinator: NSObject, ARSessionDelegate {
    var walls: [UUID: ModelEntity] = [:]

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let plane = anchor as? ARPlaneAnchor else { continue }

            // Create invisible wall with collision
            let wall = ModelEntity(
                mesh: .generatePlane(width: plane.extent.x, depth: plane.extent.z),
                materials: [SimpleMaterial(color: .clear)]  // Invisible!
            )
            wall.generateCollisionShapes(recursive: false)

            let anchorEntity = AnchorEntity(anchor: plane)
            anchorEntity.addChild(wall)
            arView.scene.addAnchor(anchorEntity)

            walls[plane.identifier] = wall
        }
    }

    func toggleWallVisibility(_ wallID: UUID) {
        guard let wall = walls[wallID] else { return }

        // Toggle between clear and green
        let isVisible = wall.model?.materials.first?.color != .clear
        wall.model?.materials = [SimpleMaterial(
            color: isVisible ? .clear : .green.withAlphaComponent(0.3)
        )]
    }
}
```

### Distance Measurement
```swift
// Simple two-point measurement
class MeasurementManager {
    var firstPoint: SIMD3<Float>?

    func handleTap(at location: CGPoint, in arView: ARView) {
        let results = arView.raycast(from: location, allowing: .estimatedPlane)
        guard let worldPosition = results.first?.worldTransform.translation else { return }

        if let first = firstPoint {
            // Second tap - calculate distance
            let distance = simd_distance(first, worldPosition)
            showDistance(distance)
            firstPoint = nil
        } else {
            // First tap - store point
            firstPoint = worldPosition
        }
    }

    func showDistance(_ distance: Float) {
        print("Distance: \(String(format: "%.2f", distance))m")
    }
}
```

### Furniture Placement
```swift
// Place 3D models in AR
class FurniturePlacer {
    func placeChair(at location: CGPoint, in arView: ARView) {
        let results = arView.raycast(from: location, allowing: .horizontal, alignment: .horizontal)
        guard let result = results.first else { return }

        // Simple box as chair placeholder
        let chair = ModelEntity(
            mesh: .generateBox(size: 0.5),
            materials: [SimpleMaterial(color: .brown)]
        )

        // Place at raycast position
        let anchor = AnchorEntity(world: result.worldTransform)
        anchor.addChild(chair)
        arView.scene.addAnchor(anchor)
    }
}
```

## Essential iOS/AR Patterns

### Pattern 1: ObservableObject for SwiftUI
```swift
class ARViewModel: ObservableObject {
    @Published var detectedWalls = 0
    @Published var trackingQuality = "Initializing"

    // SwiftUI automatically updates when these change
}
```

### Pattern 2: Coordinator for Delegation
```swift
struct ARViewContainer: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()  // Handles ARSessionDelegate
    }

    class Coordinator: NSObject, ARSessionDelegate {
        // AR events handled here
    }
}
```

### Pattern 3: Direct Entity Manipulation
```swift
// Don't create systems - just modify entities directly
entity.position = [1, 0, 0]           // RealityKit updates it
entity.scale = [2, 2, 2]              // RealityKit scales it
entity.model?.materials = [material]  // RealityKit renders it
```

## What NOT to Do

### ❌ Don't Create Custom Systems
```swift
// WRONG - RealityKit already has systems
class WallRenderSystem: System {
    // RealityKit already renders ModelComponents!
}
```

### ❌ Don't Mock AR Components
```swift
// WRONG - Can't mock Apple's frameworks
class MockARSession: ARSession {
    // This won't work properly
}
```

### ❌ Don't Overarchitect
```swift
// WRONG - Too many layers
WallManager → WallRepository → WallService → WallSystemCoordinator

// RIGHT - Direct implementation
WallCoordinator (handles everything in 100 lines)
```

## Progressive Feature Development Plan

### Week 1: Foundation
```
Day 1: AR camera view (30 lines)
Day 2: Add plane detection logging (50 lines)
Day 3: Show plane count in UI (70 lines)
Ship v0.1
```

### Week 2: Visualization
```
Day 1: Add invisible planes with collision (90 lines)
Day 2: Tap to show/hide planes (110 lines)
Day 3: Add color for selected planes (130 lines)
Ship v0.2
```

### Week 3: Interaction
```
Day 1: Add measurement mode (150 lines)
Day 2: Show distance label (170 lines)
Day 3: Add reset button (180 lines)
Ship v0.3
```

### Week 4: Polish
```
Day 1: Better UI feedback (200 lines)
Day 2: Add haptic feedback (210 lines)
Day 3: Final testing
Ship v1.0
```

## Common Gotchas and Solutions

### Device Capabilities
```swift
// Check if device supports AR
guard ARWorldTrackingConfiguration.isSupported else {
    // Show error message
    return
}
```

### Permissions
```swift
// Add to Info.plist:
<key>NSCameraUsageDescription</key>
<string>This app needs camera access for AR</string>
```

### Performance
```swift
// Disable expensive features for better performance
arView.environment.sceneUnderstanding.options = [.collision]
// NOT: [.collision, .occlusion, .physics, .receivesLighting]
```

### Tracking Quality
```swift
func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
    switch camera.trackingState {
    case .normal:
        statusLabel.text = "Tracking Good"
    case .limited(let reason):
        statusLabel.text = "Limited: \(reason)"
    case .notAvailable:
        statusLabel.text = "Not Available"
    }
}
```

## The Complete Minimal AR App Structure

```
ARApp/
├── ARApp.swift (15 lines)
├── ContentView.swift (40 lines)
├── ARViewContainer.swift (30 lines)
├── WallCoordinator.swift (100 lines)
└── Models/
    └── Wall.swift (10 lines)

Total: ~195 lines for fully functional AR wall detection app
```

## Remember

- ARKit provides the data (planes, tracking)
- RealityKit displays the content (3D models)
- You just connect them (100-200 lines)
- Don't create systems - RealityKit has them
- Don't mock AR - test calculations instead
- Ship weekly iterations, not monthly releases

The best AR app is the simple one that works!