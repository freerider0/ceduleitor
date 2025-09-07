import SwiftUI

struct CoordinateDisplayView: View {
    @ObservedObject var detector: RoomShapeDetector
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Coordinates")
                .font(.headline)
                .foregroundColor(.white)
            
            if detector.corners.isEmpty {
                Text("No corners captured")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                ForEach(Array(detector.corners.enumerated()), id: \.offset) { index, corner in
                    HStack {
                        Text("Corner \(index + 1):")
                            .font(.caption)
                            .foregroundColor(.white)
                        Text(String(format: "(%.2f, %.2f, %.2f)", corner.x, corner.y, corner.z))
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }
                
                if detector.corners.count >= 3 {
                    Divider()
                        .background(Color.white.opacity(0.3))
                    
                    HStack {
                        Text("Area:")
                            .font(.caption)
                            .foregroundColor(.white)
                        Text(String(format: "%.2f m²", detector.currentShape?.area ?? 0))
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Text("Perimeter:")
                            .font(.caption)
                            .foregroundColor(.white)
                        Text(String(format: "%.2f m", detector.currentShape?.perimeter ?? 0))
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.8))
        )
        .frame(maxWidth: 200)
    }
}

#Preview {
    CoordinateDisplayView(detector: RoomShapeDetector())
        .padding()
        .background(Color.gray)
}