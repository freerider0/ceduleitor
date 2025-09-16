import SwiftUI
import ARKit
import RealityKit

struct AR2ViewContainer: UIViewRepresentable {
    let coordinator: AR2WallCoordinator

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        coordinator.setupAR(arView: arView)
        arView.setupForWallDetection()

        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        arView.addGestureRecognizer(tapGesture)

        let longPressGesture = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPressGesture.minimumPressDuration = 0.5
        arView.addGestureRecognizer(longPressGesture)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(wallCoordinator: coordinator)
    }

    class Coordinator: NSObject {
        let wallCoordinator: AR2WallCoordinator

        init(wallCoordinator: AR2WallCoordinator) {
            self.wallCoordinator = wallCoordinator
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView = gesture.view as? ARView else { return }
            let location = gesture.location(in: arView)
            wallCoordinator.handleTap(at: location, in: arView)
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  let arView = gesture.view as? ARView else { return }
            let location = gesture.location(in: arView)
            wallCoordinator.handleLongPress(at: location, in: arView)
        }
    }
}

extension ARView: ARCoachingOverlayViewDelegate {
    func setupForWallDetection() {
        environment.sceneUnderstanding.options = [.collision]

        #if DEBUG
        debugOptions = [.showStatistics]
        #endif

        // Add coaching overlay to guide users
        addCoachingOverlay()
    }

    func addCoachingOverlay() {
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.session = self.session
        coachingOverlay.goal = .anyPlane
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coachingOverlay.delegate = self
        self.addSubview(coachingOverlay)
    }

    // ARCoachingOverlayViewDelegate methods
    public func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
        // Coaching completed, user has scanned enough
    }
}