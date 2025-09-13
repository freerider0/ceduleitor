import Foundation

class AR2WallStorage {
    var walls: [UUID: AR2Wall] = [:]
    var rooms: [UUID: AR2Room] = [:]
    var trackedWalls: Set<UUID> = []
    var currentRoomID: UUID?

    // MARK: - Wall CRUD

    func add(_ wall: AR2Wall) {
        walls[wall.id] = wall
    }

    func update(_ id: UUID, with wall: AR2Wall) {
        walls[id] = wall
    }

    func remove(_ id: UUID) {
        walls.removeValue(forKey: id)
        trackedWalls.remove(id)
    }

    func get(_ id: UUID) -> AR2Wall? {
        walls[id]
    }

    // MARK: - Room Management

    func createRoom(name: String? = nil) -> AR2Room {
        let room = AR2Room(id: UUID(), name: name)
        rooms[room.id] = room
        currentRoomID = room.id
        return room
    }

    func assignWallToRoom(wallID: UUID, roomID: UUID) {
        if var wall = walls[wallID], var room = rooms[roomID] {
            wall.roomID = roomID
            room.walls.insert(wallID)
            walls[wallID] = wall
            rooms[roomID] = room
        }
    }

    // MARK: - Queries

    func getTracked() -> [AR2Wall] {
        trackedWalls.compactMap { walls[$0] }
    }

    func getWallsForRoom(_ roomID: UUID) -> [AR2Wall] {
        guard let room = rooms[roomID] else { return [] }
        return room.walls.compactMap { walls[$0] }
    }

    func getRoomsForWall(_ wallID: UUID) -> [AR2Room] {
        guard let wall = walls[wallID] else { return [] }
        return wall.adjacentRooms.compactMap { rooms[$0] }
    }

    func getByClassification(_ type: AR2PlaneClassification) -> [AR2Wall] {
        walls.values.filter { $0.classification == type }
    }
}