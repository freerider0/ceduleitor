import SwiftUI
import RealityKit
import ARKit
import Combine

// ================================================================================
// MARK: - Room AR Component
// ================================================================================

/// AR camera component for room capture
struct RoomARComponent: UIViewRepresentable {
    @ObservedObject var detector: RoomShapeDetector
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Configure AR session for plane detection
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        arView.session.run(configuration)
        
        // Setup coordinator
        context.coordinator.setup(arView: arView)
        
        // Set session delegate for frame updates
        arView.session.delegate = context.coordinator
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.updateVisualization()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(detector: detector)
    }
    
    // ================================================================================
    // MARK: - Coordinator
    // ================================================================================
    
    class Coordinator: NSObject, ARSessionDelegate {
        
        // MARK: - Properties
        
        private let detector: RoomShapeDetector
        private weak var arView: ARView?
        
        // Components
        private let ringIndicator = RingIndicator()
        private let previewIndicator = PreviewIndicator()
        private let roomVisualization = RoomVisualization()
        
        // Store last wall detection for tap capture
        private var lastDetectedWallResult: ARRaycastResult?
        
        // Subscriptions
        private var cancellables = Set<AnyCancellable>()
        
        // MARK: - Initialization
        
        init(detector: RoomShapeDetector) {
            self.detector = detector
            super.init()
            
            // Subscribe to detector changes
            detector.$corners
                .sink { [weak self] _ in
                    self?.updateVisualization()
                }
                .store(in: &cancellables)
        }
        
        // ================================================================================
        // MARK: - Setup
        // ================================================================================
        
        @MainActor
        func setup(arView: ARView) {
            self.arView = arView
            
            // Setup components
            ringIndicator.setup(in: arView)
            previewIndicator.setup(in: arView)
            roomVisualization.setup(in: arView)
            
            // Setup tap gesture
            let tapGesture = UITapGestureRecognizer(
                target: self,
                action: #selector(handleTap(_:))
            )
            arView.addGestureRecognizer(tapGesture)
        }
        
        // ================================================================================
        // MARK: - ARSessionDelegate (Real-time Updates at 60fps)
        // ================================================================================
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            updateRealTimeIndicators()
        }
        
        /// Update indicators that need real-time feedback
        private func updateRealTimeIndicators() {
            guard let arView = arView else { return }
            
            let centerPoint = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
            
            // Perform raycasts for both surface types
            let horizontalResults = arView.raycast(
                from: centerPoint,
                allowing: .existingPlaneGeometry,
                alignment: .horizontal
            )
            
            let verticalResults = arView.raycast(
                from: centerPoint,
                allowing: .existingPlaneGeometry,
                alignment: .vertical
            )
            
            // Update based on what we hit
            if let verticalResult = verticalResults.first {
                handleVerticalSurface(verticalResult)
            } else if let horizontalResult = horizontalResults.first {
                handleHorizontalSurface(horizontalResult)
            } else {
                handleNoSurface()
            }
        }
        
        // ================================================================================
        // MARK: - Surface Handling
        // ================================================================================
        
        private func handleVerticalSurface(_ result: ARRaycastResult) {
            // Show green ring on wall
            ringIndicator.update(with: result, isVertical: true)
            
            // Hide floor preview in wall mode
            if detector.mode == .wallIntersection {
                detector.updateWallDetection(wallDetected: true)
                previewIndicator.setVisible(false)
                
                // Store result for tap capture
                lastDetectedWallResult = result
            }
        }
        
        private func handleHorizontalSurface(_ result: ARRaycastResult) {
            // Show blue ring on floor
            ringIndicator.update(with: result, isVertical: false)
            
            // Update floor preview for corner mode
            if detector.mode == .cornerPointing {
                previewIndicator.update(with: result)
                previewIndicator.setVisible(true)
                detector.updatePreview(from: result)
            }
        }
        
        private func handleNoSurface() {
            ringIndicator.hide()
            previewIndicator.setVisible(false)
            
            if detector.mode == .wallIntersection {
                detector.updateWallDetection(wallDetected: false)
                lastDetectedWallResult = nil
            }
        }
        
        // ================================================================================
        // MARK: - User Interaction
        // ================================================================================
        
        @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView = arView else { return }
            
            let centerPoint = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
            
            if detector.mode == .cornerPointing {
                handleCornerTap(at: centerPoint)
            } else {
                handleWallTap(at: centerPoint)
            }
        }
        
        private func handleCornerTap(at point: CGPoint) {
            guard let arView = arView else { return }
            
            let results = arView.raycast(
                from: point,
                allowing: .existingPlaneGeometry,
                alignment: .horizontal
            )
            
            if let result = results.first {
                _ = detector.addCornerPoint(from: result)
                previewIndicator.flash()
            }
        }
        
        private func handleWallTap(at point: CGPoint) {
            // Use the stored wall result if available
            guard let result = lastDetectedWallResult else { return }
            
            if detector.captureWall(from: result) {
                // Flash indicator to show capture
                ringIndicator.flash()
                
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                // Force immediate visualization update to show new corners
                updateVisualization()
            }
        }
        
        // ================================================================================
        // MARK: - Visualization Updates
        // ================================================================================
        
        func updateVisualization() {
            roomVisualization.update(
                corners: detector.corners,
                isComplete: detector.isComplete
            )
        }
        
    }
}