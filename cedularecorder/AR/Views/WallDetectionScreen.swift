import SwiftUI
import RealityKit
import ARKit
import Combine

struct WallDetectionScreen: View {
    @StateObject private var coordinator = WallDetectionCoordinator()
    @Environment(\.dismiss) private var dismiss
    @State private var trackedWallCount = 0
    @State private var detectedWallCount = 0
    @State private var wallModels: [WallModel] = []
    @State private var userPosition = SIMD3<Float>(0, 0, 0)
    @State private var userDirection: Float = 0
    @State private var roomPolygon: [SIMD3<Float>] = []  // Completed polygon
    @State private var updateCancellable: AnyCancellable?
    @State private var cameraUpdateTimer: AnyCancellable?
    
    func updateCameraPosition() {
        // Update camera position and rotation SMOOTHLY
        if let arView = coordinator.arView,
           let frame = arView.session.currentFrame {
            let transform = frame.camera.transform
            
            // Update user position
            userPosition = SIMD3<Float>(
                transform.columns.3.x,
                transform.columns.3.y,
                transform.columns.3.z
            )
            
            // Calculate user direction (yaw) - negative to fix rotation direction
            let forward = -transform.columns.2
            userDirection = -atan2(forward.x, forward.z)
        }
    }
    
    func updateMinimapWalls() {
        // Only rebuild wall models if dirty flag is set
        if WallInteractionSystem.minimapDirty {
            var newWallModels: [WallModel] = []
            
            // Use CACHED geometry data - no loops needed!
            for wallID in WallInteractionSystem.trackedWalls {
                if let geometry = WallInteractionSystem.wallGeometryCache[wallID],
                   let color = WallInteractionSystem.colorCache[wallID] {
                    newWallModels.append(WallModel(
                        startPoint: geometry.start,
                        endPoint: geometry.end,
                        color: Color(color)
                    ))
                }
            }
            
            wallModels = newWallModels
            WallInteractionSystem.minimapDirty = false  // Clear dirty flag
        }
        
        // Update room polygon
        roomPolygon = PlaneIntersectionSystem.roomPolygon
    }
    
