import SwiftUI

// ================================================================================
// MARK: - Smart Action Button
// ================================================================================

/// Context-aware action button that changes based on current state
struct SmartActionButton: View {
    @ObservedObject var detector: RoomShapeDetector
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Secondary actions
            HStack(spacing: 20) {
                // Undo button
                if detector.corners.count > 0 && !detector.isComplete {
                    ActionButton(
                        icon: "arrow.uturn.backward",
                        title: "Undo",
                        color: .gray,
                        size: .small
                    ) {
                        detector.undoLastPoint()
                    }
                }
                
                // Mode-specific helper
                if detector.mode == .wallIntersection && detector.wallDetectionState == .firstWallStored {
                    ActionButton(
                        icon: "arrow.clockwise",
                        title: "Reset Walls",
                        color: .orange,
                        size: .small
                    ) {
                        // Reset wall capture
                        detector.reset()
                    }
                }
                
                // Close shape button
                if detector.canClose && !detector.isComplete {
                    ActionButton(
                        icon: "checkmark.circle",
                        title: "Close Shape",
                        color: .green,
                        size: .medium
                    ) {
                        detector.closeShape()
                    }
                }
            }
            
            // Primary action button
            PrimaryActionButton(detector: detector)
        }
    }
}

// ================================================================================
// MARK: - Primary Action Button
// ================================================================================

struct PrimaryActionButton: View {
    @ObservedObject var detector: RoomShapeDetector
    @State private var isPressed = false
    
    var buttonConfig: (icon: String, title: String, subtitle: String?, color: Color) {
        if detector.isComplete {
            return ("square.and.arrow.up", "Export Room", "View measurements", .blue)
        }
        
        switch detector.mode {
        case .cornerPointing:
            return ("plus.viewfinder", "Add Corner", "Point at floor corner", .blue)
            
        case .wallIntersection:
            switch detector.wallDetectionState {
            case .searching:
                if detector.corners.isEmpty {
                    return ("viewfinder", "Find First Wall", "Look at any wall", .orange)
                } else {
                    return ("viewfinder", "Find Next Wall", "Look for perpendicular wall", .orange)
                }
            case .wallDetected:
                return ("checkmark.circle", "Capture Wall", "Tap to record wall", .green)
            case .firstWallStored:
                return ("rotate.right", "Turn 90°", "Find perpendicular wall", .purple)
            case .intersectionReady:
                return ("plus.circle", "Create Corner", "Tap to add corner", .green)
            }
        }
    }
    
    var body: some View {
        Button(action: handleTap) {
            VStack(spacing: 4) {
                Image(systemName: buttonConfig.icon)
                    .font(.title)
                    .foregroundColor(.white)
                
                Text(buttonConfig.title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                if let subtitle = buttonConfig.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .frame(width: 180, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(buttonConfig.color)
                    .shadow(color: buttonConfig.color.opacity(0.5), radius: 10, x: 0, y: 5)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity,
                           pressing: { pressing in
                               withAnimation(.easeInOut(duration: 0.1)) {
                                   isPressed = pressing
                               }
                           },
                           perform: {})
    }
    
    private func handleTap() {
        // Action is handled by AR view tap gesture
        // This just provides visual feedback
        withAnimation(.easeInOut(duration: 0.1)) {
            isPressed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isPressed = false
        }
    }
}

// ================================================================================
// MARK: - Action Button Component
// ================================================================================

struct ActionButton: View {
    enum Size {
        case small, medium, large
        
        var dimension: CGFloat {
            switch self {
            case .small: return 44
            case .medium: return 56
            case .large: return 68
            }
        }
        
        var iconSize: Font {
            switch self {
            case .small: return .body
            case .medium: return .title3
            case .large: return .title2
            }
        }
    }
    
    let icon: String
    let title: String?
    let color: Color
    let size: Size
    let action: () -> Void
    
    init(icon: String, title: String? = nil, color: Color, size: Size = .medium, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.color = color
        self.size = size
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(size.iconSize)
                    .foregroundColor(.white)
                
                if let title = title, size != .small {
                    Text(title)
                        .font(.caption2)
                        .foregroundColor(.white)
                }
            }
            .frame(width: size.dimension, height: size.dimension)
            .background(
                SwiftUI.Circle()
                    .fill(color.opacity(0.8))
            )
        }
    }
}