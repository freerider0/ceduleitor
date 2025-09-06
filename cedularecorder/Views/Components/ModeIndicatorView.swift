import SwiftUI

// ================================================================================
// MARK: - Mode Indicator View
// ================================================================================

/// Visual indicator showing current mode and how to use it
struct ModeIndicatorView: View {
    @ObservedObject var detector: RoomShapeDetector
    @State private var showHelp = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Mode selector with icons
            HStack(spacing: 0) {
                // Corner Mode
                ModeButton(
                    title: "Corners",
                    icon: "scope",
                    description: "Point at corners directly",
                    isSelected: detector.mode == .cornerPointing,
                    color: .blue
                ) {
                    detector.switchMode(.cornerPointing)
                }
                
                // Wall Mode
                ModeButton(
                    title: "Walls",
                    icon: "rectangle.split.2x1",
                    description: "Find corners from walls",
                    isSelected: detector.mode == .wallIntersection,
                    color: .purple
                ) {
                    detector.switchMode(.wallIntersection)
                }
            }
            .background(Color.black.opacity(0.3))
            .cornerRadius(12)
            
            // Current mode instructions
            InstructionBanner(mode: detector.mode, state: detector.wallDetectionState)
            
            // Progress indicator
            if !detector.corners.isEmpty {
                ProgressIndicator(
                    pointCount: detector.corners.count,
                    canClose: detector.canClose,
                    isComplete: detector.isComplete
                )
            }
        }
        .padding(.horizontal)
    }
}

// ================================================================================
// MARK: - Mode Button
// ================================================================================

struct ModeButton: View {
    let title: String
    let icon: String
    let description: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : color.opacity(0.6))
                
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .white : .gray)
                
                if isSelected {
                    Text(description)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                isSelected ? color.opacity(0.8) : Color.clear
            )
        }
    }
}

// ================================================================================
// MARK: - Instruction Banner
// ================================================================================

struct InstructionBanner: View {
    let mode: DetectionMode
    let state: WallDetectionState
    
    var instructionText: String {
        switch mode {
        case .cornerPointing:
            return "🎯 Aim the crosshair at room corners on the floor"
        case .wallIntersection:
            switch state {
            case .searching:
                return "🔍 Look at a wall to detect it"
            case .wallDetected:
                return "✅ Wall detected - tap to capture"
            case .firstWallStored:
                return "1️⃣ First wall stored - find perpendicular wall"
            case .intersectionReady:
                return "🔀 Two walls ready - tap to add corner"
            }
        }
    }
    
    var bannerColor: Color {
        switch mode {
        case .cornerPointing:
            return .blue
        case .wallIntersection:
            switch state {
            case .searching:
                return .orange
            case .wallDetected:
                return .green
            case .firstWallStored:
                return .purple
            case .intersectionReady:
                return .green
            }
        }
    }
    
    var body: some View {
        HStack {
            Text(instructionText)
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .background(bannerColor.opacity(0.8))
        .cornerRadius(20)
    }
}

// ================================================================================
// MARK: - Progress Indicator
// ================================================================================

struct ProgressIndicator: View {
    let pointCount: Int
    let canClose: Bool
    let isComplete: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Point counter
            HStack(spacing: 4) {
                ForEach(0..<max(3, pointCount), id: \.self) { index in
                    Circle()
                        .fill(index < pointCount ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            
            // Status text
            if isComplete {
                Label("Complete", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            } else if canClose {
                Label("Ready to close", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else if pointCount > 0 {
                Text("Add \(3 - pointCount) more")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.5))
        .cornerRadius(15)
    }
}