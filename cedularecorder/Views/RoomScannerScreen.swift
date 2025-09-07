import SwiftUI

// ================================================================================
// MARK: - Room Scanner Screen
// ================================================================================

struct RoomScannerScreen: View {
    @StateObject private var detector = RoomShapeDetector()
    @State private var showCoordinates = false
    @State private var showOnboarding = true
    
    var body: some View {
        ZStack {
            // AR View with room visualization
            RoomARComponent(detector: detector)
                .ignoresSafeArea()
            
            // Crosshair in center
            GeometryReader { geometry in
                CrosshairView()
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            
            // Mini-map in bottom left
            VStack {
                Spacer()
                HStack {
                    if !detector.corners.isEmpty {
                        RoomMiniMapView(detector: detector)
                            .transition(.scale.combined(with: .opacity))
                    }
                    Spacer()
                }
                .padding(.bottom, 100) // Leave space for action buttons
            }
            .padding(.leading, 16)
            .animation(.easeInOut, value: detector.corners.count)
            
            // UI Overlay
            VStack {
                // Top controls
                VStack(spacing: 12) {
                    // Mode indicator and selector
                    ModeIndicatorView(detector: detector)
                        .padding(.top, 50)
                    
                    // Visual feedback indicators
                    HStack {
                        // Ring color legend
                        RingLegend()
                        
                        Spacer()
                        
                        // Detection quality and wall count
                        if detector.mode == .wallIntersection {
                            HStack(spacing: 8) {
                                // Corner count indicator
                                if detector.corners.count > 0 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "scope")
                                            .font(.caption)
                                        Text("\(detector.corners.count) corner\(detector.corners.count == 1 ? "" : "s")")
                                            .font(.caption2)
                                    }
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(8)
                                }
                                
                                // Wall count indicator
                                if detector.capturedWallsCount > 0 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "rectangle.split.3x1")
                                            .font(.caption)
                                        Text("Wall \(detector.capturedWallsCount)")
                                            .font(.caption2)
                                    }
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(8)
                                }
                                
                                DetectionQualityIndicator(state: detector.wallDetectionState)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Bottom action area
                VStack(spacing: 20) {
                    // Smart contextual actions
                    SmartActionButton(detector: detector)
                    
                    // Quick tips
                    if showOnboarding && detector.corners.isEmpty {
                        OnboardingTip(mode: detector.mode) {
                            withAnimation {
                                showOnboarding = false
                            }
                        }
                    }
                }
                .padding(.bottom, 30)
            }
            
            // Completion overlay
            if detector.isComplete {
                CompletionOverlay(detector: detector) {
                    showCoordinates = true
                }
            }
        }
        .sheet(isPresented: $showCoordinates) {
            CoordinateDisplayView(detector: detector)
        }
    }
}

// ================================================================================
// MARK: - Ring Legend
// ================================================================================

struct RingLegend: View {
    var body: some View {
        HStack(spacing: 12) {
            // Floor indicator
            HStack(spacing: 4) {
                SwiftUI.Circle()
                    .fill(Color.blue)
                    .frame(width: 12, height: 12)
                Text("Floor")
                    .font(.caption2)
                    .foregroundColor(.white)
            }
            
            // Wall indicator
            HStack(spacing: 4) {
                SwiftUI.Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                Text("Wall")
                    .font(.caption2)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.5))
        .cornerRadius(12)
    }
}

// ================================================================================
// MARK: - Detection Quality Indicator
// ================================================================================

struct DetectionQualityIndicator: View {
    let state: WallDetectionState
    
    var qualityLevel: (text: String, color: Color, icon: String) {
        switch state {
        case .searching:
            return ("Searching", .orange, "wifi.slash")
        case .wallDetected:
            return ("Good", .green, "wifi")
        case .firstWallStored:
            return ("1 Wall", .blue, "wifi")
        case .intersectionReady:
            return ("Ready", .green, "checkmark.circle")
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: qualityLevel.icon)
                .font(.caption)
            Text(qualityLevel.text)
                .font(.caption2)
        }
        .foregroundColor(qualityLevel.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(qualityLevel.color.opacity(0.2))
        .cornerRadius(8)
    }
}

// ================================================================================
// MARK: - Onboarding Tip
// ================================================================================

struct OnboardingTip: View {
    let mode: DetectionMode
    let dismiss: () -> Void
    
    var tipText: String {
        switch mode {
        case .cornerPointing:
            return "💡 Start by pointing at any corner where walls meet the floor"
        case .wallIntersection:
            return "💡 Capture 2+ walls: Each pair of walls creates a corner. Wall 3 finds corner between walls 2-3"
        }
    }
    
    var body: some View {
        HStack {
            Text(tipText)
                .font(.caption)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Button(action: dismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// ================================================================================
// MARK: - Completion Overlay
// ================================================================================

struct CompletionOverlay: View {
    @ObservedObject var detector: RoomShapeDetector
    let showCoordinates: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Success animation
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Room Captured!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // Stats
            VStack(spacing: 8) {
                HStack {
                    Label("Area", systemImage: "square")
                    Spacer()
                    Text(String(format: "%.1f m²", detector.currentShape?.area ?? 0))
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Label("Perimeter", systemImage: "ruler")
                    Spacer()
                    Text(String(format: "%.1f m", detector.currentShape?.perimeter ?? 0))
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Label("Corners", systemImage: "scope")
                    Spacer()
                    Text("\(detector.corners.count)")
                        .fontWeight(.semibold)
                }
            }
            .font(.body)
            .foregroundColor(.white)
            .padding()
            .background(Color.black.opacity(0.3))
            .cornerRadius(12)
            
            // Actions
            HStack(spacing: 16) {
                Button(action: showCoordinates) {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: { detector.reset() }) {
                    Label("New Room", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.9))
        )
        .padding()
    }
}