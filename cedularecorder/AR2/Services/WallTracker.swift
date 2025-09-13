import Foundation
import ARKit
import RealityKit
import UIKit

class AR2WallTracker {
    private let storage: AR2WallStorage
    private let analyticsService: AR2AnalyticsService
    weak var arView: ARView?

    init(storage: AR2WallStorage, analyticsService: AR2AnalyticsService) {
        self.storage = storage
        self.analyticsService = analyticsService
    }

    // MARK: - Add plane from ARKit

    func addPlane(_ plane: ARPlaneAnchor) {
        let wall = AR2Wall(
            id: plane.identifier,
            roomID: nil,
            transform: plane.transform,
            extent: plane.planeExtent,
            center: plane.center,
            classification: mapClassification(plane.classification),
            alignment: mapAlignment(plane.alignment),
            entity: nil,
            anchorEntity: nil,
            isTracked: false,
            intersectingWalls: [],
            adjacentRooms: []
        )

        storage.add(wall)
    }

    // MARK: - Update plane from ARKit

    func updatePlane(_ plane: ARPlaneAnchor) {
        guard var wall = storage.get(plane.identifier) else { return }

        wall.transform = plane.transform
        wall.extent = plane.planeExtent
        wall.center = plane.center

        if wall.isTracked {
            // Update mesh dimensions
            if let entity = wall.entity {
                // Update to a new box with updated dimensions
                let thickness: Float = 0.01  // 1cm thick
                entity.model?.mesh = .generateBox(size: [plane.planeExtent.width, thickness, plane.planeExtent.height])

                // Update position with new center
                entity.position = plane.center
            }

            // DON'T update anchor position - it should stay at initial position
            // The only transform we need is the -90° rotation on the entity
            // ARKit's transform was already applied when we created the anchor
        }

        storage.update(plane.identifier, with: wall)
    }

    func startTracking(_ wallID: UUID, in arView: ARView) {
        guard var wall = storage.get(wallID) else { return }

        // Only track if not already tracked
        if !wall.isTracked {
            // Create a simple box to highlight the detected plane
            // Use a very thin box as a plane
            let thickness: Float = 0.01  // 1cm thick
            let mesh = MeshResource.generateBox(size: [wall.extent.width, thickness, wall.extent.height])

            // Use UnlitMaterial for consistent color (doesn't need lighting)
            let entity = ModelEntity(
                mesh: mesh,
                materials: [UnlitMaterial(color: getColorForClassification(wall.classification))]
            )

            // No rotation needed - box is already in correct orientation
            // Apply center offset from ARKit
            entity.position = wall.center

            // Use OpacityComponent for transparency
            entity.components.set(OpacityComponent(opacity: 0.5))

            // Create anchor at plane's transform and add entity
            let anchor = AnchorEntity(world: wall.transform)
            anchor.addChild(entity)
            arView.scene.addAnchor(anchor)

            // Store references
            wall.entity = entity
            wall.anchorEntity = anchor
            wall.isTracked = true
            storage.trackedWalls.insert(wallID)
            storage.update(wallID, with: wall)

            analyticsService.trackWallDetected(classification: wall.classification)
        }
    }

    func stopTracking(_ wallID: UUID) {
        guard var wall = storage.get(wallID) else { return }

        if wall.isTracked {
            // Remove from scene
            wall.anchorEntity?.removeFromParent()

            // Clear references
            wall.entity = nil
            wall.anchorEntity = nil
            wall.isTracked = false
            storage.trackedWalls.remove(wallID)
            storage.update(wallID, with: wall)

            analyticsService.trackInteraction(action: "untrack_wall")
        }
    }

    func checkIntersections(for wallID: UUID) {
        guard var wall = storage.get(wallID) else { return }

        wall.intersectingWalls.removeAll()

        let wallPosition = wall.transform.columns.3.xyz

        for (otherID, otherWall) in storage.walls {
            if otherID != wallID {
                let otherPosition = otherWall.transform.columns.3.xyz
                let distance = simd_distance(wallPosition, otherPosition)
                let maxReach = (wall.extent.width + otherWall.extent.width) / 2

                if distance < maxReach {
                    wall.intersectingWalls.insert(otherID)
                }
            }
        }

        storage.update(wallID, with: wall)
    }

    // MARK: - Helper methods

    private func mapClassification(_ classification: ARPlaneAnchor.Classification) -> AR2PlaneClassification {
        switch classification {
        case .wall: return .wall
        case .door: return .door
        case .window: return .window
        case .floor: return .floor
        case .ceiling: return .ceiling
        case .table: return .table
        case .seat: return .seat
        default: return .none
        }
    }

    private func mapAlignment(_ alignment: ARPlaneAnchor.Alignment) -> AR2PlaneAlignment {
        switch alignment {
        case .horizontal: return .horizontal
        case .vertical: return .vertical
        default: return .any
        }
    }

    private func getColorForClassification(_ classification: AR2PlaneClassification) -> UIColor {
        switch classification {
        case .wall: return .green
        case .door: return .blue
        case .window: return .yellow
        case .floor: return .gray
        case .ceiling: return .lightGray
        default: return .white
        }
    }
}