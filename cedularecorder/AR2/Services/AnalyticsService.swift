import Foundation

class AR2AnalyticsService {
    func trackWallDetected(classification: AR2PlaneClassification) {
        print("[Analytics] Wall detected: \(classification)")
    }

    func trackRoomCompleted(wallCount: Int, area: Float) {
        print("[Analytics] Room completed: \(wallCount) walls, \(area)m²")
    }

    func trackInteraction(action: String) {
        print("[Analytics] User action: \(action)")
    }
}