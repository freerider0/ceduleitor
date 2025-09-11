import SwiftUI
import PhotosUI
import AVFoundation

// MARK: - Main Camera View
@available(iOS 17.0, *)
struct ModernCameraWithOverlay: View {
    @StateObject private var cameraManager = ModernCameraManager()
    @State private var capturedImage: UIImage?
    @State private var showingPreview = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera Preview
                if cameraManager.isAuthorized && cameraManager.isSessionRunning {
                    ModernCameraPreviewView(session: cameraManager.session)
                        .ignoresSafeArea()
                } else {
                    // Permission or loading state
                    Rectangle()
                        .fill(.black)
                        .ignoresSafeArea()
                        .overlay(
                            VStack(spacing: 20) {
                                if !cameraManager.isAuthorized {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 60))
                                        .foregroundStyle(.white.opacity(0.6))
                                    
                                    Text("Camera Access Required")
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                    
                                    Button("Enable Camera") {
                                        cameraManager.requestPermission()
                                    }
                                    .buttonStyle(.borderedProminent)
                                } else {
                                    ProgressView()
                                        .controlSize(.large)
                                        .tint(.white)
                                    
                                    Text("Loading Camera...")
                                        .foregroundStyle(.white)
                                }
                            }
                        )
                }
                
                // Document Frame Overlay
                DocumentFrameOverlay(size: geometry.size)
                
                // UI Controls
                VStack {
                    // Top Controls
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                                .background(SwiftUI.Circle().fill(Color.black.opacity(0.5)))
                        }
                        .padding()
                        
                        Spacer()
                        
                        // Flash toggle
                        if cameraManager.isFlashAvailable {
                            Button {
                                cameraManager.toggleFlash()
                            } label: {
                                Image(systemName: cameraManager.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                                    .font(.title2)
                                    .foregroundStyle(cameraManager.isFlashOn ? .yellow : .white)
                                    .padding(8)
                                    .background(SwiftUI.Circle().fill(Color.black.opacity(0.5)))
                            }
                            .padding()
                        }
                    }
                    
                    Spacer()
                    
                    // Instructions and Capture Button
                    VStack(spacing: 20) {
                        Text("Position ID document within the frame")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(Color.black.opacity(0.7)))
                        
                        // Capture Button
                        Button {
                            Task {
                                await capturePhoto()
                            }
                        } label: {
                            ZStack {
                                SwiftUI.Circle()
                                    .fill(.white)
                                    .frame(width: 80, height: 80)
                                
                                SwiftUI.Circle()
                                    .stroke(.white, lineWidth: 4)
                                    .frame(width: 90, height: 90)
                                
                                if cameraManager.isCapturing {
                                    ProgressView()
                                        .tint(.black)
                                }
                            }
                        }
                        .disabled(cameraManager.isCapturing || !cameraManager.isSessionRunning)
                        .scaleEffect(cameraManager.isCapturing ? 0.9 : 1.0)
                        .animation(.easeInOut(duration: 0.1), value: cameraManager.isCapturing)
                    }
                    .padding(.bottom, 50)
                }
            }
        }
        .onAppear {
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .sheet(isPresented: $showingPreview) {
            if let image = capturedImage {
                PhotoPreviewView(
                    image: image,
                    onSave: {
                        print("🟢 Save button pressed in PhotoPreviewView")
                        savePhoto(image)
                        print("🟢 Dismissing camera view...")
                        dismiss()
                        print("🟢 Camera view dismissed")
                    },
                    onRetake: {
                        print("🔴 Retake button pressed")
                        showingPreview = false
                        capturedImage = nil
                    }
                )
            }
        }
        .alert("Camera Error", isPresented: $cameraManager.showError) {
            Button("OK") { }
        } message: {
            Text(cameraManager.errorMessage)
        }
    }
    
    @MainActor
    private func capturePhoto() async {
        print("🎯 Starting photo capture...")
        
        guard let image = await cameraManager.capturePhoto() else {
            print("❌ Failed to capture photo")
            return
        }
        
        print("✅ Photo captured successfully")
        print("📐 Captured image size: \(image.size.width) x \(image.size.height)")
        capturedImage = image
        print("🎯 Setting showingPreview to true...")
        showingPreview = true
        print("🎯 Preview sheet should be showing now")
    }
    
    private func savePhoto(_ image: UIImage) {
        print("🔵 savePhoto called - Starting save process...")
        print("📏 Image size: \(image.size.width) x \(image.size.height)")
        
        // Save ONLY to app's documents folder
        print("📁 Calling DocumentManager.shared.saveIDDocument...")
        if let savedPath = DocumentManager.shared.saveIDDocument(image) {
            print("✅ Document saved successfully to: \(savedPath)")
        } else {
            print("❌ Failed to save document")
        }
        print("🔵 savePhoto completed")
    }
}

// MARK: - Document Frame Overlay
struct DocumentFrameOverlay: View {
    let size: CGSize
    
    private var frameWidth: CGFloat { size.width * 0.85 }
    private var frameHeight: CGFloat { frameWidth * 0.63 } // ID card ratio
    
    var body: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height / 2
            
            ZStack {
                // Dark overlay with cutout - using the EXACT same dimensions
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .mask(
                        ZStack {
                            // Fill the entire screen
                            Rectangle()
                                .fill(Color.white)
                            
                            // Cut out the ID card area at the exact center
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black)
                                .frame(width: frameWidth, height: frameHeight)
                                .position(x: centerX, y: centerY)
                        }
                        .compositingGroup()
                        .luminanceToAlpha()
                    )
                    .ignoresSafeArea()
                
                // White border at the EXACT same position
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: frameWidth, height: frameHeight)
                    .position(x: centerX, y: centerY)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Corner Indicator
