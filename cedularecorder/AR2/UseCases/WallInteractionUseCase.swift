import Foundation

class AR2WallInteractionUseCase {
    private let storage: AR2WallStorage
    private let trackingUseCase: AR2WallTrackingUseCase

    init(storage: AR2WallStorage, trackingUseCase: AR2WallTrackingUseCase) {
        self.storage = storage
        self.trackingUseCase = trackingUseCase
    }

    func handleWallTap(_ wallID: UUID) -> AR2WallAction {
        guard let wall = storage.get(wallID) else {
            return .none
        }

        if wall.isTracked {
            return .untrack(wallID)
        } else if trackingUseCase.canTrackWall(wall) {
            return .track(wallID)
        } else {
            return .showError(reason: getTrackingError(wall))
        }
    }

    func canDeleteWall(_ wallID: UUID) -> Bool {
        guard let wall = storage.get(wallID) else { return false }

        if let roomID = wall.roomID,
           let room = storage.rooms[roomID] {
            return room.walls.count > 3
        }

        return true
    }

    private func getTrackingError(_ wall: AR2Wall) -> String {
        // planeExtent has width and height properties
        if wall.extent.width < 0.1 { return "Wall too narrow" }
        if wall.extent.height < 0.1 { return "Wall too short" }

        // Allow any classification including none/unknown
        if storage.trackedWalls.count >= 20 { return "Maximum walls reached" }
        return "Cannot track wall"
    }
}

enum AR2WallAction {
    case track(UUID)
    case untrack(UUID)
    case showError(reason: String)
    case none
}