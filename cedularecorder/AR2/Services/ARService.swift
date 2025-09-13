import Foundation
import ARKit
import RealityKit

class AR2Service {
    private var arView: ARView?

    func configureSession(arView: ARView, delegate: ARSessionDelegate) {
        self.arView = arView

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.vertical, .horizontal]
        config.environmentTexturing = .automatic

        arView.environment.sceneUnderstanding.options = [.collision]

        arView.session.delegate = delegate
        arView.session.run(config)
    }

    func pauseSession() {
        arView?.session.pause()
    }

    func resetSession() {
        guard let arView = arView else { return }
        arView.session.run(
            ARWorldTrackingConfiguration(),
            options: [.resetTracking, .removeExistingAnchors]
        )
    }

    func raycast(from point: CGPoint, in arView: ARView) -> ARRaycastResult? {
        arView.raycast(from: point, allowing: .existingPlaneGeometry, alignment: .any).first
    }

    func addEntity(_ entity: Entity, at anchor: ARAnchor) {
        let anchorEntity = AnchorEntity(world: anchor.transform)
        anchorEntity.addChild(entity)
        arView?.scene.addAnchor(anchorEntity)
    }
}