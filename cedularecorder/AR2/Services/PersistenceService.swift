import Foundation

class AR2PersistenceService {
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

    func saveRooms(_ rooms: [AR2Room]) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(rooms)
        let url = documentsDirectory.appendingPathComponent("rooms.json")
        try data.write(to: url)
    }

    func loadRooms() throws -> [AR2Room] {
        let url = documentsDirectory.appendingPathComponent("rooms.json")
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode([AR2Room].self, from: data)
    }

    func exportToUSDZ(rooms: [AR2Room]) throws -> URL {
        let exportURL = documentsDirectory.appendingPathComponent("room_\(Date().timeIntervalSince1970).usdz")
        // TODO: Implement USDZ export using ModelIO/SceneKit
        return exportURL
    }
}