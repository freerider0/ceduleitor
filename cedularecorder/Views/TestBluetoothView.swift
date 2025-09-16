import SwiftUI
import CoreBluetooth

struct TestBluetoothView: View {
    @StateObject private var btTest = BluetoothTest()

    var body: some View {
        VStack(spacing: 20) {
            Text("Bluetooth Test")
                .font(.largeTitle)

            Text("State: \(btTest.stateText)")
                .font(.title2)
                .foregroundColor(btTest.isReady ? .green : .red)

            Button("Create Manager") {
                btTest.createManager()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)

            Text(btTest.log)
                .font(.system(size: 12, design: .monospaced))
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
        }
        .padding()
    }
}

@MainActor
class BluetoothTest: NSObject, ObservableObject {
    @Published var stateText = "Not initialized"
    @Published var isReady = false
    @Published var log = ""

    private var centralManager: CBCentralManager?

    override init() {
        super.init()
        addLog("BluetoothTest initialized")
    }

    func createManager() {
        addLog("\n=== CREATING CENTRAL MANAGER ===")
        addLog("Current thread: \(Thread.current)")
        addLog("Is main thread: \(Thread.isMainThread)")

        if centralManager != nil {
            addLog("Manager already exists")
            return
        }

        // Try creating with different approaches
        addLog("Creating CBCentralManager...")

        // Force main queue
        DispatchQueue.main.async { [weak self] in
            self?.addLog("On main queue now")
            self?.centralManager = CBCentralManager(delegate: self, queue: nil)
            self?.addLog("CBCentralManager created")

            // Check state immediately
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let manager = self?.centralManager {
                    self?.addLog("State after 0.1s: \(manager.state.rawValue)")
                    self?.handleState(manager.state)
                }
            }

            // Check again after 1 second
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let manager = self?.centralManager {
                    self?.addLog("State after 1s: \(manager.state.rawValue)")
                    self?.handleState(manager.state)
                }
            }
        }
    }

    private func handleState(_ state: CBManagerState) {
        switch state {
        case .unknown:
            stateText = "Unknown (0)"
        case .resetting:
            stateText = "Resetting (1)"
        case .unsupported:
            stateText = "Unsupported (2)"
        case .unauthorized:
            stateText = "Unauthorized (3) - Need Permission!"
        case .poweredOff:
            stateText = "Powered Off (4)"
        case .poweredOn:
            stateText = "Powered On (5) - Ready!"
            isReady = true
        @unknown default:
            stateText = "Unknown future state"
        }
    }

    private func addLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        log += "[\(timestamp)] \(message)\n"
        print(message)
    }
}

extension BluetoothTest: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            addLog("\n🎉 DELEGATE CALLED! State: \(central.state.rawValue)")
            handleState(central.state)

            if central.state == .unauthorized {
                addLog("UNAUTHORIZED - Permission needed!")
                addLog("Trying to trigger permission dialog...")

                // Try scanning to trigger permission
                central.scanForPeripherals(withServices: nil, options: nil)
                central.stopScan()
            } else if central.state == .poweredOn {
                addLog("POWERED ON - Bluetooth is ready!")
            }
        }
    }
}