import Foundation

class ConfigurationLoader: ObservableObject {
    @Published var currentDecree: Decree?
    @Published var selectedDecreeName: String?
    private var roomCounters: [String: Int] = [:]
    private var decreeChecklists: DecreeChecklists?
    
    init() {
        loadDecreeChecklists()
    }
    
    func loadConfiguration() {
        // Load decree checklists if not already loaded
        if decreeChecklists == nil {
            loadDecreeChecklists()
        }
    }
    
    func setDecreeByDate(_ date: Date) {
        guard let decrees = decreeChecklists?.decrees else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for decree in decrees {
            // Handle null end date (current decree)
            let endDate: Date
            if let endDateString = decree.dateRange.end {
                endDate = dateFormatter.date(from: endDateString) ?? Date()
            } else {
                endDate = Date() // Current decree, valid until now
            }
            
            // Handle null start date (oldest decree)
            let startDate: Date
            if let startDateString = decree.dateRange.start {
                startDate = dateFormatter.date(from: startDateString) ?? Date(timeIntervalSince1970: 0)
            } else {
                startDate = Date(timeIntervalSince1970: 0) // Very old date
            }
            
            if date >= startDate && date <= endDate {
                self.currentDecree = decree
                self.selectedDecreeName = decree.name
                return
            }
        }
        
        // If no decree matches, use the most recent one
        if let lastDecree = decrees.last {
            self.currentDecree = lastDecree
            self.selectedDecreeName = lastDecree.name
        }
    }
    
    func createRoom(ofType type: String, latitude: Double? = nil, longitude: Double? = nil) -> Room? {
        guard let decree = currentDecree,
              let roomType = decree.roomTypes?[type] else {
            print("Cannot create room: No decree selected or room type not found")
            return nil
        }
        
        // Increment counter for this room type
        let currentCount = roomCounters[type] ?? 0
        let roomNumber = currentCount + 1
        roomCounters[type] = roomNumber
        
        // Create checklist items from decree checklist
        let checklistItems = roomType.checklist.enumerated().map { (index, text) in
            ChecklistItem(
                id: "\(type)_item_\(index)",
                text: text,
                description: "",
                isChecked: false,
                checkedAt: nil
            )
        }
        
        return Room(
            id: UUID(),
            type: type,
            displayName: roomType.name,
            number: roomNumber,
            addedAt: Date().timeIntervalSince1970,
            checklist: checklistItems,
            checkedItemIds: [],
            latitude: latitude,
            longitude: longitude
        )
    }
    
    func resetCounters() {
        roomCounters.removeAll()
    }
    
    var availableRoomTypes: [(key: String, value: DecreeRoomType)] {
        guard let decree = currentDecree,
              let roomTypes = decree.roomTypes else { return [] }
        return roomTypes.sorted { $0.value.name < $1.value.name }
    }
    
    // MARK: - Decree Handling
    
    private func loadDecreeChecklists() {
        guard let url = Bundle.main.url(forResource: "decree_checklists", withExtension: "json") else {
            print("Could not find decree_checklists.json in bundle")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            self.decreeChecklists = try JSONDecoder().decode(DecreeChecklists.self, from: data)
        } catch {
            print("Error loading decree checklists: \(error)")
        }
    }
    
    func getDecreeForDate(_ date: Date) -> Decree? {
        setDecreeByDate(date)
        return currentDecree
    }
}

// MARK: - Decree Models

struct DecreeChecklists: Codable {
    let decrees: [Decree]
}

struct Decree: Codable {
    let id: String
    let name: String
    let description: String
    let dateRange: DateRange
    let roomTypes: [String: DecreeRoomType]?
    
    struct DateRange: Codable {
        let start: String?
        let end: String?
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, description
        case dateRange = "date_range"
        case roomTypes = "room_types"
    }
}

struct DecreeRoomType: Codable {
    let name: String
    let checklist: [String]
}