import XCTest
@testable import cedularecorder

// Simplified tests that work with the actual data models
class SimplifiedFeatureTests: XCTestCase {
    
    // MARK: - Room Progress Tests (What users actually see)
    
    func testUserSeesCorrectRoomProgress() {
        // Given: User has a room with 5 items
        let checklist = (0..<5).map { i in
            ChecklistItem(id: "item_\(i)", text: "Item \(i)", description: "")
        }
        
        let room = Room(
            type: "living",
            displayName: "Living Room",
            number: 1,
            addedAt: Date().timeIntervalSince1970,
            checklist: checklist,
            checkedItemIds: Set(["item_0", "item_1", "item_2"]) // 3 of 5 checked
        )
        
        // Then: User sees "3/5" progress
        XCTAssertEqual(room.progressText, "3/5")
        XCTAssertFalse(room.isComplete)
        XCTAssertEqual(room.statusEmoji, "🟡")
    }
    
    func testUserSeesCompletedRoom() {
        // Given: User completes all items
        let checklist = (0..<3).map { i in
            ChecklistItem(id: "item_\(i)", text: "Item \(i)", description: "")
        }
        
        let room = Room(
            type: "kitchen",
            displayName: "Kitchen",
            number: 1,
            addedAt: Date().timeIntervalSince1970,
            checklist: checklist,
            checkedItemIds: Set(["item_0", "item_1", "item_2"]) // All checked
        )
        
        // Then: Room shows as complete
        XCTAssertTrue(room.isComplete)
        XCTAssertEqual(room.statusEmoji, "✅")
    }
    
    // MARK: - Session Creation (Starting an inspection)
    
    func testUserCanStartInspection() {
        // Given: User enters address
        let session = InspectionSession(
            date: Date(),
            address: "123 Main St"
        )
        
        // Then: Session is created
        XCTAssertNotNil(session.id)
        XCTAssertEqual(session.address, "123 Main St")
        XCTAssertEqual(session.rooms.count, 0)
        // Can't test uploadStatus without Equatable conformance
    }
    
    // MARK: - Adding Rooms (Core workflow)
    
    func testUserCanAddMultipleRooms() {
        // Given: User starts inspection
        var session = InspectionSession(
            date: Date(),
            address: "456 Test Ave"
        )
        
        // When: User adds rooms
        let room1 = Room(
            type: "living",
            displayName: "Living Room",
            number: 1,
            addedAt: Date().timeIntervalSince1970,
            checklist: []
        )
        
        let room2 = Room(
            type: "kitchen",
            displayName: "Kitchen",
            number: 1,
            addedAt: Date().timeIntervalSince1970 + 60,
            checklist: []
        )
        
        session.rooms.append(room1)
        session.rooms.append(room2)
        
        // Then: Both rooms are in session
        XCTAssertEqual(session.rooms.count, 2)
        XCTAssertEqual(session.rooms[0].displayName, "Living Room")
        XCTAssertEqual(session.rooms[1].displayName, "Kitchen")
    }
    
    // MARK: - Checklist Display (What user sees during recording)
    
    func testChecklistItemDisplay() {
        // Given: An unchecked item
        var item = ChecklistItem(
            id: "1",
            text: "Check windows",
            description: "Verify they open and close"
        )
        
        // Initially shows just text
        XCTAssertEqual(item.displayText, "Check windows")
        
        // When: User checks it at 30 seconds
        item.isChecked = true
        item.checkedAt = 30.5
        
        // Then: Shows with checkmark and time
        XCTAssertTrue(item.displayText.contains("✅"))
        XCTAssertTrue(item.displayText.contains("00:30"))
    }
    
    // MARK: - Video Recording State
    
    func testVideoRecordingMetadata() {
        // Given: A completed recording session
        var session = InspectionSession(
            date: Date(),
            address: "789 Record St"
        )
        
        // When: Recording completes with actual file
        let tempDir = FileManager.default.temporaryDirectory
        let videoURL = tempDir.appendingPathComponent("test_video_\(UUID().uuidString).mp4")
        
        // Create a dummy video file with some content
        let dummyData = Data(repeating: 0xFF, count: 1024 * 1024) // 1MB of data
        try? dummyData.write(to: videoURL)
        
        session.videoURL = videoURL
        session.duration = 180.0 // 3 minutes
        
        // Then: Session has video info
        XCTAssertNotNil(session.videoURL)
        XCTAssertEqual(session.duration, 180.0)
        XCTAssertGreaterThan(session.videoSizeMB, 0)
        XCTAssertEqual(session.videoSizeMB, 1.0, accuracy: 0.1) // Should be ~1MB
        
        // Cleanup
        try? FileManager.default.removeItem(at: videoURL)
    }
    
    // MARK: - Measurement Data
    
    func testMeasurementStorage() {
        // Given: User takes measurements
        var room = Room(
            type: "bedroom",
            displayName: "Bedroom",
            number: 1,
            addedAt: Date().timeIntervalSince1970,
            checklist: []
        )
        
        // When: Add measurement data
        let measurement = ARMeasurementData(
            type: "distance",
            label: "Wall length: 3.5m",
            timestamp: 45.0
        )
        
        room.arMeasurements.append(measurement)
        
        // Then: Measurement is stored with room
        XCTAssertEqual(room.arMeasurements.count, 1)
        XCTAssertEqual(room.arMeasurements[0].label, "Wall length: 3.5m")
        XCTAssertEqual(room.arMeasurements[0].timestamp, 45.0)
    }
    
    // MARK: - Session Summary (What user sees in list)
    
    func testSessionSummaryDisplay() {
        // Given: A session with mixed completion
        var session = InspectionSession(
            date: Date(),
            address: "Summary Test"
        )
        
        // Add rooms with different completion
        for i in 0..<3 {
            let checklist = (0..<5).map { j in
                ChecklistItem(id: "item_\(j)", text: "Item \(j)", description: "")
            }
            
            var checkedIds = Set<String>()
            if i == 0 {
                // First room: all checked
                checkedIds = Set(checklist.map { $0.id })
            } else if i == 1 {
                // Second room: partially checked
                checkedIds = Set(["item_0", "item_1"])
            }
            // Third room: none checked
            
            let room = Room(
                type: "room",
                displayName: "Room \(i+1)",
                number: i+1,
                addedAt: Date().timeIntervalSince1970,
                checklist: checklist,
                checkedItemIds: checkedIds
            )
            session.rooms.append(room)
        }
        
        // Then: Summary reflects overall state
        let summary = session.summary
        XCTAssertEqual(summary.totalRooms, 3)
        // Other summary properties depend on InspectionSummary structure
        XCTAssertGreaterThan(summary.inspectionRate, 0) // At least some progress
    }
    
    // MARK: - Data Persistence (Critical for not losing work)
    
    func testSessionCanBeSerialized() {
        // Given: A session with data
        let session = InspectionSession(
            date: Date(),
            address: "Persistence Test",
            videoURL: URL(string: "file://test.mp4"),
            duration: 120
        )
        
        // When: Encoding and decoding
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        do {
            let data = try encoder.encode(session)
            let decoded = try decoder.decode(InspectionSession.self, from: data)
            
            // Then: Critical data preserved
            XCTAssertEqual(decoded.id, session.id)
            XCTAssertEqual(decoded.address, session.address)
            XCTAssertEqual(decoded.videoURL, session.videoURL)
            XCTAssertEqual(decoded.duration, session.duration)
        } catch {
            XCTFail("Serialization failed: \(error)")
        }
    }
}