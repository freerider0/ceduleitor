import Foundation
import ARKit
import CoreLocation
@testable import cedularecorder

// MARK: - Mock AR Session
class MockARSession {
    var isRunning = false
    var mockFrames: [ARFrame] = []
    
    func run() {
        isRunning = true
    }
    
    func pause() {
        isRunning = false
    }
    
    func getCurrentFrame() -> ARFrame? {
        // In real tests, you'd return mock frames
        // For now, return nil (simulator friendly)
        return nil
    }
}

// MARK: - Mock Video Writer
class MockVideoWriter {
    var isRecording = false
    var recordingDuration: TimeInterval = 0
    var mockVideoURL: URL?
    
    init() {
        // Create a dummy file URL
        let tempDir = FileManager.default.temporaryDirectory
        mockVideoURL = tempDir.appendingPathComponent("mock_video_\(UUID().uuidString).mp4")
    }
    
    func startRecording() {
        isRecording = true
        recordingDuration = 0
    }
    
    func stopRecording() -> URL? {
        isRecording = false
        
        // Create a dummy file to simulate video
        if let url = mockVideoURL {
            FileManager.default.createFile(atPath: url.path, contents: Data(), attributes: nil)
            return url
        }
        return nil
    }
    
    func updateDuration(_ duration: TimeInterval) {
        recordingDuration = duration
    }
}

// MARK: - Mock Location Service
class MockLocationService {
    var mockLocation: CLLocation?
    var shouldFailLocationRequest = false
    
    init(latitude: Double = 37.7749, longitude: Double = -122.4194) {
        mockLocation = CLLocation(latitude: latitude, longitude: longitude)
    }
    
    func getCurrentLocation() -> CLLocation? {
        return shouldFailLocationRequest ? nil : mockLocation
    }
}

// MARK: - Test Data Factory
class TestDataFactory {
    
    static func makeInspectionSession(
        address: String = "123 Test Street",
        roomCount: Int = 2,
        withVideo: Bool = false
    ) -> InspectionSession {
        var session = InspectionSession(
            date: Date(),
            address: address,
            startLatitude: 37.7749,
            startLongitude: -122.4194,
            constructionDate: Date(),
            decreeUsed: "Test Decree"
        )
        
        // Add rooms
        for i in 0..<roomCount {
            let room = makeRoom(type: "testroom", number: i + 1)
            session.rooms.append(room)
        }
        
        if withVideo {
            session.videoURL = URL(string: "file://test_video.mp4")
            session.duration = 120.0 // 2 minutes
        }
        
        return session
    }
    
    static func makeRoom(
        type: String = "living",
        number: Int = 1,
        checklistCount: Int = 5,
        checkedCount: Int = 0
    ) -> Room {
        let checklist = makeChecklist(count: checklistCount)
        var checkedIds = Set<String>()
        
        // Check some items
        for i in 0..<min(checkedCount, checklistCount) {
            checkedIds.insert(checklist[i].id)
        }
        
        return Room(
            type: type,
            displayName: "Test Room",
            number: number,
            addedAt: Date().timeIntervalSince1970,
            checklist: checklist,
            checkedItemIds: checkedIds,
            latitude: 37.7749,
            longitude: -122.4194
        )
    }
    
    static func makeChecklist(count: Int = 5) -> [ChecklistItem] {
        var items: [ChecklistItem] = []
        for i in 0..<count {
            items.append(ChecklistItem(
                id: "item_\(i)",
                text: "Test Item \(i + 1)",
                description: "Description for test item \(i + 1)"
            ))
        }
        return items
    }
    
    static func makeARMeasurement(
        distance: Float = 2.5
    ) -> SimpleMeasurement {
        var measurement = SimpleMeasurement()
        measurement.startPoint = simd_float3(0, 0, 0)
        measurement.endPoint = simd_float3(distance, 0, 0)
        return measurement
    }
}

// MARK: - Mock Recording Coordinator
class MockRecordingCoordinator {
    var isRecording = false
    var currentSession: InspectionSession?
    var videoWriter = MockVideoWriter()
    var locationService = MockLocationService()
    
    func startInspection(address: String) {
        currentSession = InspectionSession(
            date: Date(),
            address: address,
            startLatitude: locationService.getCurrentLocation()?.coordinate.latitude,
            startLongitude: locationService.getCurrentLocation()?.coordinate.longitude
        )
        videoWriter.startRecording()
        isRecording = true
    }
    
    func addRoom(_ roomType: String) {
        guard let session = currentSession else { return }
        
        let room = TestDataFactory.makeRoom(type: roomType)
        currentSession?.rooms.append(room)
    }
    
    func checkItem(at index: Int, in roomIndex: Int = 0) {
        guard let session = currentSession,
              roomIndex < session.rooms.count else { return }
        
        let room = session.rooms[roomIndex]
        if index < room.checklist.count {
            currentSession?.rooms[roomIndex].checkedItemIds.insert(room.checklist[index].id)
        }
    }
    
    func stopAndSave() -> URL? {
        isRecording = false
        let videoURL = videoWriter.stopRecording()
        currentSession?.videoURL = videoURL
        currentSession?.duration = videoWriter.recordingDuration
        return videoURL
    }
}