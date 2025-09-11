import SwiftUI
import AVFoundation
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

struct IDDocumentCaptureView: View {
    @StateObject private var cameraViewModel = IDCameraViewModel()
    @Environment(\.presentationMode) var presentationMode
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var capturedImage: UIImage?
    @State private var showingPreview = false
    @State private var documentType: CapturedDocument.DocumentType = .nationalID
    @State private var enableAutoCapture = true
    @State private var autoCaptureCountdown: Int? = nil
    
    var body: some View {
        ZStack {
            // Background color
            Color.black.ignoresSafeArea()
            
            // Camera preview
            CameraPreviewView(session: cameraViewModel.session)
                .ignoresSafeArea()
            
            // Document overlay frame
            DocumentOverlayView()
                .ignoresSafeArea()
                .allowsHitTesting(false)
            
            if cameraViewModel.isCameraSetup {
            VStack {
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                            .background(SwiftUI.Circle().fill(Color.black.opacity(0.5)))
                    }
                    .padding()
                    
                    Spacer()
                    
                    if cameraViewModel.isFlashAvailable {
                        Button(action: {
                            cameraViewModel.toggleFlash()
                        }) {
                            Image(systemName: cameraViewModel.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()
                                .background(SwiftUI.Circle().fill(Color.black.opacity(0.5)))
                        }
                        .padding()
                    }
                }
                
                Spacer()
                
                VStack(spacing: 10) {
                    HStack(spacing: 15) {
                        if let qualityScore = cameraViewModel.imageQualityScore {
                            QualityIndicatorView(score: qualityScore)
                        }
                        
                        if cameraViewModel.isDocumentDetected {
                            HStack {
                                Image(systemName: "doc.text.viewfinder")
                                    .foregroundColor(.green)
                                Text("Document Detected")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 15)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.7)))
                        }
                    }
                    
                    if let countdown = autoCaptureCountdown {
                        Text("Auto-capturing in \(countdown)...")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.8)))
                    } else {
                        Text("Position ID document within the frame")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.7)))
                    }
                    
                    HStack {
                        Menu {
                            ForEach(CapturedDocument.DocumentType.allCases, id: \.self) { type in
                                Button(type.rawValue) {
                                    documentType = type
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "doc.badge.ellipsis")
                                Text(documentType.rawValue)
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 15).fill(Color.blue.opacity(0.8)))
                        }
                        
                        Toggle("Auto", isOn: $enableAutoCapture)
                            .toggleStyle(SwitchToggleStyle(tint: .green))
                            .frame(width: 100)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 15).fill(Color.black.opacity(0.5)))
                            .foregroundColor(.white)
                    }
                    
                    Button(action: {
                        cameraViewModel.capturePhoto { image in
                            if let image = image {
                                self.capturedImage = image
                                self.showingPreview = true
                            }
                        }
                    }) {
                        ZStack {
                            SwiftUI.Circle()
                                .fill(Color.white)
                                .frame(width: 70, height: 70)
                            
                            SwiftUI.Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 80, height: 80)
                        }
                    }
                    .disabled(!cameraViewModel.isQualityAcceptable)
                    .opacity(cameraViewModel.isQualityAcceptable ? 1.0 : 0.5)
                }
                .padding(.bottom, 30)
            }
            }
        }
        .sheet(isPresented: $showingPreview) {
            if let image = capturedImage {
                IDDocumentPreviewView(
                    image: image,
                    documentType: documentType,
                    qualityScore: cameraViewModel.imageQualityScore ?? 0,
                    onRetake: {
                        showingPreview = false
                        capturedImage = nil
                        autoCaptureCountdown = nil
                    },
                    onConfirm: {
                        if let savedDocument = DocumentStorageService.shared.saveDocument(
                            image,
                            type: documentType,
                            qualityScore: cameraViewModel.imageQualityScore ?? 0,
                            hasPerspectiveCorrection: true
                        ) {
                            print("Document saved with ID: \(savedDocument.id)")
                        }
                        showingPreview = false
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
        .onChange(of: cameraViewModel.isDocumentDetected) { detected in
            if detected && enableAutoCapture && cameraViewModel.isQualityAcceptable && autoCaptureCountdown == nil {
                startAutoCapture()
            } else if !detected || !cameraViewModel.isQualityAcceptable {
                cancelAutoCapture()
            }
        }
        .onChange(of: cameraViewModel.isQualityAcceptable) { acceptable in
            if !acceptable && autoCaptureCountdown != nil {
                cancelAutoCapture()
            }
        }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Camera Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            // Only show alert if not authorized, don't re-setup
            if !cameraViewModel.isCameraAuthorized {
                cameraViewModel.checkCameraPermission { authorized in
                    if !authorized {
                        DispatchQueue.main.async {
                            alertMessage = "Camera access is required to capture ID documents. Please go to Settings and enable camera access for this app."
                            showingAlert = true
                        }
                    }
                }
            }
        }
        .onDisappear {
            // Stop the camera session when leaving the view
            cameraViewModel.stopSession()
        }
    }
    
    func startAutoCapture() {
        autoCaptureCountdown = 3
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if let countdown = autoCaptureCountdown, countdown > 1 {
                autoCaptureCountdown = countdown - 1
            } else {
                timer.invalidate()
                if cameraViewModel.isDocumentDetected && cameraViewModel.isQualityAcceptable {
                    cameraViewModel.capturePhoto { image in
                        if let image = image {
                            self.capturedImage = image
                            self.showingPreview = true
                        }
                    }
                }
                autoCaptureCountdown = nil
            }
        }
    }
    
    func cancelAutoCapture() {
        autoCaptureCountdown = nil
    }
}

