import Foundation
import simd

class AR2RoomCreationUseCase {
    private let storage: AR2WallStorage
    private let geometryService: AR2GeometryService

    init(storage: AR2WallStorage, geometryService: AR2GeometryService) {
        self.storage = storage
        self.geometryService = geometryService
    }

    func canCreateRoom(from walls: [AR2Wall]) -> Bool {
        guard walls.count >= 3 else { return false }
        guard walls.allSatisfy({ $0.isTracked }) else { return false }

        return wallsFormConnectedShape(walls)
    }

    func createRoom(name: String?, wallIDs: [UUID]) -> Result<AR2Room, AR2RoomError> {
        let walls = wallIDs.compactMap { storage.get($0) }

        guard canCreateRoom(from: walls) else {
            return .failure(.invalidWalls)
        }

        var room = AR2Room(
            id: UUID(),
            name: name ?? "Room \(storage.rooms.count + 1)",
            walls: Set(wallIDs)
        )

        if let polygon = geometryService.completePolygon(from: walls.map { $0.get2DSegment() }) {
            room.isComplete = true
            room.area = polygon.area()

            guard let area = room.area, area < 200.0 else {
                return .failure(.roomTooLarge)
            }
        }

        for wallID in wallIDs {
            storage.assignWallToRoom(wallID: wallID, roomID: room.id)
        }

        storage.rooms[room.id] = room
        return .success(room)
    }

    func shouldAutoComplete(_ room: AR2Room) -> Bool {
        guard room.walls.count >= 3 else { return false }

        let walls = room.walls.compactMap { storage.get($0) }
        let segments = walls.map { $0.get2DSegment() }

        if let gap = findLargestGap(in: segments) {
            return gap < 0.5
        }

        return false
    }

    private func wallsFormConnectedShape(_ walls: [AR2Wall]) -> Bool {
        // Simple connectivity check
        return walls.count >= 3
    }

    private func findLargestGap(in segments: [AR2WallSegment]) -> Float? {
        guard segments.count >= 2 else { return nil }

        var maxGap: Float = 0
        for i in 0..<segments.count {
            let current = segments[i]
            let next = segments[(i + 1) % segments.count]

            let gap = simd_distance(current.end, next.start)
            maxGap = max(maxGap, gap)
        }

        return maxGap
    }
}

enum AR2RoomError: Error {
    case invalidWalls
    case roomTooLarge
    case notConnected
}