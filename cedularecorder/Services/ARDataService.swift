import Foundation
import ARKit
import RealityKit
import Combine

/// Service that exposes ARKit data to SwiftUI views
class ARDataService: NSObject, ObservableObject {
    // MARK: - Published properties for SwiftUI
    @Published var trackingState: ARCamera.TrackingState = .notAvailable
    @Published var trackingStateMessage: String = "Initializing..."
    @Published var detectedPlanes: Int = 0
    @Published var featurePointCount: Int = 0
    @Published var lightIntensity: Double = 1000.0
    @Published var lightTemperature: Double = 6500.0
    @Published var currentFrame: ARFrame?
    @Published var cameraTransform: simd_float4x4 = matrix_identity_float4x4
    @Published var fps: Int = 0
    
    // For depth data (LiDAR devices)
    @Published var hasDepthData: Bool = false
    @Published var depthConfidence: String = "N/A"
    
    private var frameCounter = 0
    private var lastFPSUpdate = Date()
    
    override init() {
        super.init()
    }
    
    func processFrame(_ frame: ARFrame) {
        // Update all published properties that SwiftUI can observe
        
        // Camera tracking
        trackingState = frame.camera.trackingState
        cameraTransform = frame.camera.transform
        updateTrackingMessage()
        
        // Detected planes
        let planeAnchors = frame.anchors.compactMap { $0 as? ARPlaneAnchor }
        detectedPlanes = planeAnchors.count
        
        // Feature points
        featurePointCount = frame.rawFeaturePoints?.points.count ?? 0
        
        // Light estimation
        if let lightEstimate = frame.lightEstimate {
            lightIntensity = Double(lightEstimate.ambientIntensity)
            lightTemperature = Double(lightEstimate.ambientColorTemperature)
        }
        
        // Depth data (for LiDAR devices)
        if let sceneDepth = frame.sceneDepth {
            hasDepthData = true
            switch sceneDepth.confidenceMap {
            case let map where map != nil:
                depthConfidence = "High"
            default:
                depthConfidence = "Low"
            }
        } else {
            hasDepthData = false
        }
        
        // FPS calculation
        frameCounter += 1
        let now = Date()
        if now.timeIntervalSince(lastFPSUpdate) >= 1.0 {
            fps = frameCounter
            frameCounter = 0
            lastFPSUpdate = now
        }
        
        // Store current frame for advanced usage
        currentFrame = frame
    }
    
    private func updateTrackingMessage() {
        switch trackingState {
        case .normal:
            trackingStateMessage = "Tracking Normal"
        case .limited(.excessiveMotion):
            trackingStateMessage = "Slow down device movement"
        case .limited(.insufficientFeatures):
            trackingStateMessage = "Point at more detailed surface"
        case .limited(.initializing):
            trackingStateMessage = "Initializing AR..."
        case .limited(.relocalizing):
            trackingStateMessage = "Relocalizing..."
        case .notAvailable:
            trackingStateMessage = "AR not available"
        @unknown default:
            trackingStateMessage = "Unknown state"
        }
    }
    
    // MARK: - Helper computed properties for SwiftUI
    
    var isTrackingNormal: Bool {
        trackingState == .normal
    }
    
    var cameraPosition: SIMD3<Float> {
        return SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
    }
    
    var cameraRotation: simd_quatf {
        return simd_quatf(cameraTransform)
    }
    
    var debugInfo: String {
        """
        FPS: \(fps)
        Planes: \(detectedPlanes)
        Points: \(featurePointCount)
        Light: \(Int(lightIntensity)) lm
        Temp: \(Int(lightTemperature)) K
        Depth: \(hasDepthData ? "Yes" : "No")
        """
    }
}

// MARK: - ARSessionDelegate
extension ARDataService: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        DispatchQueue.main.async { [weak self] in
            self?.processFrame(frame)
        }
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        // Can publish anchor additions to SwiftUI
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        // Can publish anchor updates to SwiftUI
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        DispatchQueue.main.async { [weak self] in
            self?.trackingState = camera.trackingState
            self?.updateTrackingMessage()
        }
    }
}