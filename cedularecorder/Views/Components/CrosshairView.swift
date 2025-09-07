import SwiftUI

struct CrosshairView: View {
    var body: some View {
        ZStack {
            // Horizontal line
            Rectangle()
                .fill(Color.yellow)
                .frame(width: 40, height: 2)
            
            // Vertical line
            Rectangle()
                .fill(Color.yellow)
                .frame(width: 2, height: 40)
            
            // Center circle
            SwiftUI.Circle()
                .stroke(Color.yellow, lineWidth: 2)
                .frame(width: 20, height: 20)
        }
    }
}

#Preview {
    CrosshairView()
        .background(Color.black.opacity(0.5))
}