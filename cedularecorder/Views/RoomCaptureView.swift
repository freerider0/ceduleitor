import SwiftUI
import RealityKit
import ARKit

struct RoomCaptureView: View {
    @StateObject private var detector = RoomShapeDetector()
    @State private var showCoordinates = false
    
    var body: some View {
        ZStack {
            // AR View with room visualization (using refactored version)
            RoomARViewRefactored(detector: detector)
                .ignoresSafeArea()
            
            // Crosshair in center - use GeometryReader to ensure true center
            GeometryReader { geometry in
                CrosshairView()
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            
            // UI Overlay
            VStack {
                // Top status bar
                VStack(spacing: 8) {
                    // Mode selector
                    Picker("Mode", selection: $detector.mode) {
                        Text("Corners").tag(DetectionMode.cornerPointing)
                        Text("Walls").tag(DetectionMode.wallIntersection)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .onChange(of: detector.mode) { newMode in
                        detector.switchMode(newMode)
                    }
                    
                    // Status message with wall detection indicator
                    HStack(spacing: 12) {
                        // Wall detection indicator for wall mode
                        if detector.mode == .wallIntersection {
                            WallDetectionIndicator(state: detector.wallDetectionState)
                        }
                        
                        Text(detector.statusMessage)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                    
                    // Point counter
                    if !detector.corners.isEmpty {
                        Text("Points: \(detector.corners.count)")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.blue.opacity(0.7))
                            .cornerRadius(8)
                    }
                }
                .padding(.top, 50)
                
                Spacer()
                
                // Bottom controls
                VStack(spacing: 16) {
                    // Action buttons row
                    HStack(spacing: 20) {
                        // Undo button
                        if !detector.corners.isEmpty && !detector.isComplete {
                            Button(action: {
                                detector.undoLastPoint()
                            }) {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .background(Color.gray.opacity(0.7))
                                    .clipShape(Circle())
                            }
                        }
                        
                        // Close shape button
                        if detector.canClose && !detector.isComplete {
                            Button(action: {
                                detector.closeShape()
                            }) {
                                Text("Close")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(width: 80, height: 50)
                                    .background(Color.green.opacity(0.8))
                                    .cornerRadius(25)
                            }
                        }
                        
                        // Reset button
                        if detector.isComplete {
                            Button(action: {
                                detector.reset()
                            }) {
                                Text("New Room")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(width: 100, height: 50)
                                    .background(Color.orange.opacity(0.8))
                                    .cornerRadius(25)
                            }
                        }
                    }
                    
                    // Main action button
                    if !detector.isComplete {
                        AddPointButton(detector: detector)
                    } else {
                        // Show coordinates button
                        Button(action: {
                            showCoordinates = true
                        }) {
                            Text("View Coordinates")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 200, height: 60)
                                .background(Color.blue)
                                .cornerRadius(30)
                        }
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $showCoordinates) {
            CoordinateDisplayView(detector: detector)
        }
    }
}

// MARK: - Crosshair View

struct CrosshairView: View {
    var body: some View {
        ZStack {
            // Horizontal line with shadow for visibility
            Rectangle()
                .fill(Color.white)
                .frame(width: 40, height: 2)
                .shadow(color: .black, radius: 1, x: 0, y: 0)
            
            // Vertical line with shadow for visibility
            Rectangle()
                .fill(Color.white)
                .frame(width: 2, height: 40)
                .shadow(color: .black, radius: 1, x: 0, y: 0)
            
            // Center dot
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
            
            // Outer circle for targeting
            Circle()
                .stroke(Color.white.opacity(0.7), lineWidth: 2)
                .frame(width: 60, height: 60)
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.3), lineWidth: 1)
                        .frame(width: 62, height: 62)
                )
        }
    }
}

// MARK: - Add Point Button

struct AddPointButton: View {
    @ObservedObject var detector: RoomShapeDetector
    @State private var isPressed = false
    
    var buttonText: String {
        switch detector.mode {
        case .cornerPointing:
            return "Add Corner"
        case .wallIntersection:
            if detector.wallDetectionState == .firstWallStored {
                return "Add Second Wall"
            } else if detector.wallDetectionState == .intersectionReady {
                return "Calculate Corner"
            } else {
                return "Capture Wall"
            }
        }
    }
    
    var body: some View {
        Button(action: {
            // Action handled by AR view tap
        }) {
            Text(buttonText)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 180, height: 60)
                .background(backgroundGradient)
                .cornerRadius(30)
                .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity,
                           pressing: { pressing in
                               withAnimation(.easeInOut(duration: 0.1)) {
                                   isPressed = pressing
                               }
                           },
                           perform: {})
        .disabled(false)
    }
    
    var backgroundGradient: LinearGradient {
        // Different colors based on mode
        if detector.mode == .wallIntersection {
            // Purple gradient for wall mode
            return LinearGradient(
                colors: [Color.purple, Color.purple.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            // Blue gradient for corner mode
            return LinearGradient(
                colors: [Color.blue, Color.blue.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - Coordinate Display View

struct CoordinateDisplayView: View {
    @ObservedObject var detector: RoomShapeDetector
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(detector.getCoordinateDisplay())
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        .padding()
                    
                    // Export buttons
                    HStack {
                        Button(action: copyToClipboard) {
                            Label("Copy", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button(action: shareCoordinates) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Room Coordinates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    func copyToClipboard() {
        UIPasteboard.general.string = detector.getCoordinateDisplay()
    }
    
    func shareCoordinates() {
        let text = detector.getCoordinateDisplay()
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(av, animated: true)
        }
    }
}

// ================================================================================
// MARK: - Wall Detection Indicator View
// ================================================================================

/// Visual indicator for wall detection state
struct WallDetectionIndicator: View {
    let state: WallDetectionState
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            switch state {
            case .searching:
                // Searching animation - rotating dashed circle
                Circle()
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                    .foregroundColor(.yellow)
                    .frame(width: 24, height: 24)
                    .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                    .animation(
                        .linear(duration: 2)
                        .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
                    .onAppear {
                        isAnimating = true
                    }
                
            case .wallDetected:
                // Wall detected - solid wall icon
                Image(systemName: "rectangle.portrait.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
                
            case .firstWallStored:
                // One wall stored, need second - "1→?" indicator
                HStack(spacing: 2) {
                    Text("1")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.blue)
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                    
                    Text("?")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.gray)
                }
                
            case .intersectionReady:
                // Two walls ready - intersection icon
                ZStack {
                    // Two intersecting lines
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: 20, height: 2)
                        .rotationEffect(Angle(degrees: 45))
                    
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: 20, height: 2)
                        .rotationEffect(Angle(degrees: -45))
                    
                    // Center dot
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                }
                .frame(width: 24, height: 24)
            }
        }
        .frame(width: 30, height: 30)
    }
}

// MARK: - Preview

struct RoomCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        RoomCaptureView()
    }
}