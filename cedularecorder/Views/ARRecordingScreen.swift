import SwiftUI
import RealityKit
import ReplayKit

struct ARRecordingScreen: View {
    @StateObject private var screenRecorder = ScreenRecorder()
    @StateObject private var measurementService = ARMeasurementService()
    @State private var showingPreview = false
    @State private var previewController: RPPreviewViewController?
    
    var body: some View {
        ZStack {
            // RealityKit AR View
            ARCameraComponent(
                measurementService: measurementService,
                isRecording: $screenRecorder.isRecording
            )
            .ignoresSafeArea()
            
            // UI Overlay
            VStack {
                // Top bar with recording status
                if screenRecorder.isRecording {
                    HStack {
                        Image(systemName: "record.circle.fill")
                            .foregroundColor(.red)
                            .font(.title2)
                        
                        Text("Recording: \(screenRecorder.formattedRecordingTime)")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.black.opacity(0.5))
                }
                
                Spacer()
                
                // Measurement info
                if let lastMeasurement = measurementService.measurements.last,
                   let distance = lastMeasurement.distance {
                    HStack {
                        Text(String(format: "Distance: %.2f m", distance))
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding()
                }
                
                // Bottom controls
                HStack(spacing: 30) {
                    // Clear measurements button
                    Button(action: {
                        measurementService.clearMeasurements()
                    }) {
                        Image(systemName: "trash")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.gray.opacity(0.7))
                            .clipShape(SwiftUI.Circle())
                    }
                    
                    // Record button
                    Button(action: toggleRecording) {
                        Image(systemName: screenRecorder.isRecording ? "stop.circle.fill" : "record.circle")
                            .font(.system(size: 40))
                            .foregroundColor(screenRecorder.isRecording ? .red : .white)
                            .frame(width: 80, height: 80)
                            .background(screenRecorder.isRecording ? Color.white : Color.red)
                            .clipShape(SwiftUI.Circle())
                    }
                    
                    // Measurement mode button
                    Button(action: {
                        measurementService.toggleMeasurementMode()
                    }) {
                        Image(systemName: measurementService.isReadyForNextPoint ? "ruler.fill" : "ruler")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(measurementService.isReadyForNextPoint ? Color.blue : Color.gray.opacity(0.7))
                            .clipShape(SwiftUI.Circle())
                    }
                }
                .padding(.bottom, 30)
            }
            
            // Error messages
            if let error = screenRecorder.errorMessage {
                VStack {
                    Text(error)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(8)
                }
                .padding()
                .transition(.move(edge: .top))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        screenRecorder.errorMessage = nil
                    }
                }
            }
        }
        .sheet(isPresented: $showingPreview) {
            if let previewController = previewController {
                PreviewControllerWrapper(previewController: previewController) {
                    showingPreview = false
                }
            }
        }
    }
    
    private func toggleRecording() {
        if screenRecorder.isRecording {
            screenRecorder.stopRecording { url in
                if let url = url {
                    // Save to photos or handle the video URL
                    screenRecorder.saveVideoToPhotos(url: url) { success in
                        if success {
                            print("Video saved to Photos")
                        }
                    }
                }
            }
        } else {
            screenRecorder.startRecording()
        }
    }
}

// Wrapper for RPPreviewViewController
struct PreviewControllerWrapper: UIViewControllerRepresentable {
    let previewController: RPPreviewViewController
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> RPPreviewViewController {
        previewController.previewControllerDelegate = context.coordinator
        return previewController
    }
    
    func updateUIViewController(_ uiViewController: RPPreviewViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }
    
    class Coordinator: NSObject, RPPreviewViewControllerDelegate {
        let onDismiss: () -> Void
        
        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }
        
        func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
            onDismiss()
        }
    }
}

struct ARRecordingView_Previews: PreviewProvider {
    static var previews: some View {
        ARRecordingScreen()
    }
}