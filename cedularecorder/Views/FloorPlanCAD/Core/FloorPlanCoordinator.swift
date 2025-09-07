import Foundation
import UIKit

// MARK: - CAD Mode
/// Different interaction modes for the floor plan editor
enum CADMode: Equatable {
    case viewing           // Default: pan, zoom, select rooms
    case drawingRoom       // Creating new room by tapping corners
    case editingRoom(CADRoom) // Room selected for transform/edit
    case attachingMedia    // Adding media to selected room
    
    static func == (lhs: CADMode, rhs: CADMode) -> Bool {
        switch (lhs, rhs) {
        case (.viewing, .viewing),
             (.drawingRoom, .drawingRoom),
             (.attachingMedia, .attachingMedia):
            return true
        case (.editingRoom(let a), .editingRoom(let b)):
            return a.id == b.id
        default:
            return false
        }
    }
    
    /// Check if currently in any drawing/editing mode
    var isEditMode: Bool {
        switch self {
        case .viewing: return false
        default: return true
        }
    }
    
    /// Get mode description for UI
    var description: String {
        switch self {
        case .viewing: return "View Mode"
        case .drawingRoom: return "Draw Room"
        case .editingRoom(let room): return "Editing: \(room.name)"
        case .attachingMedia: return "Add Media"
        }
    }
}

// MARK: - Floor Plan Coordinator
/// Manages navigation and mode transitions for floor plan editor
class FloorPlanCoordinator {
    
    // MARK: - Properties
    weak var viewController: UIViewController?
    private(set) var currentMode: CADMode = .viewing
    var onModeChange: ((CADMode) -> Void)?
    
    // Room being drawn
    private var drawingCorners: [CGPoint] = []
    private var selectedRoom: CADRoom?
    
    // MARK: - Mode Management
    
    /// Switch to a new mode
    func setMode(_ mode: CADMode) {
        // Clean up previous mode
        switch currentMode {
        case .drawingRoom:
            drawingCorners.removeAll()
        case .editingRoom:
            selectedRoom = nil
        default:
            break
        }
        
        currentMode = mode
        onModeChange?(mode)
    }
    
    /// Enter room drawing mode
    func startDrawingRoom() {
        drawingCorners.removeAll()
        setMode(.drawingRoom)
    }
    
    /// Select a room for editing
    func selectRoom(_ room: CADRoom) {
        selectedRoom = room
        setMode(.editingRoom(room))
    }
    
    /// Exit any edit mode and return to viewing
    func exitEditMode() {
        setMode(.viewing)
    }
    
    // MARK: - Menu Actions
    
    /// Show main plus button menu
    func showMainMenu(from button: UIBarButtonItem) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        // Configure for iPad
        alert.popoverPresentationController?.barButtonItem = button
        
        // Add room options
        alert.addAction(UIAlertAction(title: "Draw Custom Room", style: .default) { _ in
            self.startDrawingRoom()
        })
        
        alert.addAction(UIAlertAction(title: "Add Preset Shape", style: .default) { _ in
            self.showPresetShapeMenu(from: button)
        })
        
        alert.addAction(UIAlertAction(title: "New Floor", style: .default) { _ in
            self.addNewFloor()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        viewController?.present(alert, animated: true)
    }
    
    /// Show preset shape selection menu
    func showPresetShapeMenu(from button: UIBarButtonItem) {
        let alert = UIAlertController(title: "Select Room Shape", message: nil, preferredStyle: .actionSheet)
        
        alert.popoverPresentationController?.barButtonItem = button
        
        for preset in RoomShapePreset.allCases where preset != .custom {
            alert.addAction(UIAlertAction(title: preset.rawValue, style: .default) { _ in
                self.addPresetRoom(preset)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        viewController?.present(alert, animated: true)
    }
    
    /// Show media attachment menu for current room
    func showMediaMenu(from button: UIBarButtonItem, for room: CADRoom) {
        let alert = UIAlertController(title: "Add to \(room.name)", message: nil, preferredStyle: .actionSheet)
        
        alert.popoverPresentationController?.barButtonItem = button
        
        alert.addAction(UIAlertAction(title: "📷 Add Photo", style: .default) { _ in
            self.addPhoto(to: room)
        })
        
        alert.addAction(UIAlertAction(title: "📹 Add Video", style: .default) { _ in
            self.addVideo(to: room)
        })
        
        alert.addAction(UIAlertAction(title: "📝 Add Note", style: .default) { _ in
            self.addNote(to: room)
        })
        
        alert.addAction(UIAlertAction(title: "🎙️ Add Voice Note", style: .default) { _ in
            self.addVoiceNote(to: room)
        })
        
        if currentMode == .drawingRoom {
            alert.addAction(UIAlertAction(title: "✅ Finish Room", style: .default) { _ in
                self.finishDrawingRoom()
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        viewController?.present(alert, animated: true)
    }
    
    // MARK: - Room Actions
    
    private func addPresetRoom(_ preset: RoomShapePreset) {
        // Implementation will be connected to view model
        print("Adding preset room: \(preset.rawValue)")
    }
    
    private func finishDrawingRoom() {
        // Implementation will be connected to view model
        setMode(.viewing)
    }
    
    private func addNewFloor() {
        // Implementation will be connected to view model
        print("Adding new floor")
    }
    
    // MARK: - Media Actions
    
    private func addPhoto(to room: CADRoom) {
        print("Adding photo to \(room.name)")
        // Will trigger photo picker
    }
    
    private func addVideo(to room: CADRoom) {
        print("Adding video to \(room.name)")
        // Will trigger video picker
    }
    
    private func addNote(to room: CADRoom) {
        print("Adding note to \(room.name)")
        // Will show note editor
    }
    
    private func addVoiceNote(to room: CADRoom) {
        print("Adding voice note to \(room.name)")
        // Will show voice recorder
    }
}