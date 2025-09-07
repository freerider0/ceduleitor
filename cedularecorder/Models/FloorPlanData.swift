import Foundation
import CoreGraphics
import simd

// MARK: - Floor Plan Data Model

struct FloorPlanData: Codable, Identifiable {
    let id: UUID
    var name: String
    var corners: [FloorPlanPoint]
    var rooms: [FloorPlanRoom]
    var createdAt: Date
    var modifiedAt: Date
    var metadata: FloorPlanMetadata
    
    init(
        id: UUID = UUID(),
        name: String = "New Floor Plan",
        corners: [FloorPlanPoint] = [],
        rooms: [FloorPlanRoom] = [],
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        metadata: FloorPlanMetadata = FloorPlanMetadata()
    ) {
        self.id = id
        self.name = name
        self.corners = corners
        self.rooms = rooms
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.metadata = metadata
    }
    
    // Convert from AR capture data
    static func fromARCapture(corners: [simd_float3], roomName: String? = nil) -> FloorPlanData {
        let floorPlanPoints = corners.map { corner in
            FloorPlanPoint(x: Double(corner.x), y: Double(corner.z)) // Use X and Z for 2D floor plan
        }
        
        let room = FloorPlanRoom(
            id: UUID(),
            name: roomName ?? "Room 1",
            cornerIndices: Array(0..<floorPlanPoints.count),
            roomType: .general
        )
        
        return FloorPlanData(
            name: roomName ?? "AR Captured Room",
            corners: floorPlanPoints,
            rooms: [room],
            metadata: FloorPlanMetadata(source: .arCapture)
        )
    }
}

// MARK: - Floor Plan Point

struct FloorPlanPoint: Codable {
    var x: Double
    var y: Double
    
    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
    
    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
    
    init(from cgPoint: CGPoint) {
        self.x = Double(cgPoint.x)
        self.y = Double(cgPoint.y)
    }
}

// MARK: - Floor Plan Room

struct FloorPlanRoom: Codable, Identifiable {
    let id: UUID
    var name: String
    var cornerIndices: [Int] // Indices into the corners array
    var roomType: RoomType
    var area: Double? // Cached area in square meters
    var perimeter: Double? // Cached perimeter in meters
    
    enum RoomType: String, Codable, CaseIterable {
        case general = "General"
        case bedroom = "Bedroom"
        case bathroom = "Bathroom"
        case kitchen = "Kitchen"
        case livingRoom = "Living Room"
        case diningRoom = "Dining Room"
        case office = "Office"
        case hallway = "Hallway"
        case closet = "Closet"
        case garage = "Garage"
        
        var color: String {
            switch self {
            case .general: return "#4A90E2"
            case .bedroom: return "#7B68EE"
            case .bathroom: return "#48D1CC"
            case .kitchen: return "#FFB347"
            case .livingRoom: return "#90EE90"
            case .diningRoom: return "#DDA0DD"
            case .office: return "#F0E68C"
            case .hallway: return "#D3D3D3"
            case .closet: return "#BC8F8F"
            case .garage: return "#708090"
            }
        }
    }
}

// MARK: - Floor Plan Metadata

struct FloorPlanMetadata: Codable {
    var scale: Double // meters per unit
    var unit: MeasurementUnitType
    var source: DataSource
    var location: LocationData?
    var notes: String?
    
    enum MeasurementUnitType: String, Codable {
        case meters = "m"
        case feet = "ft"
    }
    
    enum DataSource: String, Codable {
        case manual = "Manual"
        case arCapture = "AR Capture"
        case imported = "Imported"
    }
    
    init(
        scale: Double = 0.01,
        unit: MeasurementUnitType = .meters,
        source: DataSource = .manual,
        location: LocationData? = nil,
        notes: String? = nil
    ) {
        self.scale = scale
        self.unit = unit
        self.source = source
        self.location = location
        self.notes = notes
    }
}

// MARK: - Location Data

struct LocationData: Codable {
    var latitude: Double
    var longitude: Double
    var address: String?
    var altitude: Double?
}

// MARK: - Floor Plan Collection (for multiple floors)

struct FloorPlanCollection: Codable, Identifiable {
    let id: UUID
    var name: String // Building name
    var floors: [Floor]
    var createdAt: Date
    var modifiedAt: Date
    
    struct Floor: Codable, Identifiable {
        let id: UUID
        var level: Int // Floor number (0 = ground, 1 = first floor, etc.)
        var name: String // Custom name like "Ground Floor", "Basement"
        var floorPlan: FloorPlanData
    }
    
    init(
        id: UUID = UUID(),
        name: String = "New Building",
        floors: [Floor] = [],
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.floors = floors
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

// MARK: - Export Formats

enum ExportFormat {
    case png
    case pdf
    case svg
    case dxf
    case json
    
    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .pdf: return "pdf"
        case .svg: return "svg"
        case .dxf: return "dxf"
        case .json: return "json"
        }
    }
}