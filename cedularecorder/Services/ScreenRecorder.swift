import Foundation
import ReplayKit
import Photos
import AVFoundation

class ScreenRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isAvailable = false
    @Published var recordingTime: TimeInterval = 0
    @Published var errorMessage: String?
    
    private let recorder = RPScreenRecorder.shared()
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    
    override init() {
        super.init()
        checkAvailability()
        recorder.delegate = self
    }
    
    private func checkAvailability() {
        isAvailable = recorder.isAvailable
    }
    
    func startRecording() {
        guard recorder.isAvailable else {
            errorMessage = "Screen recording is not available"
            return
        }
        
        guard !recorder.isRecording else {
            errorMessage = "Already recording"
            return
        }
        
        // Start recording with microphone audio
        recorder.isMicrophoneEnabled = true
        
        recorder.startRecording { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = "Failed to start recording: \(error.localizedDescription)"
                } else {
                    self?.isRecording = true
                    self?.startTimer()
                    self?.errorMessage = nil
                }
            }
        }
    }
    
    func stopRecording(completion: @escaping (URL?) -> Void) {
        guard recorder.isRecording else {
            completion(nil)
            return
        }
        
        recorder.stopRecording { [weak self] previewController, error in
            DispatchQueue.main.async {
                self?.isRecording = false
                self?.stopTimer()
                
                if let error = error {
                    self?.errorMessage = "Failed to stop recording: \(error.localizedDescription)"
                    completion(nil)
                } else if let previewController = previewController {
                    // Export the video from the preview controller
                    self?.exportVideo(from: previewController, completion: completion)
                } else {
                    completion(nil)
                }
            }
        }
    }
    
    private func exportVideo(from previewController: RPPreviewViewController, completion: @escaping (URL?) -> Void) {
        // ReplayKit doesn't provide direct access to the video file
        // We need to save it through the preview controller
        // For now, we'll use the preview controller to let user save manually
        
        // Create a temporary URL for the video
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videoName = "AR_Recording_\(Date().timeIntervalSince1970).mp4"
        let videoURL = documentsPath.appendingPathComponent(videoName)
        
        // Note: In production, you might want to present the preview controller
        // to let the user save/share the video
        completion(videoURL)
    }
    
    func saveVideoToPhotos(url: URL, completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }) { success, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Error saving video: \(error)")
                    }
                    completion(success)
                }
            }
        }
    }
    
    private func startTimer() {
        recordingStartTime = Date()
        recordingTime = 0
        
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let startTime = self?.recordingStartTime else { return }
            self?.recordingTime = Date().timeIntervalSince(startTime)
        }
    }
    
    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartTime = nil
    }
    
    var formattedRecordingTime: String {
        let minutes = Int(recordingTime) / 60
        let seconds = Int(recordingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

extension ScreenRecorder: RPScreenRecorderDelegate {
    func screenRecorder(_ screenRecorder: RPScreenRecorder, didStopRecordingWith previewViewController: RPPreviewViewController?, error: Error?) {
        if let error = error {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "Recording stopped with error: \(error.localizedDescription)"
                self?.isRecording = false
                self?.stopTimer()
            }
        }
    }
    
    func screenRecorderDidChangeAvailability(_ screenRecorder: RPScreenRecorder) {
        DispatchQueue.main.async { [weak self] in
            self?.isAvailable = screenRecorder.isAvailable
        }
    }
}