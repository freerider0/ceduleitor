# SudoLang Guide for AR/iOS Development

## What is SudoLang?

SudoLang is a pseudocode language for instructing AI. It describes WHAT you want, letting AI handle the HOW in platform-specific code.

## Why SudoLang for AR Development?

1. **Prevents Overengineering** - You define the exact structure
2. **Maintains Simplicity** - Natural language constraints
3. **Documents Design** - The blueprint IS your documentation
4. **Controls AI Output** - AI can only implement what you specify

## Basic SudoLang Structure for iOS/AR

```sudolang
AppName {
  platform: iOS
  frameworks: [SwiftUI, RealityKit, ARKit]

  State {
    // Data your app tracks
  }

  Features {
    // What the app does (ONE per version!)
  }

  Events {
    // User actions or system callbacks
  }

  Constraints {
    * Under X lines total
    * Use only built-in components
    * No custom systems
  }
}
```

## SudoLang Concepts → iOS Implementation

SudoLang doesn't need to "know" iOS. AI translates concepts:

```sudolang
// SudoLang Concept        →  iOS Implementation
observable state           →  @Published in ObservableObject
onPlaneDetected           →  ARSessionDelegate.session(_:didAdd:)
View with ARCanvas        →  UIViewRepresentable + ARView
tap handler              →  UITapGestureRecognizer
```

## Progressive Feature Development

### Version 0.1: Minimal Foundation
```sudolang
ARWallApp v0.1 {
  Features {
    Show AR camera view
  }

  Constraints {
    * Under 50 lines
    * Just camera, no detection
  }
}
```

### Version 0.2: Add Core Feature
```sudolang
ARWallApp v0.2 {
  // Previous features implied

  ADD Features {
    Detect planes and log to console
  }

  ADD Events {
    onPlaneDetected -> print("Found plane")
  }

  Constraints {
    * Under 80 lines total
  }
}
```

### Version 0.3: Add Interaction
```sudolang
ARWallApp v0.3 {
  // Previous features implied

  ADD State {
    trackedWalls: Set<UUID>
  }

  ADD Features {
    Tap wall to make visible (green)
  }

  ADD Events {
    onTap(location) -> toggleWallVisibility
  }

  Constraints {
    * Under 120 lines total
  }
}
```

## iOS-Specific SudoLang Patterns

### Pattern 1: Delegation
```sudolang
WallDetector {
  implements: ARSessionDelegate  // AI knows to create delegate methods

  events {
    planesDetected(planes)    // -> didAdd anchors
    planesUpdated(planes)     // -> didUpdate anchors
    planesLost(planes)        // -> didRemove anchors
  }
}
```

### Pattern 2: Observable State
```sudolang
ARCoordinator {
  @Observable {              // AI translates to @Published
    wallCount: Integer
    trackingQuality: String
  }
}
```

### Pattern 3: View Structure
```sudolang
MainView {
  body {
    ZStack {
      ARViewContainer()      // AI knows: UIViewRepresentable
      HUDOverlay {           // AI knows: SwiftUI overlay
        StatusBar()
        ControlButtons()
      }
    }
  }
}
```

## Complete AR App Example

```sudolang
# AR Wall Measurement App

ARMeasureApp {
  platform: iOS(17.0)
  frameworks: [SwiftUI, RealityKit, ARKit]

  ## State (Observable)
  State {
    detectedWalls: Dictionary<UUID, Wall>
    trackedWalls: Set<UUID>
    measurements: Array<Measurement>
    mode: "detect" | "measure"
  }

  ## Core Data Types
  Wall {
    id: UUID
    width: Float
    height: Float
    transform: Matrix4x4
    isTracked: Boolean
    entity?: ModelEntity  // Optional, only if tracked
  }

  Measurement {
    startPoint: Vector3
    endPoint: Vector3
    distance: Float
  }

  ## Features (v1.0)
  Features {
    - Detect walls with ARKit
    - Tap to track/untrack walls
    - Two-tap measurement
    - Show distance overlay
  }

  ## Event Handlers
  Events {
    // AR Events (delegate)
    onPlaneDetected(plane) -> addWall(plane)
    onPlaneUpdated(plane) -> updateWall(plane)
    onPlaneRemoved(plane) -> removeUntracked(plane)

    // User Events (gestures)
    onTap(location) -> {
      if mode == "detect" -> toggleWallTracking(location)
      if mode == "measure" -> addMeasurementPoint(location)
    }

    onModeSwitch -> toggleMode()
  }

  ## Implementation Flow
  detectMode {
    tap -> raycast -> findWall -> toggleVisibility
  }

  measureMode {
    firstTap -> store point
    secondTap -> calculate distance -> show result
  }

  ## Constraints
  constraints {
    * Total under 200 lines
    * No custom ECS systems
    * Use RealityKit built-in components only
    * Single coordinator file
    * Direct delegate implementation
    * No persistence in v1
  }
}
```

## Platform Hints for Better Translation

Add hints to help AI choose correct iOS patterns:

```sudolang
ARApp {
  ## Platform Hints
  platform: iOS
  pattern: MVVM
  coordinator: ObservableObject    // AI uses ObservableObject
  arLogic: ARSessionDelegate       // AI implements delegate
  gestures: UIGestureRecognizer    // AI adds gesture recognizers

  ## This helps AI translate correctly
}
```

## Common AR/iOS Patterns in SudoLang

### Raycast and Select
```sudolang
handleTap(screenPoint) {
  screenPoint
    |> raycast(allowing: .existingPlanes)
    |> getFirstHit
    |> extractEntity
    |> toggleSelection
}
```

### Plane to Wall Conversion
```sudolang
onPlaneDetected(arPlane) {
  arPlane
    |> createWall(width: arPlane.extent.x, height: arPlane.extent.y)
    |> addCollisionShape
    |> storeInDictionary
}
```

### State Updates
```sudolang
updateTrackingQuality(frame) {
  frame.trackingState
    |> mapToString("limited" | "normal" | "notAvailable")
    |> updatePublishedProperty
}
```

## Testing in SudoLang

```sudolang
Tests {
  test_CanDetectWall {
    setup: Start AR session
    action: Wait for plane detection
    verify: walls.count > 0
  }

  test_MeasureDistance {
    setup: Two 3D points
    action: Calculate distance
    verify: distance == expected ± 0.01
  }

  constraints {
    * No mocks
    * Test actual behavior
    * Under 10 lines each
  }
}
```

## The Power of Constraints

Always include constraints to prevent overengineering:

```sudolang
constraints {
  * Maximum X lines of code
  * No custom [systems/managers/coordinators]
  * Use only [specific frameworks]
  * Single file if possible
  * No external dependencies
  * Direct implementation only
  * No design patterns unless specified
  * Must be understandable by junior dev
}
```

## Converting SudoLang to Swift

When giving SudoLang to AI:

```
"Convert this SudoLang to iOS Swift:

Platform context:
- iOS 17+
- SwiftUI for UI
- RealityKit for 3D
- ARKit for tracking
- Follow Apple's patterns

[YOUR SUDOLANG]

Requirements:
- Exact implementation of blueprint
- No additions or improvements
- Use native iOS patterns
- Keep it simple and direct"
```

## Remember

- SudoLang describes INTENT, not implementation
- Keep blueprints under 50 lines
- One feature per version
- Always include constraints
- AI translates concepts to iOS patterns

The goal: You design the architecture, AI handles the syntax!