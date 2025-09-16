import SwiftUI
import CoreBluetooth

struct FinalBTTest: View {
    @StateObject private var bt = FinalBT()

    var body: some View {
        VStack {
            Text("Final BT Test")
                .font(.largeTitle)
                .padding()

            Text("State: \(bt.state)")
                .font(.title)
                .padding()

            if bt.state == "Ready" {
                Button("Scan") {
                    bt.scan()
                }
                .buttonStyle(.borderedProminent)
            }

            ForEach(bt.devices, id: \.self) { device in
                Text(device)
                    .padding()
            }

            Spacer()
        }
        .onAppear {
            print("View appeared")
        }
    }
}

class FinalBT: NSObject, ObservableObject, CBCentralManagerDelegate {
    @Published var state = "Init"
    @Published var devices: [String] = []

    private var manager: CBCentralManager?

    override init() {
        super.init()
        print("FinalBT init")

        // Delay creation to ensure app is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            print("Creating manager...")
            self?.manager = CBCentralManager(delegate: self, queue: nil)
            print("Manager created, state: \(self?.manager?.state.rawValue ?? -1)")

            // Force a scan to trigger permission if needed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let mgr = self?.manager {
                    print("Current state: \(mgr.state.rawValue)")
                    if mgr.state == .unknown {
                        print("State still unknown, trying scan to trigger permission...")
                        mgr.scanForPeripherals(withServices: nil)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            mgr.stopScan()
                        }
                    }
                }
            }
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("STATE UPDATE: \(central.state.rawValue)")

        DispatchQueue.main.async {
            switch central.state {
            case .poweredOn:
                self.state = "Ready"
            case .poweredOff:
                self.state = "BT Off"
            case .unauthorized:
                self.state = "No Permission"
            default:
                self.state = "State: \(central.state.rawValue)"
            }
        }
    }

    func scan() {
        guard let manager = manager else {
            print("Manager not ready")
            return
        }
        print("Scanning...")
        manager.scanForPeripherals(withServices: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            manager.stopScan()
            print("Scan stopped")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? "Unknown"
        print("Found: \(name)")

        DispatchQueue.main.async {
            if !self.devices.contains(name) {
                self.devices.append(name)
            }
        }
    }
}