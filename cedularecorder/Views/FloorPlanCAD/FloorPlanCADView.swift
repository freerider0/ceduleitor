import SwiftUI
import UIKit
import simd

// MARK: - SwiftUI Wrapper
struct FloorPlanCADView: View {
    @StateObject private var viewModel = FloorPlanCADViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            // UIKit CAD View - Clean, no clutter
            FloorPlanCADRepresentable(viewModel: viewModel)
                .ignoresSafeArea()
            
            // Minimal overlay with just back button and info
            VStack {
                HStack {
                    // Back button
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(SwiftUI.Circle().fill(Color.black.opacity(0.5)))
                    }
                    .padding()
                    
                    Spacer()
                }
                
                Spacer()
                
                // Simple info display at bottom
                HStack {
                    VStack(alignment: .leading) {
                        Text("Area: \(String(format: "%.1f m²", viewModel.area))")
                            .font(.caption)
                            .foregroundColor(.white)
                        Text("Perimeter: \(String(format: "%.1f m", viewModel.perimeter))")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.6))
                    )
                    
                    Spacer()
                }
                .padding()
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.loadSampleData()
        }
    }
}

// MARK: - UIViewControllerRepresentable
struct FloorPlanCADRepresentable: UIViewControllerRepresentable {
    @ObservedObject var viewModel: FloorPlanCADViewModel
    
    func makeUIViewController(context: Context) -> FloorPlanViewController {
        let controller = FloorPlanViewController()
        viewModel.viewController = controller
        return controller
    }
    
    func updateUIViewController(_ uiViewController: FloorPlanViewController, context: Context) {
        // Updates handled by view controller's own bindings
    }
}

// MARK: - View Model
class FloorPlanCADViewModel: ObservableObject {
    @Published var corners: [simd_float3] = []
    @Published var area: Double = 0
    @Published var perimeter: Double = 0
    @Published var needsUpdate: Bool = false
    
    weak var viewController: FloorPlanViewController?
    
    func loadSampleData() {
        // Load sample room corners (rectangle)
        corners = [
            simd_float3(0, 0, 0),
            simd_float3(5, 0, 0),
            simd_float3(5, 0, 4),
            simd_float3(0, 0, 4)
        ]
        
        calculateMetrics()
        needsUpdate = true
    }
    
    func loadRoomData(_ data: [simd_float3]) {
        corners = data
        calculateMetrics()
        needsUpdate = true
    }
    
    private func calculateMetrics() {
        guard corners.count >= 3 else {
            area = 0
            perimeter = 0
            return
        }
        
        // Calculate area using shoelace formula
        var calculatedArea: Float = 0
        for i in 0..<corners.count {
            let j = (i + 1) % corners.count
            calculatedArea += corners[i].x * corners[j].z
            calculatedArea -= corners[j].x * corners[i].z
        }
        area = Double(abs(calculatedArea) / 2.0)
        
        // Calculate perimeter
        var calculatedPerimeter: Float = 0
        for i in 0..<corners.count {
            let j = (i + 1) % corners.count
            let distance = simd_distance(corners[i], corners[j])
            calculatedPerimeter += distance
        }
        perimeter = Double(calculatedPerimeter)
    }
}

// MARK: - Preview
struct FloorPlanCADView_Previews: PreviewProvider {
    static var previews: some View {
        FloorPlanCADView()
    }
}