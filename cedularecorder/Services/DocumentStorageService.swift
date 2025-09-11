import Foundation
import UIKit
import CoreData

struct CapturedDocument {
    let id: UUID
    let image: UIImage
    let timestamp: Date
    let documentType: DocumentType
    let metadata: DocumentMetadata
    
    enum DocumentType: String, CaseIterable {
        case nationalID = "National ID"
        case passport = "Passport"
        case driverLicense = "Driver's License"
        case other = "Other"
    }
    
    struct DocumentMetadata {
        let qualityScore: Double
        let hasPerspectiveCorrection: Bool
        let dimensions: CGSize
        let fileSize: Int64?
    }
}

class DocumentStorageService: ObservableObject {
    static let shared = DocumentStorageService()
    
    @Published var savedDocuments: [CapturedDocument] = []
    
    private let documentsDirectory: URL
    private let thumbnailsDirectory: URL
    
    init() {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let baseDirectory = paths[0].appendingPathComponent("CapturedDocuments")
        
        self.documentsDirectory = baseDirectory.appendingPathComponent("FullSize")
        self.thumbnailsDirectory = baseDirectory.appendingPathComponent("Thumbnails")
        
        createDirectoriesIfNeeded()
        loadSavedDocuments()
    }
    
    private func createDirectoriesIfNeeded() {
        let fileManager = FileManager.default
        
        do {
            if !fileManager.fileExists(atPath: documentsDirectory.path) {
                try fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
            }
            
            if !fileManager.fileExists(atPath: thumbnailsDirectory.path) {
                try fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
            }
        } catch {
            print("Error creating directories: \(error)")
        }
    }
    
    func saveDocument(_ image: UIImage, type: CapturedDocument.DocumentType, qualityScore: Double, hasPerspectiveCorrection: Bool) -> CapturedDocument? {
        let documentID = UUID()
        let timestamp = Date()
        
        let fullSizeURL = documentsDirectory.appendingPathComponent("\(documentID.uuidString).jpg")
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent("\(documentID.uuidString)_thumb.jpg")
        
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            print("Failed to convert image to JPEG data")
            return nil
        }
        
