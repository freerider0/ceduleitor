import Foundation

struct InspectionSession: Identifiable, Codable {
    let id: UUID
    let date: Date
    var address: String
    var videoURL: URL?
    var duration: TimeInterval
    var rooms: [Room]
    var currentRoomId: UUID?
    var events: [InspectionEvent]
    var uploadStatus: UploadStatus
    var uploadDate: Date?
    var startLatitude: Double?
    var startLongitude: Double?
    var constructionDate: Date?
    var decreeUsed: String?
    
    init(id: UUID = UUID(), date: Date, address: String, videoURL: URL? = nil, duration: TimeInterval = 0, rooms: [Room] = [], currentRoomId: UUID? = nil, events: [InspectionEvent] = [], uploadStatus: UploadStatus = .notUploaded, uploadDate: Date? = nil, startLatitude: Double? = nil, startLongitude: Double? = nil, constructionDate: Date? = nil, decreeUsed: String? = nil) {
        self.id = id
        self.date = date
        self.address = address
        self.videoURL = videoURL
        self.duration = duration
        self.rooms = rooms
        self.currentRoomId = currentRoomId
        self.events = events
        self.uploadStatus = uploadStatus
        self.uploadDate = uploadDate
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.constructionDate = constructionDate
        self.decreeUsed = decreeUsed
    }
    
    var currentRoom: Room? {
        rooms.first { $0.id == currentRoomId }
    }
    
    var videoSizeMB: Double {
        guard let url = videoURL else { return 0 }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let size = attributes[.size] as? Int64 ?? 0
            return Double(size) / (1024 * 1024)
        } catch {
            return 0
        }
    }
    
    var summary: InspectionSummary {
        let totalChecks = rooms.reduce(0) { $0 + $1.checklist.count }
        let completedChecks = rooms.reduce(0) { $0 + $1.checkedItemIds.count }
        let rate = totalChecks > 0 ? (Double(completedChecks) / Double(totalChecks) * 100) : 0
        
        return InspectionSummary(
            totalRooms: rooms.count,
            totalChecks: totalChecks,
            completedChecks: completedChecks,
            inspectionRate: rate
        )
    }
}

struct InspectionEvent: Codable {
    enum EventType: String, Codable {
        case roomAdded = "room_added"
        case roomSwitched = "room_switched"
        case itemChecked = "item_checked"
        case itemUnchecked = "item_unchecked"
        case recordingStarted = "recording_started"
        case recordingStopped = "recording_stopped"
    }
    
    let timestamp: TimeInterval
    let type: EventType
    let roomName: String?
    let roomType: String?
    let itemId: String?
    let itemText: String?
    let fromRoom: String?
    let toRoom: String?
    
    var formattedTime: String {
        let minutes = Int(timestamp) / 60
        let seconds = Int(timestamp) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct InspectionSummary: Codable {
    let totalRooms: Int
    let totalChecks: Int
    let completedChecks: Int
    let inspectionRate: Double
}

enum UploadStatus: Codable {
    case notUploaded
    case uploading(progress: Double)
    case uploaded
    case failed(error: String)
    
    enum CodingKeys: String, CodingKey {
        case status
        case progress
        case error
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let status = try container.decode(String.self, forKey: .status)
        
        switch status {
        case "notUploaded":
            self = .notUploaded
        case "uploading":
            let progress = try container.decode(Double.self, forKey: .progress)
            self = .uploading(progress: progress)
        case "uploaded":
            self = .uploaded
        case "failed":
            let error = try container.decode(String.self, forKey: .error)
            self = .failed(error: error)
        default:
            self = .notUploaded
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .notUploaded:
            try container.encode("notUploaded", forKey: .status)
        case .uploading(let progress):
            try container.encode("uploading", forKey: .status)
            try container.encode(progress, forKey: .progress)
        case .uploaded:
            try container.encode("uploaded", forKey: .status)
        case .failed(let error):
            try container.encode("failed", forKey: .status)
            try container.encode(error, forKey: .error)
        }
    }
}