    var body: some View {
        ZStack {
            // AR View
            WallDetectionARView(coordinator: coordinator)
                .edgesIgnoringSafeArea(.all)
                .onAppear {
                    // Wall updates - event-driven for performance
                    updateCancellable = coordinator.wallUpdatePublisher
                        .receive(on: DispatchQueue.main)
                        .sink { _ in
                            // Update counts from ECS systems
                            trackedWallCount = WallInteractionSystem.trackedWalls.count
                            detectedWallCount = WallClassificationSystem.detectedWallCount
                            
                            // Update wall models only
                            updateMinimapWalls()
                        }
                    
                    // Camera updates - smooth 30fps for responsive minimap
                    cameraUpdateTimer = Timer.publish(every: 1.0/30.0, on: .main, in: .common)
                        .autoconnect()
                        .sink { _ in
                            updateCameraPosition()
                        }
                }
                .onDisappear {
                    updateCancellable?.cancel()
                    cameraUpdateTimer?.cancel()
                }
            
            // Crosshair in center of screen
            WallCrosshairView()
            
            // UI Overlay
            VStack {
                // Top Status Bar
                TopStatusBar(coordinator: coordinator, trackedCount: trackedWallCount, dismiss: dismiss)
                
                Spacer()
                
                // Bottom Controls
                HStack(alignment: .bottom) {
                    // Mini Map showing tracked walls
                    if coordinator.isReady {
                        WallMiniMapView(
                            walls: wallModels,
                            userPosition: userPosition,
                            userDirection: userDirection,
                            roomPolygon: roomPolygon
                        )
                        .frame(width: 200, height: 200)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .overlay(
                            VStack {
                                HStack {
                                    Text("Walls: \(trackedWallCount)")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                Spacer()
                            }
                            .padding(8)
                        )
                        .padding()
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    Spacer()
                    
                    // Control Buttons
                    ControlButtons(trackedCount: trackedWallCount)
                        .padding()
                }
            }
        }
        .navigationBarHidden(true)
        .onDisappear {
            coordinator.stopSession()
        }
    }
}

// MARK: - AR View with Coaching Overlay
struct WallDetectionARView: UIViewRepresentable {
    let coordinator: WallDetectionCoordinator
    
    func makeUIView(context: Context) -> UIView {
        // IMPORTANT: Register systems BEFORE creating ARView
        // This ensures RealityKit creates system instances for all scenes
        WallDetectionARView.registerECSSystems()
        
        
        // Create container view
        let containerView = UIView()
        
        // Create AR view
        let arView = ARView(frame: .zero)
        arView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(arView)
        
        // Add constraints for AR view
        NSLayoutConstraint.activate([
            arView.topAnchor.constraint(equalTo: containerView.topAnchor),
            arView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            arView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            arView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Create and configure coaching overlay
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
        coachingOverlay.session = arView.session
        coachingOverlay.goal = .tracking
        coachingOverlay.activatesAutomatically = true
        containerView.addSubview(coachingOverlay)
        
        // Add constraints for coaching overlay
        NSLayoutConstraint.activate([
            coachingOverlay.topAnchor.constraint(equalTo: containerView.topAnchor),
            coachingOverlay.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            coachingOverlay.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            coachingOverlay.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Setup the coordinator with this AR view
        coordinator.setupARView(arView)
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No updates needed
    }
    
    // MARK: - System Registration
    @MainActor
    static func registerECSSystems() {
        // Register components first
        UserTrackedComponent.registerComponent()
        CircleIndicatorComponent.registerComponent()
        print("[AR] ✅ Components registered")
        
        // Register systems with RealityKit - must be done before ARView creation
        // This tells RealityKit to instantiate these systems for every scene
        WallClassificationSystem.registerSystem()
        WallInteractionSystem.registerSystem()
        WallCircleIndicatorSystem.registerSystem()
        PlaneIntersectionSystem.registerSystem()
        
        print("[AR] ✅ Systems registered with RealityKit - they will be instantiated for each scene")
    }
}

// MARK: - Top Status Bar
struct TopStatusBar: View {
    @ObservedObject var coordinator: WallDetectionCoordinator
    let trackedCount: Int
    let dismiss: DismissAction
    
    var statusColor: Color {
        switch coordinator.trackingState {
        case .normal:
            return .green
        case .limited(_):
            return .orange
        case .notAvailable:
            return .red
        }
    }
    
    var body: some View {
        HStack {
            // Back button
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.5))
                    .clipShape(SwiftUI.Circle())
            }
            
            Spacer()
            
            // Status info
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    // Tracking indicator
                    TrackingIndicator(isReady: coordinator.isReady)
                    
                    Text("Walls Tracked")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Text("\(trackedCount)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    
                Text(coordinator.isReady ? "Tap walls to track" : "Initializing...")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(statusColor, lineWidth: 2)
                    )
            )
        }
        .padding()
    }
}

// MARK: - Control Buttons
struct ControlButtons: View {
    let trackedCount: Int
    
    var body: some View {
        VStack(spacing: 16) {
            // Clear button
            Button(action: {
                // Clear using ECS system
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let arView = window.rootViewController?.view.subviews.compactMap({ $0 as? ARView }).first {
                    WallInteractionSystem.clearAllTrackedWalls(in: arView.scene)
                }
            }) {
                Image(systemName: "trash")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.red.opacity(0.8))
                    .clipShape(SwiftUI.Circle())
                    .shadow(radius: 4)
            }
            .disabled(trackedCount == 0)
            .opacity(trackedCount == 0 ? 0.3 : 1.0)
            
        }
    }
}

// MARK: - Minimap components moved to WallMiniMapView.swift
// MARK: - Tracking Indicator
struct TrackingIndicator: View {
    let isReady: Bool
    @State private var isAnimating = false
    
    var body: some View {
        SwiftUI.Circle()
            .fill(isReady ? Color.green : Color.orange)
            .frame(width: 8, height: 8)
            .scaleEffect(isAnimating && !isReady ? 1.2 : 1.0)
            .opacity(isAnimating && !isReady ? 0.5 : 1.0)
            .animation(
                !isReady ? Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default,
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Wall Crosshair View
struct WallCrosshairView: View {
    var body: some View {
        ZStack {
            // Horizontal line
            Rectangle()
                .fill(Color.white)
                .frame(width: 40, height: 2)
                .overlay(
                    Rectangle()
                        .stroke(Color.black, lineWidth: 0.5)
                )
            
            // Vertical line
            Rectangle()
                .fill(Color.white)
                .frame(width: 2, height: 40)
                .overlay(
                    Rectangle()
                        .stroke(Color.black, lineWidth: 0.5)
                )
            
            // Center dot
            SwiftUI.Circle()
                .fill(Color.red)
                .frame(width: 6, height: 6)
                .overlay(
                    SwiftUI.Circle()
                        .stroke(Color.white, lineWidth: 1)
                )
        }
        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 0)
    }
}

#Preview {
    WallDetectionScreen()
}
