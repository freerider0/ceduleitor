import SwiftUI
import AVFoundation
import UIKit

struct SimpleCameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: SimpleCameraView
        
        init(_ parent: SimpleCameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct IDDocumentCaptureSimpleView: View {
    @State private var capturedImage: UIImage?
    @State private var showCamera = false
    @State private var showImagePreview = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let image = capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 400)
                        .cornerRadius(10)
                        .padding()
                    
                    HStack(spacing: 30) {
                        Button(action: {
                            capturedImage = nil
                            showCamera = true
                        }) {
                            Label("Retake", systemImage: "arrow.counterclockwise")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(width: 140)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange))
                        }
                        
                        Button(action: {
                            if let image = capturedImage {
                                saveImage(image)
                            }
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Label("Save", systemImage: "checkmark")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(width: 140)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.green))
                        }
                    }
                } else {
                    VStack(spacing: 30) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("Capture ID Document")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Position your ID document clearly in the camera frame")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: {
                            showCamera = true
                        }) {
                            HStack {
                                Image(systemName: "camera.fill")
                                Text("Open Camera")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(width: 200)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.blue))
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("ID Document Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .sheet(isPresented: $showCamera) {
            SimpleCameraView(image: $capturedImage)
        }
    }
    
    private func saveImage(_ image: UIImage) {
        // Save to photo library
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        
        // Also save using DocumentStorageService
        if let _ = DocumentStorageService.shared.saveDocument(
            image,
            type: .nationalID,
            qualityScore: 1.0,
            hasPerspectiveCorrection: false
        ) {
            print("Document saved successfully")
        }
    }
}

struct IDDocumentCaptureSimpleView_Previews: PreviewProvider {
    static var previews: some View {
        IDDocumentCaptureSimpleView()
    }
}