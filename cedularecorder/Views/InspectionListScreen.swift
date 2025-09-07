import SwiftUI

struct InspectionListScreen: View {
    @StateObject private var logger = InspectionLogger()
    @State private var showingRecorder = false
    
    var body: some View {
        List {
            if logger.sessions.isEmpty {
                // Empty state
                VStack(spacing: 20) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("No Inspections Yet")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Text("Tap the + button to start recording")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
                .listRowBackground(Color.clear)
            } else {
                ForEach(logger.sessions) { session in
                    NavigationLink(destination: VideoReplayScreen(session: session, logger: logger)) {
                        sessionRow(session)
                    }
                }
                .onDelete(perform: deleteSession)
            }
        }
        .navigationTitle("Inspections")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // Room capture button
                    NavigationLink(destination: RoomScannerScreen()) {
                        Image(systemName: "square.on.square.dashed")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                    
                    // Plus button to start new recording
                    NavigationLink(destination: ARRecordingScreen()) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .onAppear {
            logger.loadSessions()
        }
        .refreshable {
            // Pull to refresh
            logger.loadSessions()
        }
    }
    
    private func sessionRow(_ session: InspectionSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Address with icon
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
                
                Text(session.address)
                    .font(.headline)
                    .lineLimit(1)
            }
            
            // Date and time info
            HStack {
                Label {
                    Text(session.date, style: .date)
                        .font(.caption)
                } icon: {
                    Image(systemName: "calendar")
                        .font(.caption)
                }
                
                Spacer()
                
                Label {
                    Text(formatDuration(session.duration))
                        .font(.caption)
                } icon: {
                    Image(systemName: "clock")
                        .font(.caption)
                }
                
                Spacer()
                
                Label {
                    Text("\(session.videoSizeMB, specifier: "%.1f") MB")
                        .font(.caption)
                } icon: {
                    Image(systemName: "doc.circle")
                        .font(.caption)
                }
            }
            .foregroundColor(.secondary)
            
            // Stats bar
            HStack {
                // Rooms count
                Label {
                    Text("\(session.rooms.count)")
                        .fontWeight(.semibold)
                } icon: {
                    Image(systemName: "door.left.hand.open")
                }
                .font(.caption)
                .foregroundColor(.blue)
                
                // GPS indicator
                if session.startLatitude != nil && session.startLongitude != nil {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                // Decree used
                if let decree = session.decreeUsed {
                    Text(decree)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Inspection rate badge
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(session.summary.inspectionRate >= 90 ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                    
                    HStack(spacing: 4) {
                        Image(systemName: session.summary.inspectionRate >= 90 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .font(.caption)
                        
                        Text("\(Int(session.summary.inspectionRate))%")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(session.summary.inspectionRate >= 90 ? .green : .orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .fixedSize()
                
                // Upload status
                uploadStatusIcon(session.uploadStatus)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func uploadStatusIcon(_ status: UploadStatus) -> some View {
        Group {
            switch status {
            case .uploaded:
                Image(systemName: "checkmark.icloud.fill")
                    .foregroundColor(.green)
            case .uploading:
                Image(systemName: "icloud.and.arrow.up")
                    .foregroundColor(.blue)
            case .failed:
                Image(systemName: "exclamationmark.icloud.fill")
                    .foregroundColor(.red)
            case .notUploaded:
                Image(systemName: "icloud.slash")
                    .foregroundColor(.gray)
            }
        }
        .font(.caption)
    }
    
    private func deleteSession(at offsets: IndexSet) {
        for index in offsets {
            logger.deleteSession(at: index)
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}