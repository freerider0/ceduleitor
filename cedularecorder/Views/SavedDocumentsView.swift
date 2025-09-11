import SwiftUI

struct SavedDocumentsView: View {
    @ObservedObject private var documentManager = DocumentManager.shared
    @State private var selectedDocument: DocumentManager.SavedDocument?
    @State private var showingDocumentPreview = false
    @State private var showingShareSheet = false
    @State private var shareURL: URL?
    
    var body: some View {
        NavigationView {
            VStack {
                if documentManager.savedDocuments.isEmpty {
                    emptyStateView
                } else {
                    documentsList
                }
            }
            .navigationTitle("Saved ID Documents")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                documentManager.loadSavedDocuments()
            }
            .navigationBarItems(trailing: 
                Group {
                    if !documentManager.savedDocuments.isEmpty {
                        Text("\(documentManager.getDocumentCount()) documents")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            )
        }
        .sheet(isPresented: $showingDocumentPreview) {
            if let document = selectedDocument,
               let image = documentManager.loadDocument(fileName: document.fileName) {
                DocumentDetailView(document: document, image: image)
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = shareURL {
                DocumentShareSheet(activityItems: [url])
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.image")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Documents Saved")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Captured ID documents will appear here")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var documentsList: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Storage info card
                storageInfoCard
                
                // Documents list
                ForEach(documentManager.getAllDocuments()) { document in
                    DocumentRow(
                        document: document,
                        onTap: {
                            selectedDocument = document
                            showingDocumentPreview = true
                        },
                        onShare: {
                            if let url = documentManager.shareDocument(document) {
                                shareURL = url
                                showingShareSheet = true
                            }
                        },
                        onDelete: {
                            documentManager.deleteDocument(document)
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    private var storageInfoCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Storage Used")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(documentManager.formatFileSize(documentManager.getTotalStorageUsed()))
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            Image(systemName: "externaldrive")
                .font(.title2)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct DocumentRow: View {
    let document: DocumentManager.SavedDocument
    let onTap: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void
    
    @State private var showingDeleteAlert = false
    @State private var thumbnailImage: UIImage?
    
    var body: some View {
        HStack {
            // Thumbnail with actual image
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                if let thumbnail = thumbnailImage {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: "doc.text.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .frame(width: 60, height: 60)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(document.documentType)
                    .font(.headline)
                
                Text(formattedDate(document.dateCaptured))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(DocumentManager.shared.formatFileSize(document.fileSize))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                
                Button(action: {
                    showingDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
        .onTapGesture {
            onTap()
        }
        .onAppear {
            loadThumbnail()
        }
        .alert("Delete Document", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete this document? This action cannot be undone.")
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func loadThumbnail() {
        DispatchQueue.global(qos: .background).async {
            if let fullImage = DocumentManager.shared.loadDocument(fileName: document.fileName) {
                // Create thumbnail
                let thumbnailSize = CGSize(width: 120, height: 120)
                UIGraphicsBeginImageContextWithOptions(thumbnailSize, false, 0.0)
                fullImage.draw(in: CGRect(origin: .zero, size: thumbnailSize))
                let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                
                DispatchQueue.main.async {
                    self.thumbnailImage = thumbnail
                }
            }
        }
    }
}

struct DocumentDetailView: View {
    let document: DocumentManager.SavedDocument
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle(document.documentType)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Close") {
                    dismiss()
                },
                trailing: Button(action: {
                    // Share using UIActivityViewController
                    if let url = DocumentManager.shared.shareDocument(document) {
                        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootVC = windowScene.windows.first?.rootViewController {
                            rootVC.present(activityVC, animated: true)
                        }
                    }
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
            )
        }
    }
}

struct DocumentShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct SavedDocumentsView_Previews: PreviewProvider {
    static var previews: some View {
        SavedDocumentsView()
    }
}