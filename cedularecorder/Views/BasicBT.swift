import SwiftUI
import CoreBluetooth

struct BasicBT: View {
    @StateObject private var bt = BTManager()

    var body: some View {
        VStack {
            Text("State: \(bt.stateText)")
                .font(.largeTitle)
                .padding()
        }
    }
}

class BTManager: NSObject, ObservableObject, CBCentralManagerDelegate {
    @Published var stateText = "Starting..."
    var centralManager: CBCentralManager!

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async {
            self.stateText = "State: \(central.state.rawValue)"
        }
    }
}