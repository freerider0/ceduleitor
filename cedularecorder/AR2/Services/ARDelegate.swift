import Foundation
import ARKit
import RealityKit

class AR2Delegate: NSObject, ARSessionDelegate {
    weak var tracker: AR2WallTracker?
    weak var coordinator: AR2WallCoordinator?
    let storage: AR2WallStorage

    private var lastUpdateTime: TimeInterval = 0
    private let updateInterval: TimeInterval = 0.5

    init(tracker: AR2WallTracker, coordinator: AR2WallCoordinator, storage: AR2WallStorage) {
        self.tracker = tracker
        self.coordinator = coordinator
        self.storage = storage
        super.init()
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        // Don't store planes automatically - wait for user interaction
        // ARKit already tracks all planes internally
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        // Only update planes that we're actually tracking
        anchors
            .compactMap { $0 as? ARPlaneAnchor }
            .filter { storage.trackedWalls.contains($0.identifier) }
            .forEach { plane in
                tracker?.updatePlane(plane)

                // Only check intersections periodically to avoid performance issues
                let currentTime = Date.timeIntervalSinceReferenceDate
                if currentTime - lastUpdateTime > updateInterval {
                    tracker?.checkIntersections(for: plane.identifier)
                    lastUpdateTime = currentTime
                }
            }
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        // NEVER remove tracked planes - user explicitly chose to track them
        // They should only be removed by user action (tap again or reset)
        anchors
            .compactMap { $0 as? ARPlaneAnchor }
            .filter { storage.trackedWalls.contains($0.identifier) }
            .forEach { plane in
                print("ARKit removed tracked plane \(plane.identifier) but keeping our visualization")
                // Do nothing - keep the visualization even if ARKit loses tracking
            }
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        coordinator?.updateTrackingState(frame.camera.trackingState)

        let transform = frame.camera.transform
        let position = SIMD2(transform.columns.3.x, transform.columns.3.z)
        let rotation = atan2(transform.columns.0.z, transform.columns.0.x)

        coordinator?.userPosition = position
        coordinator?.userRotation = rotation
    }
}