import Foundation

struct ChecklistItem: Identifiable, Codable {
    let id: String
    let text: String
    let description: String
    var isChecked: Bool = false
    var checkedAt: TimeInterval?
    
    var displayText: String {
        if let time = checkedAt {
            let formatted = formatTime(time)
            return "\(text) ✅ @ \(formatted)"
        }
        return text
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

struct ChecklistItemConfig: Codable {
    let id: String
    let text: String
    let description: String
}