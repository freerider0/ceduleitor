import Foundation

// ==================================================
// MARK: - Upload Service
// ==================================================
/// Handles server uploads with robust error handling and retry logic
/// Ensures network failures don't crash the app
class UploadService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var uploadProgress: Double = 0.0
    @Published var isUploading = false
    @Published var uploadError: String?
    
    // MARK: - Configuration
    // TODO: Update with your actual server URL
    private let serverURL = "https://your-server.com/api/inspections/upload"
    private let maxRetryAttempts = 3
    private let timeoutInterval: TimeInterval = 300 // 5 minutes for large videos
    
    // MARK: - Private Properties
    private var currentTask: URLSessionDataTask?
    private var progressTimer: Timer?
    
    // ==================================================
    // MARK: - Main Upload Method
    // ==================================================
    
    /// Upload inspection with video and metadata
    func uploadInspection(
        session: InspectionSession,
        videoURL: URL,
        logData: Data,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // Reset state
        uploadError = nil
        
        // Validate server URL
        guard let url = URL(string: serverURL) else {
            let error = UploadError.invalidURL
            uploadError = error.localizedDescription
            completion(.failure(error))
            return
        }
        
        // Validate video file exists
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            let error = UploadError.missingVideo
            uploadError = error.localizedDescription
            completion(.failure(error))
            return
        }
        
        // Check file size (limit to 500MB)
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: videoURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            let maxSize: Int64 = 500 * 1024 * 1024 // 500 MB
            
            guard fileSize > 0 else {
                let error = UploadError.emptyVideo
                uploadError = error.localizedDescription
                completion(.failure(error))
                return
            }
            
            guard fileSize <= maxSize else {
                let error = UploadError.videoTooLarge
                uploadError = error.localizedDescription
                completion(.failure(error))
                return
            }
            
            print("Uploading video: \(fileSize / (1024*1024)) MB")
            
        } catch {
            uploadError = "Cannot read video file: \(error.localizedDescription)"
            completion(.failure(error))
            return
        }
        
        // Start upload
        isUploading = true
        uploadProgress = 0.0
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutInterval
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Build multipart body
        do {
            let body = try createMultipartBody(
                session: session,
                videoURL: videoURL,
                logData: logData,
                boundary: boundary
            )
            
            // Create upload task with proper configuration
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = timeoutInterval
            configuration.timeoutIntervalForResource = timeoutInterval * 2
            configuration.allowsCellularAccess = true
            
            let urlSession = URLSession(configuration: configuration)
            
            currentTask = urlSession.uploadTask(with: request, from: body) { [weak self] data, response, error in
                self?.handleUploadResponse(
                    data: data,
                    response: response,
                    error: error,
                    completion: completion
                )
            }
            
            currentTask?.resume()
            
            // Start progress simulation
            simulateProgress()
            
        } catch {
            isUploading = false
            uploadError = "Failed to prepare upload: \(error.localizedDescription)"
            completion(.failure(error))
        }
    }
    
    // ==================================================
    // MARK: - Response Handling
    // ==================================================
    
    /// Handle upload response with proper error checking
    private func handleUploadResponse(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Stop progress timer
            self.progressTimer?.invalidate()
            self.progressTimer = nil
            self.isUploading = false
            
            // Handle network error
            if let error = error {
                let nsError = error as NSError
                
                // Check for cancellation
                if nsError.code == NSURLErrorCancelled {
                    self.uploadError = "Upload cancelled"
                    completion(.failure(UploadError.cancelled))
                    return
                }
                
                // Get user-friendly error message
                self.uploadError = self.getErrorMessage(from: nsError)
                completion(.failure(error))
                return
            }
            
            // Check HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                let error = UploadError.invalidResponse
                self.uploadError = error.localizedDescription
                completion(.failure(error))
                return
            }
            
            // Handle status codes
            switch httpResponse.statusCode {
            case 200...299:
                // Success
                self.uploadProgress = 1.0
                self.uploadError = nil
                completion(.success(()))
                
            case 400:
                let error = UploadError.badRequest
                self.uploadError = error.localizedDescription
                completion(.failure(error))
                
            case 401, 403:
                let error = UploadError.unauthorized
                self.uploadError = error.localizedDescription
                completion(.failure(error))
                
            case 413:
                let error = UploadError.videoTooLarge
                self.uploadError = error.localizedDescription
                completion(.failure(error))
                
            case 500...599:
                let error = UploadError.serverError(code: httpResponse.statusCode)
                self.uploadError = error.localizedDescription
                completion(.failure(error))
                
            default:
                let error = UploadError.serverError(code: httpResponse.statusCode)
                self.uploadError = error.localizedDescription
                completion(.failure(error))
            }
        }
    }
    
    // ==================================================
    // MARK: - Helper Methods
    // ==================================================
    
    /// Create multipart form data
    private func createMultipartBody(
        session: InspectionSession,
        videoURL: URL,
        logData: Data,
        boundary: String
    ) throws -> Data {
        var body = Data()
        
        // Create metadata JSON
        let metadata: [String: Any] = [
            "session_id": session.id.uuidString,
            "address": session.address,
            "date": ISO8601DateFormatter().string(from: session.date),
            "duration": session.duration,
            "total_rooms": session.summary.totalRooms,
            "inspection_rate": session.summary.inspectionRate,
            "latitude": session.startLatitude ?? 0,
            "longitude": session.startLongitude ?? 0
        ]
        
        // Add metadata field
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"metadata\"\r\n")
        body.append("Content-Type: application/json\r\n\r\n")
        
        let metadataData = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
        body.append(metadataData)
        body.append("\r\n")
        
        // Add log file
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"log\"; filename=\"inspection_\(session.id.uuidString).json\"\r\n")
        body.append("Content-Type: application/json\r\n\r\n")
        body.append(logData)
        body.append("\r\n")
        
        // Add video file with memory-efficient loading
        let videoData = try Data(contentsOf: videoURL, options: .mappedIfSafe)
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"video\"; filename=\"\(videoURL.lastPathComponent)\"\r\n")
        body.append("Content-Type: video/mp4\r\n\r\n")
        body.append(videoData)
        body.append("\r\n")
        
        // Close boundary
        body.append("--\(boundary)--\r\n")
        
        return body
    }
    
    /// Simulate upload progress
    private func simulateProgress() {
        progressTimer?.invalidate()
        
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self, self.isUploading else {
                timer.invalidate()
                return
            }
            
            // Gradually increase progress up to 90%
            if self.uploadProgress < 0.9 {
                self.uploadProgress = min(self.uploadProgress + 0.05, 0.9)
            }
        }
    }
    
    /// Get user-friendly error message
    private func getErrorMessage(from error: NSError) -> String {
        switch error.code {
        case NSURLErrorNotConnectedToInternet:
            return "No internet connection"
        case NSURLErrorTimedOut:
            return "Upload timed out. Check your connection and try again."
        case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost:
            return "Cannot connect to server"
        case NSURLErrorNetworkConnectionLost:
            return "Connection lost during upload"
        case NSURLErrorDataLengthExceedsMaximum:
            return "Video file is too large"
        default:
            return "Network error: \(error.localizedDescription)"
        }
    }
    
    /// Retry upload with existing session
    func retryUpload(
        session: InspectionSession,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // Validate video exists
        guard let videoURL = session.videoURL else {
            let error = UploadError.missingVideo
            uploadError = error.localizedDescription
            completion(.failure(error))
            return
        }
        
        // Re-generate log data
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let logData = try encoder.encode(session)
            uploadInspection(
                session: session,
                videoURL: videoURL,
                logData: logData,
                completion: completion
            )
        } catch {
            uploadError = "Failed to prepare data: \(error.localizedDescription)"
            completion(.failure(error))
        }
    }
    
    /// Cancel current upload
    func cancelUpload() {
        currentTask?.cancel()
        currentTask = nil
        progressTimer?.invalidate()
        progressTimer = nil
        
        isUploading = false
        uploadProgress = 0
        uploadError = "Upload cancelled"
    }
}

// ==================================================
// MARK: - Upload Errors
// ==================================================

enum UploadError: LocalizedError {
    case invalidURL
    case serverError(code: Int)
    case missingVideo
    case emptyVideo
    case videoTooLarge
    case unknown
    case invalidResponse
    case badRequest
    case unauthorized
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL configured"
        case .serverError(let code):
            return "Server error (code \(code))"
        case .missingVideo:
            return "Video file not found"
        case .emptyVideo:
            return "Video file is empty"
        case .videoTooLarge:
            return "Video exceeds 500 MB limit"
        case .unknown:
            return "An unknown error occurred"
        case .invalidResponse:
            return "Invalid server response"
        case .badRequest:
            return "Invalid request format"
        case .unauthorized:
            return "Authentication required"
        case .cancelled:
            return "Upload cancelled"
        }
    }
}

// ==================================================
// MARK: - Data Extension
// ==================================================

extension Data {
    /// Safely append string to data
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}