struct CornerIndicator: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 15))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 15, y: 0))
        }
        .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        .frame(width: 15, height: 15)
        .background(Color.clear)
    }
}

// MARK: - Modern Camera Manager
@MainActor
class ModernCameraManager: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var isSessionRunning = false
    @Published var isCapturing = false
    @Published var isFlashOn = false
    @Published var isFlashAvailable = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var currentDevice: AVCaptureDevice?
    private var currentPhotoProcessor: PhotoCaptureProcessor?
    
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    override init() {
        super.init()
        checkPermission()
    }
    
    func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            Task { @MainActor in
                self?.isAuthorized = granted
                if granted {
                    self?.setupCamera()
                }
            }
        }
    }
    
    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            setupCamera()
        case .notDetermined:
            requestPermission()
        case .denied, .restricted:
            isAuthorized = false
            showError(message: "Camera access is required to capture photos")
        @unknown default:
            isAuthorized = false
        }
    }
    
    private func setupCamera() {
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }
    
    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        // Add camera input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            session.commitConfiguration()
            Task { @MainActor in
                showError(message: "Unable to access camera")
            }
            return
        }
        
        currentDevice = camera
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        // Add photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            
            // Configure photo output
            photoOutput.isHighResolutionCaptureEnabled = true
            if let connection = photoOutput.connection(with: .video) {
                connection.videoOrientation = .portrait
            }
        }
        
        session.commitConfiguration()
        
        Task { @MainActor in
            isFlashAvailable = camera.hasFlash
        }
    }
    
    func startSession() {
        guard isAuthorized else { return }
        
        sessionQueue.async { [weak self] in
            guard let self = self, !self.session.isRunning else { return }
            self.session.startRunning()
            
            Task { @MainActor in
                self.isSessionRunning = self.session.isRunning
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.session.isRunning else { return }
            self.session.stopRunning()
            
            Task { @MainActor in
                self.isSessionRunning = false
            }
        }
    }
    
    func toggleFlash() {
        guard let device = currentDevice, device.hasFlash else { return }
        
        sessionQueue.async { [weak self] in
            do {
                try device.lockForConfiguration()
                device.torchMode = device.torchMode == .on ? .off : .on
                device.unlockForConfiguration()
                
                Task { @MainActor in
                    self?.isFlashOn = device.torchMode == .on
                }
            } catch {
                Task { @MainActor in
                    self?.showError(message: "Unable to toggle flash")
                }
            }
        }
    }
    
    func capturePhoto() async -> UIImage? {
        print("📸 capturePhoto() called")
        
        // Set capturing state
        isCapturing = true
        defer { isCapturing = false }
        
        return await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self = self else {
                    print("❌ Self is nil in capture queue")
                    continuation.resume(returning: nil)
                    return
                }
                
                print("📸 Preparing capture settings...")
                // Simple settings for faster capture
                let settings = AVCapturePhotoSettings()
                
                // Only set flash if it's on (faster)
                if self.isFlashOn, let device = self.currentDevice, device.hasFlash {
                    settings.flashMode = .on
                    print("📸 Flash enabled")
                }
                
                print("📸 Creating photo capture delegate...")
                // Create delegate and keep strong reference
                let delegate = PhotoCaptureProcessor { [weak self] image in
                    print("📸 Delegate returned image: \(image != nil)")
                    // Clear the reference after use
                    Task { @MainActor in
                        self?.currentPhotoProcessor = nil
                    }
                    continuation.resume(returning: image)
                }
                
                // Store strong reference to prevent deallocation
                Task { @MainActor in
                    self.currentPhotoProcessor = delegate
                }
                
                print("📸 Calling photoOutput.capturePhoto...")
                self.photoOutput.capturePhoto(with: settings, delegate: delegate)
                print("📸 capturePhoto called on photoOutput")
            }
        }
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - Photo Capture Processor
class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (UIImage?) -> Void
    private var hasCompleted = false
    
    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
        super.init()
        print("🎬 PhotoCaptureProcessor initialized")
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print("🎬 photoOutput:didFinishProcessingPhoto called")
        
        // Ensure we only call completion once
        guard !hasCompleted else {
            print("⚠️ Completion already called, ignoring")
            return
        }
        hasCompleted = true
        
        if let error = error {
            print("❌ Photo capture error: \(error)")
            completion(nil)
            return
        }
        
        print("🎬 Getting photo data representation...")
        guard let data = photo.fileDataRepresentation() else {
            print("❌ Failed to get photo data")
            completion(nil)
            return
        }
        
        print("🎬 Photo data size: \(data.count) bytes")
        let image = UIImage(data: data)
        print("🎬 Created UIImage: \(image != nil)")
        completion(image)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        print("🎬 willCapturePhotoFor called - photo is being captured")
    }
}

// MARK: - Camera Preview
struct ModernCameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.session = session
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        // Update if needed
    }
}

class CameraPreviewUIView: UIView {
    var session: AVCaptureSession? {
        didSet {
            guard let session = session else { return }
            previewLayer.session = session
        }
    }
    
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    private var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
        previewLayer.videoGravity = .resizeAspectFill
    }
}

// MARK: - Photo Preview
struct PhotoPreviewView: View {
    let image: UIImage
    let onSave: () -> Void
    let onRetake: () -> Void
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Retake") {
                        onRetake()
                    }
                    .foregroundStyle(.red)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                    }
                    .foregroundStyle(.green)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// Preview provider
struct ModernCameraWithOverlay_Previews: PreviewProvider {
    static var previews: some View {
        if #available(iOS 17.0, *) {
            ModernCameraWithOverlay()
        } else {
            Text("iOS 17+ required")
        }
    }
}