import SwiftUI
import CoreBluetooth

struct MinimalBTTest: View {
    @StateObject private var btvm = MinimalBTViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text("Minimal BT Test")
                .font(.largeTitle)

            Text("State: \(btvm.stateText)")
                .font(.title2)
                .foregroundColor(btvm.state == 5 ? .green : .red)

            Text("Raw state: \(btvm.state)")
                .font(.caption)

            Spacer()
        }
        .padding()
    }
}

@MainActor
class MinimalBTViewModel: NSObject, ObservableObject, CBCentralManagerDelegate {
    @Published var state: Int = -1
    @Published var stateText: String = "Not initialized"

    private var centralManager: CBCentralManager!

    override init() {
        super.init()
        print("MinimalBTViewModel init")

        // Create CBCentralManager with self as delegate
        centralManager = CBCentralManager(delegate: self, queue: nil)
        print("CBCentralManager created")
    }

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("🎉🎉🎉 DELEGATE CALLED! State: \(central.state.rawValue)")

        Task { @MainActor in
            self.state = central.state.rawValue

            switch central.state {
            case .unknown:
                self.stateText = "Unknown"
            case .resetting:
                self.stateText = "Resetting"
            case .unsupported:
                self.stateText = "Unsupported"
            case .unauthorized:
                self.stateText = "Unauthorized - Need Permission"
            case .poweredOff:
                self.stateText = "Bluetooth OFF"
            case .poweredOn:
                self.stateText = "Bluetooth ON - Ready!"
            @unknown default:
                self.stateText = "Unknown state"
            }
        }
    }
}