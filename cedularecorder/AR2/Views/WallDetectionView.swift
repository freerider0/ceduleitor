import SwiftUI

struct AR2WallDetectionView: View {
    @StateObject private var coordinator = AR2WallCoordinator()
    @State private var showMiniMap = true
    @State private var showControls = true

    var body: some View {
        ZStack {
            AR2ViewContainer(coordinator: coordinator)
                .ignoresSafeArea()

            // Crosshair in center for aiming
            ZStack {
                Rectangle()
                    .fill(.white)
                    .frame(width: 30, height: 2)
                Rectangle()
                    .fill(.white)
                    .frame(width: 2, height: 30)
            }
            .opacity(0.6)
            .background(
                SwiftUI.Circle()
                    .fill(.black.opacity(0.2))
                    .frame(width: 40, height: 40)
            )

            VStack {
                if showControls {
                    HStack {
                        AR2TrackingStatusPill(quality: coordinator.getTrackingQuality())

                        Spacer()

                        Label("Walls: \(coordinator.trackedWallCount)", systemImage: "square.split.2x2")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.thinMaterial)
                            .cornerRadius(8)
                    }
                    .padding()
                }

                Spacer()

                if showMiniMap {
                    HStack {
                        Spacer()
                        AR2MiniMapView(coordinator: coordinator)
                            .frame(width: 200, height: 200)
                            .padding()
                    }
                }

                if showControls {
                    HStack(spacing: 20) {
                        Button(action: { showMiniMap.toggle() }) {
                            Image(systemName: showMiniMap ? "map.fill" : "map")
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(.thinMaterial)
                                .clipShape(SwiftUI.Circle())
                        }

                        Button(action: { coordinator.startNewRoom() }) {
                            Label("New Room", systemImage: "plus.square")
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(.blue)
                                .foregroundColor(.white)
                                .cornerRadius(20)
                        }

                        Button(action: { coordinator.reset() }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(.thinMaterial)
                                .clipShape(SwiftUI.Circle())
                        }
                    }
                    .padding()
                }
            }
        }
        .statusBarHidden()
    }
}

struct AR2TrackingStatusPill: View {
    let quality: String

    var body: some View {
        HStack(spacing: 6) {
            SwiftUI.Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(quality)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.thinMaterial)
        .cornerRadius(12)
    }

    private var statusColor: Color {
        switch quality {
        case "Good": return .green
        case "Limited": return .yellow
        default: return .red
        }
    }
}