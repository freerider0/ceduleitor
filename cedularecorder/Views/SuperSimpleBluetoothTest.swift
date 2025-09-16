import SwiftUI
import CoreBluetooth

struct SuperSimpleBluetoothTest: View {
    @State private var message = "Tap button to test"
    @State private var manager: CBCentralManager?
    @State private var delegate: BTDelegate?  // KEEP DELEGATE ALIVE!

    var body: some View {
        VStack(spacing: 30) {
            Text("Super Simple BT Test")
                .font(.title)

            Text(message)
                .font(.headline)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)

            Button("Create Manager") {
                message = "Creating manager..."

                // Create and STORE the delegate
                delegate = BTDelegate { state in
                    message = "State: \(state)"
                }

                // Create manager with the stored delegate
                manager = CBCentralManager(delegate: delegate!, queue: nil)

                // Check state immediately
                if let m = manager {
                    message = "Created. State: \(m.state.rawValue)"
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// Simplest possible delegate
class BTDelegate: NSObject, CBCentralManagerDelegate {
    var onStateChange: ((Int) -> Void)?

    init(onStateChange: @escaping (Int) -> Void) {
        self.onStateChange = onStateChange
        super.init()
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("🎉 DELEGATE CALLED! State: \(central.state.rawValue)")
        onStateChange?(central.state.rawValue)
    }
}