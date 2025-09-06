import SwiftUI
import RealityKit
import ARKit

/// Example SwiftUI view showing how AR data is now easily accessible
struct ARDebugView: View {
    @StateObject private var arData = ARDataService()
    @State private var showDebugInfo = true
    
    var body: some View {
        ZStack {
            // RealityKit AR View
            ARViewContainer(arDataService: arData)
                .ignoresSafeArea()
            
            // SwiftUI overlay with live AR data
            VStack {
                // Tracking state banner
                if arData.trackingState != .normal {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                        Text(arData.trackingStateMessage)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.9))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.top)
                }
                
                Spacer()
                
                // Debug info panel
                if showDebugInfo {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AR Debug Info")
                            .font(.headline)
                        
                        Divider()
                        
                        // All these values update automatically!
                        HStack {
                            Label("\(arData.fps) FPS", systemImage: "speedometer")
                            Spacer()
                            Label("\(arData.detectedPlanes) planes", systemImage: "square.3.layers.3d")
                        }
                        
                        HStack {
                            Label("\(arData.featurePointCount) points", systemImage: "point.3.connected.trianglepath.dotted")
                            Spacer()
                            Label("\(Int(arData.lightIntensity)) lm", systemImage: "light.max")
                        }
                        
                        HStack {
                            Label("\(Int(arData.lightTemperature))K", systemImage: "thermometer")
                            Spacer()
                            Label("Depth: \(arData.hasDepthData ? "✓" : "✗")", systemImage: "camera.metering.spot")
                        }
                        
                        // Camera position
                        Text("Camera: (\(String(format: "%.2f", arData.cameraPosition.x)), \(String(format: "%.2f", arData.cameraPosition.y)), \(String(format: "%.2f", arData.cameraPosition.z)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding()
                }
                
                // Toggle debug info
                HStack {
                    Spacer()
                    Button(action: { showDebugInfo.toggle() }) {
                        Image(systemName: showDebugInfo ? "info.circle.fill" : "info.circle")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue.opacity(0.7))
                            .clipShape(Circle())
                    }
                    .padding()
                }
            }
        }
    }
}

// Simple ARView wrapper that connects to our data service
struct ARViewContainer: UIViewRepresentable {
    let arDataService: ARDataService
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Configure session
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics = .sceneDepth
        }
        
        // Connect our data service to receive AR updates
        arView.session.delegate = arDataService
        arView.session.run(config)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Updates handled by delegate
    }
}

struct ARDebugView_Previews: PreviewProvider {
    static var previews: some View {
        ARDebugView()
    }
}