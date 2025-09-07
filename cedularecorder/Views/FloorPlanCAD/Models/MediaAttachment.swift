import Foundation
import UIKit

// MARK: - Media Type
/// Types of media that can be attached to a room
enum MediaType: String, Codable {
    case photo = "Photo"
    case video = "Video"
    case note = "Note"
    case voiceNote = "Voice Note"
    
    /// Icon for each media type
    var icon: String {
        switch self {
        case .photo: return "photo"
        case .video: return "video"
        case .note: return "note.text"
        case .voiceNote: return "mic.circle"
        }
    }
    
    /// Color for media type indicator
    var color: UIColor {
        switch self {
        case .photo: return .systemBlue
        case .video: return .systemPurple
        case .note: return .systemYellow
        case .voiceNote: return .systemRed
        }
    }
}

// MARK: - Media Attachment
/// Represents a media item attached to a specific location in a room
struct MediaAttachment: Identifiable, Codable {
    let id: UUID
    var type: MediaType
    var title: String
    var position: CGPoint  // Position within the room (local coordinates)
    var thumbnailData: Data?  // For photos/videos
    var content: String?  // For notes
    var audioURL: URL?  // For voice notes
    var videoURL: URL?  // For videos
    var createdAt: Date
    
    /// Initialize a new media attachment
    init(type: MediaType,
         title: String = "",
         position: CGPoint = .zero) {
        self.id = UUID()
        self.type = type
        self.title = title.isEmpty ? type.rawValue : title
        self.position = position
        self.createdAt = Date()
    }
    
    /// Get thumbnail image if available
    var thumbnail: UIImage? {
        guard let data = thumbnailData else { return nil }
        return UIImage(data: data)
    }
    
    /// Set thumbnail from UIImage
    mutating func setThumbnail(_ image: UIImage) {
        thumbnailData = image.jpegData(compressionQuality: 0.7)
    }
}