import SwiftUI
import AVKit

struct VideoReplayView: View {
    let session: InspectionSession
    @ObservedObject var logger: InspectionLogger  // Passed from parent
    @State private var player: AVPlayer?
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isPlaying = false
    @State private var isDragging = false
    
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 0) {
            // Video Player or Error Message
            if let videoURL = session.videoURL, FileManager.default.fileExists(atPath: videoURL.path) {
                VideoPlayer(player: player)
                    .onAppear {
                        setupPlayer(url: videoURL)
                    }
                    .frame(height: UIScreen.main.bounds.height * 0.35)
                
                // Video Controls
                VStack(spacing: 12) {
                    // Time slider
                    HStack(spacing: 12) {
                        Text(formatTime(currentTime))
                            .font(.caption)
                            .monospacedDigit()
                            .frame(width: 45)
                        
                        Slider(value: $currentTime, in: 0...max(duration, 1)) { editing in
                            isDragging = editing
                            if !editing {
                                seekToTime(currentTime)
                            }
                        }
                        .accentColor(.blue)
                        
                        Text(formatTime(duration))
                            .font(.caption)
                            .monospacedDigit()
                            .frame(width: 45)
                    }
                    .padding(.horizontal)
                    
                    // Play/Pause and skip buttons
                    HStack(spacing: 40) {
                        // Skip backward 10s
                        Button(action: { skipBackward() }) {
                            Image(systemName: "gobackward.10")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        
                        // Play/Pause
                        Button(action: { togglePlayPause() }) {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                        }
                        
                        // Skip forward 10s
                        Button(action: { skipForward() }) {
                            Image(systemName: "goforward.10")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.bottom, 8)
                }
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                .onReceive(timer) { _ in
                    if !isDragging {
                        updateCurrentTime()
                    }
                }
            } else {
                // Show error when video is not available
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    Text("Video not available")
                        .font(.headline)
                    Text("The video file could not be found")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(height: UIScreen.main.bounds.height * 0.35)
                .frame(maxWidth: .infinity)
                .background(Color.black)
            }
            
            // Inspection Points List
            List {
                Section(header: Text("Inspection Points")) {
                    ForEach(logger.getInspectionPoints(for: session), id: \.timestamp) { point in
                        Button(action: {
                            seekToTimestamp(point.seconds)
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(point.room)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text(point.item)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                }
                                
                                Spacer()
                                
                                HStack(spacing: 4) {
                                    Text(point.timestamp)
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    Image(systemName: "play.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                Section(header: Text("Summary")) {
                    HStack {
                        Text("Total Rooms")
                        Spacer()
                        Text("\(session.summary.totalRooms)")
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("Checks Completed")
                        Spacer()
                        Text("\(session.summary.completedChecks)/\(session.summary.totalChecks)")
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("Inspection Rate")
                        Spacer()
                        Text("\(Int(session.summary.inspectionRate))%")
                            .fontWeight(.semibold)
                            .foregroundColor(session.summary.inspectionRate >= 90 ? .green : .orange)
                    }
                }
            }
        }
        .navigationTitle(session.address)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    exportSession()
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
    }
    
    private func setupPlayer(url: URL) {
        // Check if video file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("Video file not found at: \(url.path)")
            return
        }
        
        player = AVPlayer(url: url)
        
        Task {
            if let item = player?.currentItem {
                do {
                    let duration = try await item.asset.load(.duration)
                    await MainActor.run {
                        self.duration = CMTimeGetSeconds(duration)
                    }
                } catch {
                    print("Failed to load duration: \(error)")
                }
            }
        }
    }
    
    private func updateCurrentTime() {
        guard let player = player else { return }
        currentTime = CMTimeGetSeconds(player.currentTime())
        isPlaying = player.rate > 0
    }
    
    private func seekToTime(_ time: Double) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 1))
    }
    
    private func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
    
    private func skipForward() {
        let newTime = min(currentTime + 10, duration)
        currentTime = newTime
        seekToTime(newTime)
    }
    
    private func skipBackward() {
        let newTime = max(currentTime - 10, 0)
        currentTime = newTime
        seekToTime(newTime)
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    private func seekToTimestamp(_ seconds: TimeInterval) {
        currentTime = seconds
        seekToTime(seconds)
        player?.play()
        isPlaying = true
    }
    
    private func exportSession() {
        // Export JSON log
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(session)
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileName = "inspection_\(session.id.uuidString).json"
            let url = documentsPath.appendingPathComponent(fileName)
            try data.write(to: url)
            
            exportURL = url
            showShareSheet = true
        } catch {
            print("Error exporting session: \(error)")
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}