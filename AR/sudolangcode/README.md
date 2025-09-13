# AR System MVVM Architecture

This folder contains the SudoLang specifications for the AR wall detection system, organized following MVVM pattern.

## Folder Structure

```
sudolangcode/
├── Models/           # Data structures & storage
│   ├── Models.sudo       # Wall, Room, WallSegment models
│   └── WallStorage.sudo  # Storage management
│
├── Views/            # UI Components (no business logic)
│   ├── WallDetectionView.sudo  # Main AR view
│   ├── MiniMapView.sudo        # 2D minimap visualization
│   └── ARViewContainer.sudo    # AR container view
│
├── ViewModels/       # UI State & Orchestration
│   └── WallCoordinator.sudo    # Main coordinator (@Published states)
│
├── UseCases/         # Business Logic Layer
│   ├── UseCases.sudo           # Wall tracking, room creation logic
│   └── BusinessLogic.sudo      # Business rules & validation
│
├── Services/         # External Dependencies
│   └── Services.sudo           # ARService, PersistenceService, GeometryService
│
└── Infrastructure/   # AR-specific Components
    ├── ARDelegate.sudo         # ARSessionDelegate implementation
    ├── WallDetector.sudo       # Wall detection logic
    └── WallTracker.sudo        # Wall tracking logic
```

## Architecture Flow

1. **User Interaction** → View
2. **View** → ViewModel (user action)
3. **ViewModel** → UseCase (business logic)
4. **UseCase** → Service (external operation)
5. **Service** → Returns result
6. **UseCase** → Applies business rules
7. **ViewModel** → Updates @Published state
8. **View** → Re-renders with new state

## Key Principles

- **Models**: Pure data, no logic
- **Views**: UI only, no business logic
- **ViewModels**: Orchestration, no business rules
- **UseCases**: All business logic lives here
- **Services**: External dependencies (ARKit, file system, etc.)
- **Infrastructure**: AR-specific implementations

## File Count
- Total: ~420 lines of SudoLang
- 11 files organized by responsibility
- Each file ≤ 150 lines (following anti-overengineering framework)