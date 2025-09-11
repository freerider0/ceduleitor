import SwiftUI
import AVFoundation

struct SimpleCameraTest: View {
    @StateObject private var camera = SimpleCameraModel()
    
    var body: some View {
        ZStack {
            if camera.isAuthorized {
                CameraView(session: camera.session)
                    .ignoresSafeArea()
            } else {
                Text("Camera access required")
                    .foregroundColor(.white)
                    .background(Color.black)
            }
        }
        .onAppear {
            camera.requestPermission()
        }
    }
}

struct CameraView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        // Start session
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}

class SimpleCameraModel: ObservableObject {
    @Published var isAuthorized = false
    let session = AVCaptureSession()
    
    func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if granted {
                    self?.setupCamera()
                }
            }
        }
    }
    
    private func setupCamera() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        
        session.addInput(input)
    }
}
