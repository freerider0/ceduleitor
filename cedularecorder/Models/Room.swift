import Foundation

struct Room: Identifiable, Codable {
    let id: UUID
    let type: String
    let displayName: String
    let number: Int
    let addedAt: TimeInterval
    var checklist: [ChecklistItem]
    var checkedItemIds: Set<String>
    var latitude: Double?
    var longitude: Double?
    var arMeasurements: [ARMeasurementData] = []
    
    init(id: UUID = UUID(), type: String, displayName: String, number: Int, addedAt: TimeInterval, checklist: [ChecklistItem], checkedItemIds: Set<String> = [], latitude: Double? = nil, longitude: Double? = nil, arMeasurements: [ARMeasurementData] = []) {
        self.id = id
        self.type = type
        self.displayName = displayName
        self.number = number
        self.addedAt = addedAt
        self.checklist = checklist
        self.checkedItemIds = checkedItemIds
        self.latitude = latitude
        self.longitude = longitude
        self.arMeasurements = arMeasurements
    }
    
    var name: String {
        if number > 1 {
            return "\(displayName) \(number)"
        }
        return displayName
    }
    
    var progress: (completed: Int, total: Int) {
        (checkedItemIds.count, checklist.count)
    }
    
    var progressText: String {
        "\(checkedItemIds.count)/\(checklist.count)"
    }
    
    var isComplete: Bool {
        checkedItemIds.count == checklist.count
    }
    
    var statusEmoji: String {
        if isComplete {
            return "✅"
        } else if checkedItemIds.count > 0 {
            return "🟡"
        } else {
            return "🔴"
        }
    }
}

struct RoomTypeConfig: Codable {
    let displayName: String
    let checklist: [ChecklistItemConfig]
    
    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case checklist
    }
}

struct RoomConfiguration: Codable {
    let roomTypes: [String: RoomTypeConfig]
    
    enum CodingKeys: String, CodingKey {
        case roomTypes = "room_types"
    }
}

// AR Measurement data structure for storage
struct ARMeasurementData: Codable {
    let id: UUID
    let type: String  // "distance", "rectangle", "circle", "line"
    let label: String
    let timestamp: TimeInterval
    let value: Double?  // Distance in meters or radius
    let width: Double?  // For rectangles
    let height: Double?  // For rectangles
    
    init(id: UUID = UUID(), type: String, label: String, timestamp: TimeInterval, value: Double? = nil, width: Double? = nil, height: Double? = nil) {
        self.id = id
        self.type = type
        self.label = label
        self.timestamp = timestamp
        self.value = value
        self.width = width
        self.height = height
    }
}