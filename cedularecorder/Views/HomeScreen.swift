import SwiftUI

// ================================================================================
// MARK: - Home View
// ================================================================================

/// Initial screen with navigation options for testing
struct HomeScreen: View {
    @State private var showRoomCapture = false
    @State private var showListView = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // App title
                        VStack(spacing: 8) {
                            Image(systemName: "viewfinder.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text("Room Recorder")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Text("AR Room Capture & Measurement")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 20)
                        
                        // Navigation buttons
                        VStack(spacing: 20) {
                        // ID Document Capture button
                        NavigationLink(destination: ModernCameraWithOverlay()) {
                            HStack {
                                Image(systemName: "doc.text.viewfinder")
                                    .font(.title2)
                                Text("ID Document Scanner")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.indigo)
                            )
                            .foregroundColor(.white)
                        }
                        
                        // Room Capture button
                        NavigationLink(destination: RoomScannerScreen(), isActive: $showRoomCapture) {
                            HStack {
                                Image(systemName: "camera.viewfinder")
                                    .font(.title2)
                                Text("Room Capture")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.blue)
                            )
                            .foregroundColor(.white)
                        }
                        
                        // Saved Documents button
                        NavigationLink(destination: SavedDocumentsView()) {
                            HStack {
                                Image(systemName: "folder.fill.badge.person.crop")
                                    .font(.title2)
                                Text("Saved ID Documents")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.purple)
                            )
                            .foregroundColor(.white)
                        }
                        
                        // List View button (placeholder for now)
                        NavigationLink(destination: SavedRoomsListView(), isActive: $showListView) {
                            HStack {
                                Image(systemName: "list.bullet.rectangle")
                                    .font(.title2)
                                Text("Saved Rooms")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.green)
                            )
                            .foregroundColor(.white)
                        }
                        
                        // 2D Floor Plan button
                        NavigationLink(destination: FloorPlan2DScreen()) {
                            HStack {
                                Image(systemName: "square.grid.3x3")
                                    .font(.title2)
                                Text("2D Floor Plan")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.orange)
                            )
                            .foregroundColor(.white)
                        }
                        
                        // Wall Detection button
                        NavigationLink(destination: WallDetectionScreen()) {
                            HStack {
                                Image(systemName: "square.3.layers.3d")
                                    .font(.title2)
                                Text("Wall Detection")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.teal)
                            )
                            .foregroundColor(.white)
                        }

                        // AR2 Wall Detection button
                        NavigationLink(destination: AR2WallDetectionView()) {
                            HStack {
                                Image(systemName: "cube.transparent")
                                    .font(.title2)
                                Text("AR2")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.mint)
                            )
                            .foregroundColor(.white)
                        }
                        
                        // Settings button (placeholder)
                        Button(action: {
                            print("Settings tapped")
                        }) {
                            HStack {
                                Image(systemName: "gearshape.fill")
                                    .font(.title2)
                                Text("Settings")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.gray, lineWidth: 2)
                            )
                            .foregroundColor(.gray)
                        }
                        
                        // PlaneGCS Test button
                        NavigationLink(destination: PlaneGCSTestScreen()) {
                            HStack {
                                Image(systemName: "gearshape.2")
                                    .font(.title2)
                                Text("PlaneGCS Test")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.green)
                            )
                            .foregroundColor(.white)
                        }
                        }
                        .padding(.horizontal, 30)
                        
                        // Version info
                        Text("Version 1.0.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 20)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// ================================================================================
// MARK: - Saved Rooms List View (Placeholder)
// ================================================================================

struct SavedRoomsListView: View {
    @Environment(\.presentationMode) var presentationMode
    
    // Sample data for testing
    let sampleRooms = [
        ("Living Room", "25.4 m²", "6 corners", Date()),
        ("Bedroom", "18.2 m²", "4 corners", Date(timeIntervalSinceNow: -86400)),
        ("Kitchen", "12.8 m²", "5 corners", Date(timeIntervalSinceNow: -172800))
    ]
    
    var body: some View {
        List {
            ForEach(sampleRooms, id: \.0) { room in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(room.0)
                                .font(.headline)
                            HStack(spacing: 12) {
                                Label(room.1, systemImage: "square")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Label(room.2, systemImage: "scope")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text(room.3, style: .date)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(room.3, style: .time)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("Saved Rooms")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarItems(
            trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            }
        )
    }
}

// ================================================================================
// MARK: - Preview
// ================================================================================

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeScreen()
    }
}