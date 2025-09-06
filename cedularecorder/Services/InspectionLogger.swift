import Foundation

// ==================================================
// MARK: - Inspection Logger Service
// ==================================================
/// Manages inspection session logging and persistence with crash-safe operations
/// Handles all file I/O with proper error recovery
class InspectionLogger: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentSession: InspectionSession?
    @Published var sessions: [InspectionSession] = []
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let documentsPath: URL
    private let sessionsFile = "inspection_sessions.json"
    private let sessionQueue = DispatchQueue(label: "inspection.logger.queue")
    
    // MARK: - Initialization
    init() {
        // Get documents directory safely
        if let docsPath = FileManager.default.urls(for: .documentDirectory, 
                                                   in: .userDomainMask).first {
            self.documentsPath = docsPath
        } else {
            // Fallback to temp directory if documents unavailable
            self.documentsPath = URL(fileURLWithPath: NSTemporaryDirectory())
            print("Warning: Using temp directory for storage")
        }
        
        // Load existing sessions
        loadSessions()
    }
    
    // ==================================================
    // MARK: - Session Management
    // ==================================================
    
    /// Start a new inspection session
    func startNewSession(address: String, latitude: Double? = nil, longitude: Double? = nil, constructionDate: Date? = nil, decreeUsed: String? = nil) {
        // Validate address
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else {
            errorMessage = "Address cannot be empty"
            return
        }
        
        // Create new session
        let session = InspectionSession(
            date: Date(),
            address: trimmedAddress,
            startLatitude: latitude,
            startLongitude: longitude,
            constructionDate: constructionDate,
            decreeUsed: decreeUsed
        )
        
        currentSession = session
        
        // Log recording started event
        logEvent(.recordingStarted, room: nil, item: nil)
    }
    
    /// End the current session and save it
    /// Returns the permanent video URL if successful
    func endSession(videoURL: URL?, duration: TimeInterval) -> URL? {
        guard currentSession != nil else {
            print("No active session to end")
            return nil
        }
        
        var permanentVideoURL: URL? = nil
        
        // Copy video file to permanent location if provided
        if let tempURL = videoURL {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                // Create permanent video filename
                let videoFileName = "video_\(currentSession!.id.uuidString).mp4"
                let permanentURL = documentsPath.appendingPathComponent(videoFileName)
                
                do {
                    // Remove existing file if it exists
                    if FileManager.default.fileExists(atPath: permanentURL.path) {
                        try FileManager.default.removeItem(at: permanentURL)
                    }
                    
                    // Copy video to permanent location
                    try FileManager.default.copyItem(at: tempURL, to: permanentURL)
                    currentSession?.videoURL = permanentURL
                    permanentVideoURL = permanentURL
                    print("Video saved to: \(permanentURL.lastPathComponent)")
                    
                    // Don't delete temp file yet - we'll save to photos first
                } catch {
                    print("Error copying video file: \(error)")
                    errorMessage = "Failed to save video file"
                    // Fall back to temp URL if copy fails
                    currentSession?.videoURL = tempURL
                    permanentVideoURL = tempURL
                }
            } else {
                print("Warning: Video file not found at \(tempURL)")
                errorMessage = "Video file was not saved properly"
            }
        }
        
        // Update duration
        currentSession?.duration = duration
        
        // Log recording stopped event
        logEvent(.recordingStopped, room: nil, item: nil)
        
        // Save the completed session
        if let finalSession = currentSession {
            sessions.append(finalSession)
            saveSessions()
            exportSessionData(finalSession)
        }
        
        currentSession = nil
        
        return permanentVideoURL
    }
    
    // ==================================================
    // MARK: - Room Management
    // ==================================================
    
    /// Add a room to the current session
    func addRoom(_ room: Room) {
        guard currentSession != nil else {
            print("Cannot add room: No active session")
            return
        }
        
        // Validate room
        guard !room.displayName.isEmpty else {
            print("Cannot add room with empty name")
            return
        }
        
        currentSession?.rooms.append(room)
        currentSession?.currentRoomId = room.id
        
        logEvent(.roomAdded, room: room, item: nil)
    }
    
    /// Switch to a different room
    func switchToRoom(_ room: Room) {
        guard let session = currentSession else {
            print("Cannot switch room: No active session")
            return
        }
        
        // Validate room exists in session
        guard session.rooms.contains(where: { $0.id == room.id }) else {
            print("Cannot switch to room not in session")
            return
        }
        
        let currentRoom = session.currentRoom
        
        logEvent(
            .roomSwitched,
            room: nil,
            item: nil,
            fromRoom: currentRoom?.name,
            toRoom: room.name
        )
        
        currentSession?.currentRoomId = room.id
    }
    
    // ==================================================
    // MARK: - Checklist Management
    // ==================================================
    
    /// Mark a checklist item as checked
    func checkItem(_ item: ChecklistItem, in room: Room, at timestamp: TimeInterval) {
        guard currentSession != nil else {
            print("Cannot check item: No active session")
            return
        }
        
        // Find room index safely
        guard let roomIndex = currentSession?.rooms.firstIndex(where: { $0.id == room.id }) else {
            print("Room not found in session")
            return
        }
        
        // Update room's checked items
        currentSession?.rooms[roomIndex].checkedItemIds.insert(item.id)
        
        // Update the checklist item's timestamp
        if let itemIndex = currentSession?.rooms[roomIndex].checklist.firstIndex(where: { $0.id == item.id }) {
            currentSession?.rooms[roomIndex].checklist[itemIndex].isChecked = true
            currentSession?.rooms[roomIndex].checklist[itemIndex].checkedAt = timestamp
        }
        
        logEvent(
            .itemChecked,
            room: room,
            item: item,
            timestamp: timestamp
        )
    }
    
    /// Mark a checklist item as unchecked
    func uncheckItem(_ item: ChecklistItem, in room: Room) {
        guard currentSession != nil else {
            print("Cannot uncheck item: No active session")
            return
        }
        
        // Find room index safely
        guard let roomIndex = currentSession?.rooms.firstIndex(where: { $0.id == room.id }) else {
            print("Room not found in session")
            return
        }
        
        // Update room's checked items
        currentSession?.rooms[roomIndex].checkedItemIds.remove(item.id)
        
        // Update the checklist item
        if let itemIndex = currentSession?.rooms[roomIndex].checklist.firstIndex(where: { $0.id == item.id }) {
            currentSession?.rooms[roomIndex].checklist[itemIndex].isChecked = false
            currentSession?.rooms[roomIndex].checklist[itemIndex].checkedAt = nil
        }
        
        logEvent(.itemUnchecked, room: room, item: item)
    }
    
    // ==================================================
    // MARK: - Event Logging
    // ==================================================
    
    /// Log an inspection event
    private func logEvent(
        _ type: InspectionEvent.EventType,
        room: Room?,
        item: ChecklistItem?,
        timestamp: TimeInterval? = nil,
        fromRoom: String? = nil,
        toRoom: String? = nil
    ) {
        guard currentSession != nil else { return }
        
        let sessionStartTime = currentSession?.date.timeIntervalSince1970 ?? Date().timeIntervalSince1970
        let eventTimestamp = timestamp ?? (Date().timeIntervalSince1970 - sessionStartTime)
        
        let event = InspectionEvent(
            timestamp: eventTimestamp,
            type: type,
            roomName: room?.name,
            roomType: room?.type,
            itemId: item?.id,
            itemText: item?.text,
            fromRoom: fromRoom,
            toRoom: toRoom
        )
        
        currentSession?.events.append(event)
    }
    
    // ==================================================
    // MARK: - Data Export
    // ==================================================
    
    /// Export session data to JSON file
    private func exportSessionData(_ session: InspectionSession) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            
            do {
                let data = try encoder.encode(session)
                let filename = "inspection_\(session.id.uuidString).json"
                let url = self.documentsPath.appendingPathComponent(filename)
                
                // Write with data protection
                try data.write(to: url, options: [.atomic, .completeFileProtection])
                print("Exported session to: \(filename)")
                
            } catch {
                print("Failed to export session: \(error)")
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to save inspection data"
                }
            }
        }
    }
    
    // ==================================================
    // MARK: - Data Persistence
    // ==================================================
    
    /// Load saved sessions from disk
    func loadSessions() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let url = self.documentsPath.appendingPathComponent(self.sessionsFile)
            
            // Check if file exists
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("No saved sessions found")
                return
            }
            
            do {
                let data = try Data(contentsOf: url)
                
                // Validate data is not empty
                guard !data.isEmpty else {
                    print("Sessions file is empty")
                    return
                }
                
                let decoder = JSONDecoder()
                // Try different date decoding strategies
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    
                    // Try to decode as TimeInterval (number)
                    if let timeInterval = try? container.decode(TimeInterval.self) {
                        return Date(timeIntervalSince1970: timeInterval)
                    }
                    
                    // Try to decode as ISO8601 string
                    if let dateString = try? container.decode(String.self) {
                        let formatter = ISO8601DateFormatter()
                        if let date = formatter.date(from: dateString) {
                            return date
                        }
                    }
                    
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date")
                }
                
                let loadedSessions = try decoder.decode([InspectionSession].self, from: data)
                
                DispatchQueue.main.async {
                    self.sessions = loadedSessions
                    self.errorMessage = nil
                }
                
            } catch {
                print("Error loading sessions: \(error)")
                // Don't crash - continue with empty sessions
                DispatchQueue.main.async {
                    self.errorMessage = "Could not load previous inspections"
                }
            }
        }
    }
    
    /// Save sessions to disk
    private func saveSessions() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let url = self.documentsPath.appendingPathComponent(self.sessionsFile)
            
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                // Use timeIntervalSince1970 for consistent encoding/decoding
                encoder.dateEncodingStrategy = .secondsSince1970
                let data = try encoder.encode(self.sessions)
                
                // Write with data protection and atomic write
                try data.write(to: url, options: [.atomic, .completeFileProtection])
                print("Saved \(self.sessions.count) sessions")
                
            } catch {
                print("Error saving sessions: \(error)")
                DispatchQueue.main.async {
                    self.errorMessage = "Could not save inspection data"
                }
            }
        }
    }
    
    // ==================================================
    // MARK: - Data Retrieval
    // ==================================================
    
    /// Get inspection points for video navigation
    func getInspectionPoints(for session: InspectionSession) -> [(room: String, item: String, timestamp: String, seconds: TimeInterval)] {
        var points: [(room: String, item: String, timestamp: String, seconds: TimeInterval)] = []
        
        for event in session.events {
            if event.type == .itemChecked,
               let roomName = event.roomName,
               let itemText = event.itemText {
                points.append((
                    room: roomName,
                    item: itemText,
                    timestamp: event.formattedTime,
                    seconds: event.timestamp
                ))
            }
        }
        
        return points.sorted { $0.seconds < $1.seconds }
    }
    
    /// Delete a session safely
    func deleteSession(at index: Int) {
        guard index >= 0 && index < sessions.count else {
            print("Invalid session index: \(index)")
            return
        }
        
        let session = sessions[index]
        
        // Remove session from array
        sessions.remove(at: index)
        
        // Delete associated files
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Delete JSON export if exists
            let jsonFile = "inspection_\(session.id.uuidString).json"
            let jsonURL = self.documentsPath.appendingPathComponent(jsonFile)
            
            do {
                if FileManager.default.fileExists(atPath: jsonURL.path) {
                    try FileManager.default.removeItem(at: jsonURL)
                }
            } catch {
                print("Could not delete session file: \(error)")
            }
            
            // Delete video file if exists
            if let videoURL = session.videoURL,
               FileManager.default.fileExists(atPath: videoURL.path) {
                do {
                    try FileManager.default.removeItem(at: videoURL)
                } catch {
                    print("Could not delete video file: \(error)")
                }
            }
            
            // Save updated sessions list
            self.saveSessions()
        }
    }
}