struct DocumentOverlayView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Semi-transparent overlay with cutout for document
                Rectangle()
                    .fill(Color.black.opacity(0.7))
                    .mask(
                        ZStack {
                            Color.white
                            
                            RoundedRectangle(cornerRadius: 15)
                                .frame(width: geometry.size.width * 0.9, height: geometry.size.width * 0.56)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                    )
                
                // White border around document area
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: geometry.size.width * 0.9, height: geometry.size.width * 0.56)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                
                // Corner markers for better alignment
                ForEach(0..<4) { index in
                    CornerMarker()
                        .position(cornerPosition(for: index, in: geometry.size))
                }
            }
        }
    }
    
    func cornerPosition(for index: Int, in size: CGSize) -> CGPoint {
        let rectWidth = size.width * 0.9
        let rectHeight = size.width * 0.56
        let centerX = size.width / 2
        let centerY = size.height / 2
        
        switch index {
        case 0: return CGPoint(x: centerX - rectWidth/2, y: centerY - rectHeight/2)
        case 1: return CGPoint(x: centerX + rectWidth/2, y: centerY - rectHeight/2)
        case 2: return CGPoint(x: centerX + rectWidth/2, y: centerY + rectHeight/2)
        case 3: return CGPoint(x: centerX - rectWidth/2, y: centerY + rectHeight/2)
        default: return .zero
        }
    }
}

struct CornerMarker: View {
    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 20))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 20, y: 0))
            }
            .stroke(Color.white, lineWidth: 4)
        }
        .frame(width: 20, height: 20)
    }
}

struct QualityIndicatorView: View {
    let score: Double
    
    var color: Color {
        if score > 0.7 {
            return .green
        } else if score > 0.4 {
            return .yellow
        } else {
            return .red
        }
    }
    
    var statusText: String {
        if score > 0.7 {
            return "Good Quality"
        } else if score > 0.4 {
            return "Fair Quality"
        } else {
            return "Poor Quality - Adjust lighting or focus"
        }
    }
    
    var body: some View {
        HStack {
            SwiftUI.Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.7)))
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    class PreviewView: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer?
        
        func setupPreviewLayer(with session: AVCaptureSession) {
            // Remove old layer if exists
            previewLayer?.removeFromSuperlayer()
            
            // Create new preview layer
            let newLayer = AVCaptureVideoPreviewLayer(session: session)
            newLayer.frame = bounds
            newLayer.videoGravity = .resizeAspectFill
            
            // Configure connection
            if let connection = newLayer.connection {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                print("Preview connection established - Active: \(connection.isActive), Enabled: \(connection.isEnabled)")
            } else {
                print("No preview connection available yet")
            }
            
            layer.insertSublayer(newLayer, at: 0)
            previewLayer = newLayer
            
            print("Preview layer setup complete")
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = PreviewView()
        view.backgroundColor = .black
        
        // Setup preview layer after a delay to ensure session is configured
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            view.setupPreviewLayer(with: session)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let view = uiView as? PreviewView else { return }
        
        // Re-setup preview if needed
        if view.previewLayer == nil || view.previewLayer?.connection == nil {
            DispatchQueue.main.async {
                view.setupPreviewLayer(with: session)
            }
        }
    }
}

class IDCameraViewModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var session = AVCaptureSession()
    @Published var isFlashOn = false
    @Published var isFlashAvailable = false
    @Published var imageQualityScore: Double?
    @Published var isQualityAcceptable = false
    @Published var isDocumentDetected = false
    @Published var detectedRectangle: CIRectangleFeature?
    @Published var isCameraAuthorized = false
    @Published var isCameraSetup = false
    
    private var photoOutput = AVCapturePhotoOutput()
    private var videoOutput = AVCaptureVideoDataOutput()
    private var currentDevice: AVCaptureDevice?
    private var captureCompletion: ((UIImage?) -> Void)?
    private let visionQueue = DispatchQueue(label: "com.app.vision")
    private var isSettingUp = false // Add flag to prevent concurrent setup
    
    override init() {
        super.init()
        checkAndSetupCamera()
    }
    
    private func checkAndSetupCamera() {
        checkCameraPermission { [weak self] authorized in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isCameraAuthorized = authorized
                if authorized && !self.isCameraSetup {
                    self.setupCamera()
                }
            }
        }
    }
    
    func setupCamera() {
        // Skip if already setup or currently setting up
        if isCameraSetup || isSettingUp {
            print("Camera already setup or currently setting up")
            return
        }
        
        isSettingUp = true
        
        // Clear any existing configuration
        session.beginConfiguration()
        
        // Remove any existing inputs and outputs
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        
        session.sessionPreset = .photo
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Failed to get camera device")
            session.commitConfiguration()
            isSettingUp = false
            return
        }
        
        currentDevice = camera
        isFlashAvailable = camera.hasFlash
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            
            if session.canAddInput(input) {
                session.addInput(input)
                print("Camera input added successfully")
            } else {
                print("Cannot add camera input")
            }
            
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
                photoOutput.isHighResolutionCaptureEnabled = true
                print("Photo output added successfully")
            } else {
                print("Cannot add photo output")
            }
            
            videoOutput.setSampleBufferDelegate(self, queue: visionQueue)
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
                print("Video output added successfully")
            } else {
                print("Cannot add video output")
            }
            
        } catch {
            print("Camera setup error: \(error)")
            session.commitConfiguration()
            isSettingUp = false
            return
        }
        
        session.commitConfiguration()
        
        // Mark as setup before starting to prevent duplicate calls
        isCameraSetup = true
        isSettingUp = false
        
        // Start the session on background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
                print("Camera session started, running: \(self.session.isRunning)")
            }
        }
    }
    
    func checkCameraPermission(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        print("Camera authorization status: \(status.rawValue)")
        
        switch status {
        case .authorized:
            print("Camera access already authorized")
            completion(true)
        case .notDetermined:
            print("Camera access not determined, requesting...")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                print("Camera access request result: \(granted)")
                completion(granted)
            }
        case .denied:
            print("Camera access denied")
            completion(false)
        case .restricted:
            print("Camera access restricted")
            completion(false)
        @unknown default:
            print("Unknown camera authorization status")
            completion(false)
        }
    }
    
    func toggleFlash() {
        isFlashOn.toggle()
    }
    
    func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
                print("Camera session stopped")
            }
        }
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        captureCompletion = completion
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = isFlashOn ? .on : .off
        settings.isHighResolutionPhotoEnabled = true
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            captureCompletion?(nil)
            return
        }
        
        let correctedImage = correctPerspective(image: image)
        
        DispatchQueue.main.async {
            self.captureCompletion?(correctedImage)
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        analyzeImageQuality(pixelBuffer: pixelBuffer)
        detectDocument(pixelBuffer: pixelBuffer)
    }
    
    private func analyzeImageQuality(pixelBuffer: CVPixelBuffer) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        var quality = 1.0
        
        let laplacian = ciImage.applyingFilter("CILaplacian")
        if let outputImage = context.createCGImage(laplacian, from: laplacian.extent) {
            let blurScore = calculateBlurScore(from: outputImage)
            quality *= (1.0 - blurScore)
        }
        
        let statistics = ciImage.applyingFilter("CIAreaAverage", parameters: ["inputExtent": CIVector(cgRect: ciImage.extent)])
        if let outputImage = context.createCGImage(statistics, from: CGRect(x: 0, y: 0, width: 1, height: 1)),
           let data = outputImage.dataProvider?.data,
           let bytes = CFDataGetBytePtr(data) {
            let brightness = Double(bytes[0]) / 255.0
            
            if brightness < 0.3 || brightness > 0.85 {
                quality *= 0.7
            }
        }
        
        DispatchQueue.main.async {
            self.imageQualityScore = quality
            self.isQualityAcceptable = quality > 0.5
        }
    }
    
    private func calculateBlurScore(from image: CGImage) -> Double {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: &pixelData,
                                width: width,
                                height: height,
                                bitsPerComponent: bitsPerComponent,
                                bytesPerRow: bytesPerRow,
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        
        context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var variance: Double = 0
        let sampleSize = min(100, width * height)
        let step = max(1, (width * height) / sampleSize)
        
        for i in stride(from: 0, to: pixelData.count, by: step * bytesPerPixel) {
            let gray = Double(pixelData[i])
            variance += gray * gray
        }
        
        variance /= Double(sampleSize)
        
        return min(1.0, max(0.0, 1.0 - (variance / 10000.0)))
    }
    
    private func correctPerspective(image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        
        let ciImage = CIImage(cgImage: cgImage)
        let detector = CIDetector(ofType: CIDetectorTypeRectangle,
                                 context: nil,
                                 options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        
        guard let features = detector?.features(in: ciImage) as? [CIRectangleFeature],
              let rectangle = features.first else {
            return image
        }
        
        let perspectiveCorrection = CIFilter.perspectiveCorrection()
        perspectiveCorrection.inputImage = ciImage
        perspectiveCorrection.topLeft = rectangle.topLeft
        perspectiveCorrection.topRight = rectangle.topRight
        perspectiveCorrection.bottomLeft = rectangle.bottomLeft
        perspectiveCorrection.bottomRight = rectangle.bottomRight
        
        guard let outputImage = perspectiveCorrection.outputImage,
              let correctedCGImage = CIContext().createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }
        
        return UIImage(cgImage: correctedCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    private func detectDocument(pixelBuffer: CVPixelBuffer) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let detector = CIDetector(ofType: CIDetectorTypeRectangle,
                                 context: nil,
                                 options: [CIDetectorAccuracy: CIDetectorAccuracyHigh,
                                          CIDetectorAspectRatio: 1.6,
                                          CIDetectorMaxFeatureCount: 1])
        
        if let features = detector?.features(in: ciImage) as? [CIRectangleFeature],
           let rectangle = features.first {
            
            let imageSize = ciImage.extent.size
            let minArea = imageSize.width * imageSize.height * 0.15
            let rectangleArea = calculateArea(of: rectangle)
            
            DispatchQueue.main.async {
                self.detectedRectangle = rectangle
                self.isDocumentDetected = rectangleArea > minArea
            }
        } else {
            DispatchQueue.main.async {
                self.detectedRectangle = nil
                self.isDocumentDetected = false
            }
        }
    }
    
    private func calculateArea(of rectangle: CIRectangleFeature) -> CGFloat {
        let width = distance(from: rectangle.topLeft, to: rectangle.topRight)
        let height = distance(from: rectangle.topLeft, to: rectangle.bottomLeft)
        return width * height
    }
    
    private func distance(from point1: CGPoint, to point2: CGPoint) -> CGFloat {
        let dx = point2.x - point1.x
        let dy = point2.y - point1.y
        return sqrt(dx * dx + dy * dy)
    }
}

struct IDDocumentPreviewView: View {
    let image: UIImage
    let documentType: CapturedDocument.DocumentType
    let qualityScore: Double
    let onRetake: () -> Void
    let onConfirm: () -> Void
    
    var body: some View {
        VStack {
            Text("Review Captured Document")
                .font(.largeTitle)
                .padding()
            
            VStack(spacing: 10) {
                HStack {
                    Label(documentType.rawValue, systemImage: "doc.text")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack {
                        Image(systemName: "checkmark.shield")
                            .foregroundColor(qualityScore > 0.7 ? .green : qualityScore > 0.4 ? .yellow : .red)
                        Text("\(Int(qualityScore * 100))% Quality")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(10)
                    .shadow(radius: 5)
            }
            .padding()
            
            HStack(spacing: 30) {
                Button(action: onRetake) {
                    Label("Retake", systemImage: "arrow.counterclockwise")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 140)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.red))
                }
                
                Button(action: onConfirm) {
                    Label("Use Photo", systemImage: "checkmark")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 140)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.green))
                }
            }
            .padding()
        }
    }
}

struct IDDocumentCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        IDDocumentCaptureView()
    }
}