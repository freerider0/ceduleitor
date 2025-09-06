import SwiftUI
import RealityKit
import ARKit

struct RealityKitARView: UIViewRepresentable {
    @ObservedObject var measurementService: ARMeasurementService
    @Binding var isRecording: Bool
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Configure AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        arView.session.run(configuration)
        
        // Add tap gesture for measurements
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        arView.addGestureRecognizer(tapGesture)
        
        context.coordinator.arView = arView
        context.coordinator.setupMeasurementVisualization()
        
        // Set ARSession delegate to access ARKit data
        arView.session.delegate = context.coordinator
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Update measurement visualizations
        context.coordinator.updateMeasurements(measurementService.measurements)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ARSessionDelegate {
        let parent: RealityKitARView
        weak var arView: ARView?
        var measurementAnchors: [AnchorEntity] = []
        
        init(_ parent: RealityKitARView) {
            self.parent = parent
            super.init()
        }
        
        func setupMeasurementVisualization() {
            // Setup will be done as measurements are added
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView = arView else { return }
            
            let location = gesture.location(in: arView)
            
            // Perform raycast
            let results = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .any)
            
            if let firstResult = results.first {
                let worldPosition = simd_float3(
                    firstResult.worldTransform.columns.3.x,
                    firstResult.worldTransform.columns.3.y,
                    firstResult.worldTransform.columns.3.z
                )
                
                // Add measurement point
                if parent.measurementService.isReadyForNextPoint {
                    parent.measurementService.addPoint(at: worldPosition)
                    addMeasurementMarker(at: worldPosition)
                }
            }
        }
        
        func addMeasurementMarker(at position: simd_float3) {
            guard let arView = arView else { return }
            
            // Create a sphere to mark the measurement point
            let mesh = MeshResource.generateSphere(radius: 0.01)
            let material = SimpleMaterial(color: .green, isMetallic: false)
            let modelEntity = ModelEntity(mesh: mesh, materials: [material])
            
            // Create anchor at the position
            let anchor = AnchorEntity(world: position)
            anchor.addChild(modelEntity)
            
            arView.scene.addAnchor(anchor)
            measurementAnchors.append(anchor)
        }
        
        func updateMeasurements(_ measurements: [SimpleMeasurement]) {
            // Clear old visualizations
            measurementAnchors.forEach { $0.removeFromParent() }
            measurementAnchors.removeAll()
            
            // Add new visualizations
            for measurement in measurements {
                if let start = measurement.startPoint {
                    addMeasurementMarker(at: start)
                }
                
                if let end = measurement.endPoint {
                    addMeasurementMarker(at: end)
                    
                    // Draw line between points
                    if let start = measurement.startPoint {
                        addMeasurementLine(from: start, to: end)
                    }
                }
            }
        }
        
        func addMeasurementLine(from start: simd_float3, to end: simd_float3) {
            guard let arView = arView else { return }
            
            // Calculate line properties
            let distance = simd_distance(start, end)
            let midpoint = (start + end) / 2
            
            // Create a thin cylinder as the line
            let mesh = MeshResource.generateCylinder(height: distance, radius: 0.002)
            let material = SimpleMaterial(color: .yellow, isMetallic: false)
            let lineEntity = ModelEntity(mesh: mesh, materials: [material])
            
            // Position and orient the line
            let anchor = AnchorEntity(world: midpoint)
            
            // Calculate rotation to align cylinder from start to end
            let direction = normalize(end - start)
            let up = simd_float3(0, 1, 0)
            
            if abs(dot(direction, up)) < 0.999 {
                let rotation = simd_quatf(from: up, to: direction)
                lineEntity.transform.rotation = rotation
            }
            
            anchor.addChild(lineEntity)
            arView.scene.addAnchor(anchor)
            measurementAnchors.append(anchor)
            
            // Add distance text
            addDistanceLabel(at: midpoint, distance: distance)
        }
        
        func addDistanceLabel(at position: simd_float3, distance: Float) {
            guard let arView = arView else { return }
            
            // Create text mesh
            let text = String(format: "%.2f m", distance)
            let textMesh = MeshResource.generateText(
                text,
                extrusionDepth: 0.001,
                font: .systemFont(ofSize: 0.05),
                containerFrame: .zero,
                alignment: .center,
                lineBreakMode: .byWordWrapping
            )
            
            let material = SimpleMaterial(color: .white, isMetallic: false)
            let textEntity = ModelEntity(mesh: textMesh, materials: [material])
            
            // Position text slightly above the measurement line
            let anchor = AnchorEntity(world: position + simd_float3(0, 0.05, 0))
            anchor.addChild(textEntity)
            
            // Make text face the camera
            textEntity.look(at: arView.cameraTransform.translation, from: position, relativeTo: nil)
            
            arView.scene.addAnchor(anchor)
            measurementAnchors.append(anchor)
        }
        
        // MARK: - ARSessionDelegate Methods (Access to ARKit data)
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            // Access current frame data
            // This is called 60 times per second with new AR data
            
            // Camera tracking state
            let trackingState = frame.camera.trackingState
            
            // Camera transform
            let cameraTransform = frame.camera.transform
            
            // Detected anchors (planes, images, objects, etc.)
            let anchors = frame.anchors
            
            // Raw feature points
            if let pointCloud = frame.rawFeaturePoints {
                let points = pointCloud.points // [simd_float3]
            }
            
            // Light estimation
            if let lightEstimate = frame.lightEstimate {
                let intensity = lightEstimate.ambientIntensity
                let temperature = lightEstimate.ambientColorTemperature
            }
            
            // Captured image (CVPixelBuffer)
            let pixelBuffer = frame.capturedImage
            
            // You can process or use this data as needed
        }
        
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            // Called when new anchors are detected (planes, images, etc.)
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor {
                    // Detected a plane
                    let extent = planeAnchor.extent // size
                    let center = planeAnchor.center // position
                    let alignment = planeAnchor.alignment // horizontal/vertical
                }
            }
        }
        
        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            // Called when existing anchors are updated
        }
        
        func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
            // Called when anchors are removed
        }
        
        func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
            // Called when tracking quality changes
            switch camera.trackingState {
            case .normal:
                print("Tracking normal")
            case .limited(let reason):
                print("Tracking limited: \(reason)")
            case .notAvailable:
                print("Tracking not available")
            }
        }
    }
}

// Helper extension for quaternion
extension simd_quatf {
    init(from: simd_float3, to: simd_float3) {
        let axis = simd_normalize(simd_cross(from, to))
        let angle = acos(simd_dot(simd_normalize(from), simd_normalize(to)))
        self = simd_quatf(angle: angle, axis: axis)
    }
}