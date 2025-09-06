import Foundation
import ReplayKit
import ARKit
import AVFoundation

/// Service for recording AR sessions with overlays using ReplayKit
class ARRecordingService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var errorMessage: String?
    
    private let recorder = RPScreenRecorder.shared()
    private var timer: Timer?
    private var startTime: Date?
    private var recordingURL: URL?
    private var completionHandler: ((URL?) -> Void)?
    
    override init() {
        super.init()
        setupRecorder()
    }
    
    private func setupRecorder() {
        recorder.isMicrophoneEnabled = true
        recorder.isCameraEnabled = true
    }
    
    /// Start recording the AR view
    func startRecording(completion: @escaping (Bool) -> Void) {
        // Check if ReplayKit is available (not available on simulator)
        #if targetEnvironment(simulator)
            // For simulator testing, just mark as recording
            self.isRecording = true
            self.startTime = Date()
            self.startTimer()
            completion(true)
            return
        #else
            guard recorder.isAvailable else {
                errorMessage = "Screen recording is not available on this device"
                completion(false)
                return
            }
            
            // Check if already recording
            guard !recorder.isRecording else {
                completion(true)
                return
            }
            
            // Start screen recording with microphone
            recorder.isMicrophoneEnabled = true
            
            recorder.startRecording { [weak self] error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.errorMessage = "Failed to start recording: \(error.localizedDescription)"
                        print("ReplayKit error: \(error)")
                        completion(false)
                    } else {
                        self?.isRecording = true
                        self?.startTime = Date()
                        self?.startTimer()
                        completion(true)
                    }
                }
            }
        #endif
    }
    
    /// Stop recording and save the video
    func stopRecording(completion: @escaping (URL?) -> Void) {
        #if targetEnvironment(simulator)
            // For simulator, create a dummy video file
            stopTimer()
            self.isRecording = false
            
            // Create a placeholder file for testing
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileName = "Recording_\(Date().timeIntervalSince1970).mp4"
            let documentsURL = documentsPath.appendingPathComponent(fileName)
            
            // Create empty file for simulator testing
            FileManager.default.createFile(atPath: documentsURL.path, contents: nil, attributes: nil)
            completion(documentsURL)
            return
        #else
            guard recorder.isRecording else {
                completion(nil)
                return
            }
            
            self.completionHandler = completion
            stopTimer()
            
            // Create file URL in Documents directory instead of temp
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileName = "Recording_\(Date().timeIntervalSince1970).mp4"
            let documentsURL = documentsPath.appendingPathComponent(fileName)
            self.recordingURL = documentsURL
            
            recorder.stopRecording(withOutput: documentsURL) { [weak self] error in
                DispatchQueue.main.async {
                    self?.isRecording = false
                    
                    if let error = error {
                        self?.errorMessage = "Failed to stop recording: \(error.localizedDescription)"
                        self?.completionHandler?(nil)
                    } else {
                        // Return the documents URL directly, no Photos Library
                        self?.completionHandler?(documentsURL)
                    }
                    
                    self?.completionHandler = nil
                }
            }
        #endif
    }
    
    /// Alternative method using AVAssetWriter for AR frame capture
    func startARRecording(session: ARSession, completion: @escaping (Bool) -> Void) {
        // This method can be used to directly capture AR frames
        // if ReplayKit doesn't work well
        
        isRecording = true
        startTime = Date()
        startTimer()
        
        // Setup AVAssetWriter to capture AR frames
        setupAssetWriter(for: session)
        
        completion(true)
    }
    
    private func setupAssetWriter(for session: ARSession) {
        // Create output URL
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = "AR_Direct_\(Date().timeIntervalSince1970).mp4"
        let outputURL = tempDirectory.appendingPathComponent(fileName)
        
        do {
            let assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
            
            // Configure video settings for 1080p
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 1920,
                AVVideoHeightKey: 1080,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 10_000_000,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                ]
            ]
            
            let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput.expectsMediaDataInRealTime = true
            
            if assetWriter.canAdd(videoInput) {
                assetWriter.add(videoInput)
            }
            
            // Store for later use
            self.recordingURL = outputURL
            
        } catch {
            errorMessage = "Failed to setup video writer: \(error.localizedDescription)"
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.startTime else { return }
            self.recordingTime = Date().timeIntervalSince(startTime)
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    
    var formattedRecordingTime: String {
        let minutes = Int(recordingTime) / 60
        let seconds = Int(recordingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}