import Foundation
import UIKit

// MARK: - Floor
/// Represents a single floor/level in a building
class Floor: Identifiable, Codable {
    let id: UUID
    var name: String
    var level: Int  // 0 = ground floor, 1 = first floor, -1 = basement
    var rooms: [CADRoom]
    var isActive: Bool
    
    /// Total area of all rooms on this floor
    var totalArea: Double {
        rooms.reduce(0) { $0 + $1.area }
    }
    
    init(name: String = "Ground Floor", level: Int = 0) {
        self.id = UUID()
        self.name = name
        self.level = level
        self.rooms = []
        self.isActive = true
    }
}

// MARK: - Floor Plan
/// Complete floor plan containing multiple floors and rooms
class FloorPlan: Codable {
    let id: UUID
    var name: String
    var floors: [Floor]
    var currentFloorIndex: Int
    var createdAt: Date
    var modifiedAt: Date
    
    /// Currently active floor
    var currentFloor: Floor? {
        guard currentFloorIndex < floors.count else { return nil }
        return floors[currentFloorIndex]
    }
    
    /// Total area of entire building
    var totalArea: Double {
        floors.reduce(0) { $0 + $1.totalArea }
    }
    
    /// Total number of rooms
    var totalRooms: Int {
        floors.reduce(0) { $0 + $1.rooms.count }
    }
    
    init(name: String = "New Project") {
        self.id = UUID()
        self.name = name
        self.floors = [Floor()]  // Start with ground floor
        self.currentFloorIndex = 0
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
    
    /// Add a new floor
    func addFloor(name: String? = nil, level: Int? = nil) {
        let floorLevel = level ?? floors.count
        let floorName = name ?? "Floor \(floorLevel)"
        let newFloor = Floor(name: floorName, level: floorLevel)
        floors.append(newFloor)
    }
    
    /// Add room to current floor
    func addRoom(_ room: CADRoom) {
        currentFloor?.rooms.append(room)
        modifiedAt = Date()
    }
    
    /// Remove room from current floor
    func removeRoom(_ room: CADRoom) {
        currentFloor?.rooms.removeAll { $0.id == room.id }
        modifiedAt = Date()
    }
    
    /// Find room by ID across all floors
    func findRoom(by id: UUID) -> (room: CADRoom, floor: Floor)? {
        for floor in floors {
            if let room = floor.rooms.first(where: { $0.id == id }) {
                return (room, floor)
            }
        }
        return nil
    }
}