        guard let thumbnailImage = generateThumbnail(from: image),
              let thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.7) else {
            print("Failed to generate thumbnail")
            return nil
        }
        
        do {
            try imageData.write(to: fullSizeURL)
            try thumbnailData.write(to: thumbnailURL)
            
            let metadata = CapturedDocument.DocumentMetadata(
                qualityScore: qualityScore,
                hasPerspectiveCorrection: hasPerspectiveCorrection,
                dimensions: image.size,
                fileSize: Int64(imageData.count)
            )
            
            let document = CapturedDocument(
                id: documentID,
                image: image,
                timestamp: timestamp,
                documentType: type,
                metadata: metadata
            )
            
            savedDocuments.append(document)
            saveDocumentMetadata()
            
            return document
        } catch {
            print("Error saving document: \(error)")
            return nil
        }
    }
    
    func deleteDocument(_ document: CapturedDocument) {
        let fullSizeURL = documentsDirectory.appendingPathComponent("\(document.id.uuidString).jpg")
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent("\(document.id.uuidString)_thumb.jpg")
        
        do {
            try FileManager.default.removeItem(at: fullSizeURL)
            try FileManager.default.removeItem(at: thumbnailURL)
            
            savedDocuments.removeAll { $0.id == document.id }
            saveDocumentMetadata()
        } catch {
            print("Error deleting document: \(error)")
        }
    }
    
    func loadDocument(withID id: UUID) -> UIImage? {
        let fullSizeURL = documentsDirectory.appendingPathComponent("\(id.uuidString).jpg")
        
        guard let imageData = try? Data(contentsOf: fullSizeURL),
              let image = UIImage(data: imageData) else {
            return nil
        }
        
        return image
    }
    
    func loadThumbnail(withID id: UUID) -> UIImage? {
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent("\(id.uuidString)_thumb.jpg")
        
        guard let imageData = try? Data(contentsOf: thumbnailURL),
              let image = UIImage(data: imageData) else {
            return nil
        }
        
        return image
    }
    
    private func generateThumbnail(from image: UIImage) -> UIImage? {
        let targetSize = CGSize(width: 200, height: 200)
        
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        let aspectWidth = targetSize.width / image.size.width
        let aspectHeight = targetSize.height / image.size.height
        let aspectRatio = min(aspectWidth, aspectHeight)
        
        let scaledSize = CGSize(
            width: image.size.width * aspectRatio,
            height: image.size.height * aspectRatio
        )
        
        let drawRect = CGRect(
            x: (targetSize.width - scaledSize.width) / 2,
            y: (targetSize.height - scaledSize.height) / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )
        
        image.draw(in: drawRect)
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    private func saveDocumentMetadata() {
        let metadataURL = documentsDirectory.appendingPathComponent("metadata.json")
        
        let metadata = savedDocuments.map { document in
            [
                "id": document.id.uuidString,
                "timestamp": ISO8601DateFormatter().string(from: document.timestamp),
                "documentType": document.documentType.rawValue,
                "qualityScore": document.metadata.qualityScore,
                "hasPerspectiveCorrection": document.metadata.hasPerspectiveCorrection,
                "width": document.metadata.dimensions.width,
                "height": document.metadata.dimensions.height,
                "fileSize": document.metadata.fileSize ?? 0
            ] as [String : Any]
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
            try jsonData.write(to: metadataURL)
        } catch {
            print("Error saving metadata: \(error)")
        }
    }
    
    private func loadSavedDocuments() {
        let metadataURL = documentsDirectory.appendingPathComponent("metadata.json")
        
        guard let jsonData = try? Data(contentsOf: metadataURL),
              let metadata = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            return
        }
        
        savedDocuments = metadata.compactMap { item in
            guard let idString = item["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let timestampString = item["timestamp"] as? String,
                  let timestamp = ISO8601DateFormatter().date(from: timestampString),
                  let documentTypeString = item["documentType"] as? String,
                  let documentType = CapturedDocument.DocumentType(rawValue: documentTypeString),
                  let qualityScore = item["qualityScore"] as? Double,
                  let hasPerspectiveCorrection = item["hasPerspectiveCorrection"] as? Bool,
                  let width = item["width"] as? Double,
                  let height = item["height"] as? Double,
                  let image = loadDocument(withID: id) else {
                return nil
            }
            
            let fileSize = item["fileSize"] as? Int64
            
            let metadata = CapturedDocument.DocumentMetadata(
                qualityScore: qualityScore,
                hasPerspectiveCorrection: hasPerspectiveCorrection,
                dimensions: CGSize(width: width, height: height),
                fileSize: fileSize
            )
            
            return CapturedDocument(
                id: id,
                image: image,
                timestamp: timestamp,
                documentType: documentType,
                metadata: metadata
            )
        }
    }
    
    func exportDocument(_ document: CapturedDocument, to url: URL) throws {
        guard let imageData = document.image.jpegData(compressionQuality: 1.0) else {
            throw NSError(domain: "DocumentStorageService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        try imageData.write(to: url)
    }
    
    func shareDocument(_ document: CapturedDocument) -> [Any] {
        var items: [Any] = []
        
        if let imageData = document.image.jpegData(compressionQuality: 1.0) {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(document.id.uuidString).jpg")
            try? imageData.write(to: tempURL)
            items.append(tempURL)
        }
        
        let description = """
        Document Type: \(document.documentType.rawValue)
        Captured: \(DateFormatter.localizedString(from: document.timestamp, dateStyle: .medium, timeStyle: .short))
        Quality Score: \(String(format: "%.0f%%", document.metadata.qualityScore * 100))
        """
        
        items.append(description)
        
        return items
    }
}