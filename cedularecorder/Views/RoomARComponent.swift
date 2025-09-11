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
                    Task { @MainActor in
                        self?.updateVisualization()
                    }
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
            
            // In wall mode, prioritize floor detection if not yet set
            if detector.mode == .wallIntersection && detector.floorHeight == 0 {
                // Look for floor first
                if let horizontalResult = horizontalResults.first {
                    handleHorizontalSurface(horizontalResult)
                } else {
                    handleNoSurface()
                }
            } else {
                // Normal priority: walls over floor
                if let verticalResult = verticalResults.first {
                    handleVerticalSurface(verticalResult)
                } else if let horizontalResult = horizontalResults.first {
                    handleHorizontalSurface(horizontalResult)
                } else {
                    handleNoSurface()
                }
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
            
            // Handle based on mode
            if detector.mode == .cornerPointing {
                // Update floor preview for corner mode
                previewIndicator.update(with: result)
                previewIndicator.setVisible(true)
                detector.updatePreview(from: result)
            } else if detector.mode == .wallIntersection {
                // In wall mode, update floor height continuously
                detector.updatePreview(from: result)
                
                // Show preview indicator on floor if floor not set
                if detector.floorHeight == 0 {
                    previewIndicator.update(with: result)
                    previewIndicator.setVisible(true)
                } else {
                    previewIndicator.setVisible(false)
                }
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
            } else if detector.mode == .wallIntersection {
                // In wall mode, check if we need to set floor first
                if detector.floorHeight == 0 {
                    handleFloorTap(at: centerPoint)
                } else {
                    // Simply try to capture any wall at the center point
                    handleWallTap(at: centerPoint)
                }
            }
        }
        
        private func handleFloorTap(at point: CGPoint) {
            guard let arView = arView else { return }
            
            let results = arView.raycast(
                from: point,
                allowing: .existingPlaneGeometry,
                alignment: .horizontal
            )
            
            if let result = results.first {
                if detector.setFloorPlane(from: result) {
                    // Flash indicator to show floor captured
                    previewIndicator.flash()
                    ringIndicator.flash()
                    
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
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
            guard let arView = arView else { return }
            
            // Try to find any vertical wall at the tap point
            let results = arView.raycast(
                from: point,
                allowing: .existingPlaneGeometry,
                alignment: .vertical
            )
            
            if let result = results.first {
                // Capture wall and check if corner was created
                let previousCornerCount = detector.corners.count
                
                if detector.captureWall(from: result) {
                    // Flash indicator to show capture
                    ringIndicator.flash()
                    
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
                    // Check if a new corner was added (happens automatically after 2nd wall)
                    if detector.corners.count > previousCornerCount {
                        // Strong feedback for corner creation
                        let strongFeedback = UIImpactFeedbackGenerator(style: .heavy)
                        strongFeedback.impactOccurred()
                        
                        // Update visualization immediately
                        Task { @MainActor in
                            updateVisualization()
                        }
                    }
                }
            } else {
                // No wall found at tap point
                detector.statusMessage = "No wall detected - try again"
            }
        }
        
        // ================================================================================
        // MARK: - Visualization Updates
        // ================================================================================
        
        @MainActor
        func updateVisualization() {
            roomVisualization.update(
                corners: detector.corners,
                isComplete: detector.isComplete
            )
        }
        
    }
}