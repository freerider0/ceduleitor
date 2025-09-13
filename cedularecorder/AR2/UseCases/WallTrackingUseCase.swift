import Foundation
import simd

class AR2WallTrackingUseCase {
    private let storage: AR2WallStorage

    init(storage: AR2WallStorage) {
        self.storage = storage
    }

    func canTrackWall(_ wall: AR2Wall) -> Bool {
        // Allow tracking any surface with minimum size
        guard wall.extent.width >= 0.1 else { return false }
        guard wall.extent.height >= 0.1 else { return false }
        // Remove classification restriction - allow windows, doors, unknown, etc.
        guard storage.trackedWalls.count < 20 else { return false }

        return true
    }

    func trackWall(_ wallID: UUID) -> Result<AR2Wall, AR2TrackingError> {
        guard var wall = storage.get(wallID) else {
            return .failure(.wallNotFound)
        }

        guard canTrackWall(wall) else {
            return .failure(.invalidWall)
        }

        storage.trackedWalls.insert(wallID)
        wall.isTracked = true
        storage.update(wallID, with: wall)

        return .success(wall)
    }

    func shouldMergeWalls(_ wall1: AR2Wall, _ wall2: AR2Wall) -> Bool {
        let position1 = wall1.transform.columns.3.xyz
        let position2 = wall2.transform.columns.3.xyz
        let distance = simd_distance(position1, position2)

        let rotation1 = atan2(wall1.transform.columns.0.z, wall1.transform.columns.0.x)
        let rotation2 = atan2(wall2.transform.columns.0.z, wall2.transform.columns.0.x)
        let angleDiff = abs(rotation1 - rotation2)

        return distance < 0.2 &&
               angleDiff < 0.1 &&
               wall1.classification == wall2.classification
    }
}

enum AR2TrackingError: Error {
    case wallNotFound
    case invalidWall
    case maximumWallsReached
}