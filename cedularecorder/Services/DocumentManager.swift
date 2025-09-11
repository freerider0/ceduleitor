import Foundation
import UIKit

// MARK: - Document Manager
class DocumentManager: ObservableObject {
    static let shared = DocumentManager()
    
    @Published var savedDocuments: [SavedDocument] = []
    
    private let documentsDirectory: URL
    private let idDocumentsFolder = "IDDocuments"
    
    struct SavedDocument: Identifiable, Codable {
        let id = UUID()
        let fileName: String
        let dateCaptured: Date
        let fileSize: Int64
        var notes: String = ""
        var documentType: String = "ID Card"
    }
    
    init() {
        // Get the app's documents directory
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let baseDirectory = paths[0]
        
        // Create IDDocuments subfolder
        self.documentsDirectory = baseDirectory.appendingPathComponent(idDocumentsFolder)
        
        // Create directory if it doesn't exist
        createDirectoryIfNeeded()
        
        // Load existing documents
        loadSavedDocuments()
    }
    
    private func createDirectoryIfNeeded() {
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: documentsDirectory.path) {
            do {
                try fileManager.createDirectory(at: documentsDirectory, 
                                              withIntermediateDirectories: true, 
                                              attributes: nil)
                print("Created IDDocuments directory at: \(documentsDirectory.path)")
            } catch {
                print("Error creating IDDocuments directory: \(error)")
            }
        }
    }
    
    // MARK: - Save Document
    func saveIDDocument(_ image: UIImage) -> String? {
        print("📝 saveIDDocument called")
        
        // Generate unique filename with timestamp
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let fileName = "ID_\(timestamp).jpg"
        print("📝 Generated filename: \(fileName)")
        
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        print("📝 File URL: \(fileURL.path)")
        
        // Convert to JPEG with good quality
        print("🖼 Converting image to JPEG...")
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            print("❌ Failed to convert image to JPEG")
            return nil
        }
        print("🖼 JPEG data size: \(imageData.count) bytes")
        
        do {
            // Write image to file
            print("💾 Writing image to file...")
            try imageData.write(to: fileURL)
            print("💾 Image written successfully")
            
            // Get file size
            print("📊 Getting file attributes...")
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            print("📊 File size: \(fileSize) bytes")
            
            // Create document record
            let document = SavedDocument(
                fileName: fileName,
                dateCaptured: Date(),
                fileSize: fileSize
            )
            print("📄 Created document record")
            
            // Add to saved documents on main thread for UI updates
            print("🔄 Adding to saved documents list...")
            DispatchQueue.main.async { [weak self] in
                print("🔄 On main thread - appending document")
                self?.savedDocuments.append(document)
                print("🔄 Document appended, saving metadata...")
                self?.saveMetadata()
                print("🔄 Metadata saved")
            }
            
            print("✅ Saved ID document: \(fileName)")
            print("✅ File size: \(formatFileSize(fileSize))")
            print("✅ Location: \(fileURL.path)")
            
            return fileURL.path
            
        } catch {
            print("❌ Error saving ID document: \(error)")
            return nil
        }
    }
    
    // MARK: - Load Document
    func loadDocument(fileName: String) -> UIImage? {
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        guard let imageData = try? Data(contentsOf: fileURL),
              let image = UIImage(data: imageData) else {
            print("Failed to load document: \(fileName)")
            return nil
        }
        
        return image
    }
    
    // MARK: - Delete Document
    func deleteDocument(_ document: SavedDocument) {
        let fileURL = documentsDirectory.appendingPathComponent(document.fileName)
        
        do {
            try FileManager.default.removeItem(at: fileURL)
            savedDocuments.removeAll { $0.id == document.id }
            saveMetadata()
            print("Deleted document: \(document.fileName)")
        } catch {
            print("Error deleting document: \(error)")
        }
    }
    
    // MARK: - Metadata Management
    private func saveMetadata() {
        let metadataURL = documentsDirectory.appendingPathComponent("metadata.json")
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(savedDocuments)
            try data.write(to: metadataURL)
        } catch {
            print("Error saving metadata: \(error)")
        }
    }
    
    func loadSavedDocuments() {
        let metadataURL = documentsDirectory.appendingPathComponent("metadata.json")
        
        guard let data = try? Data(contentsOf: metadataURL) else {
            print("No existing metadata found")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            savedDocuments = try decoder.decode([SavedDocument].self, from: data)
            print("Loaded \(savedDocuments.count) saved documents")
        } catch {
            print("Error loading metadata: \(error)")
        }
    }
    
    // MARK: - Utility Functions
    func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    func getDocumentsDirectory() -> URL {
        return documentsDirectory
    }
    
    func getAllDocuments() -> [SavedDocument] {
        return savedDocuments.sorted { $0.dateCaptured > $1.dateCaptured }
    }
    
    // MARK: - Export Functions
    func exportDocument(_ document: SavedDocument, to url: URL) throws {
        let sourceURL = documentsDirectory.appendingPathComponent(document.fileName)
        try FileManager.default.copyItem(at: sourceURL, to: url)
    }
    
    func shareDocument(_ document: SavedDocument) -> URL? {
        let sourceURL = documentsDirectory.appendingPathComponent(document.fileName)
        
        // Create temporary URL for sharing
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempURL = tempDirectory.appendingPathComponent(document.fileName)
        
        do {
            // Remove if exists
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            
            // Copy to temp location
            try FileManager.default.copyItem(at: sourceURL, to: tempURL)
            return tempURL
        } catch {
            print("Error preparing document for sharing: \(error)")
            return nil
        }
    }
    
    // MARK: - Statistics
    func getTotalStorageUsed() -> Int64 {
        return savedDocuments.reduce(0) { $0 + $1.fileSize }
    }
    
    func getDocumentCount() -> Int {
        return savedDocuments.count
    }
}