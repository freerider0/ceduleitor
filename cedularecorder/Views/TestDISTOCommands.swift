import SwiftUI
import CoreBluetooth

struct TestDISTOCommands: View {
    @StateObject private var tester = DISTOCommandTester()

    var body: some View {
        VStack(spacing: 20) {
            Text("DISTO Command Tester")
                .font(.largeTitle)
                .padding()

            // Status
            HStack {
                SwiftUI.Circle()
                    .fill(tester.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                Text(tester.status)
                    .font(.headline)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)

            if !tester.isConnected {
                Button("Connect to DISTO") {
                    tester.findAndConnect()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Test All Commands") {
                    tester.testAllCommands()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button("Disconnect") {
                    tester.disconnect()
                }
                .buttonStyle(.bordered)
            }

            // Response log
            ScrollView {
                Text(tester.log)
                    .font(.system(size: 10, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)

            Spacer()
        }
        .padding()
    }
}

class DISTOCommandTester: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var status = "Not connected"
    @Published var isConnected = false
    @Published var log = ""

    private var centralManager: CBCentralManager!
    private var disto: CBPeripheral?
    private var writeChar: CBCharacteristic?

    // UUIDs
    private let serviceUUID = CBUUID(string: "3AB10100-F831-4395-B29D-570977D5BF94")
    private let writeUUID = CBUUID(string: "3AB10109-F831-4395-B29D-570977D5BF94")

    // Commands to test (from Python)
    private let commands: [(Data, String)] = [
        (Data([0x67]), "Measure (g) - 0x67"),          // 'g'
        (Data([0x64]), "Distance (d) - 0x64"),         // 'd'
        (Data([0x6F]), "On (o) - 0x6F"),              // 'o'
        (Data([0x70]), "Off (p) - 0x70"),             // 'p'
        (Data([0x00]), "Null byte - 0x00"),
        (Data([0x01]), "Byte 0x01"),
        (Data([0x73]), "Status (s) - 0x73"),          // 's'
        (Data([0x62]), "Battery (b) - 0x62"),         // 'b'
        (Data([0x6C]), "Laser (l) - 0x6C"),           // 'l'
        (Data([0x63]), "Clear (c) - 0x63"),           // 'c'
        (Data([0x74]), "Timer (t) - 0x74"),           // 't'
        (Data([0x61]), "Area (a) - 0x61"),            // 'a'
        (Data([0x76]), "Volume (v) - 0x76"),          // 'v'
    ]

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func findAndConnect() {
        guard centralManager.state == .poweredOn else { return }

        addLog("Looking for paired DISTO...")

        // Check for connected devices
        let connected = centralManager.retrieveConnectedPeripherals(withServices: [serviceUUID])
        if let device = connected.first {
            addLog("Found connected DISTO")
            connect(to: device)
            return
        }

        // Scan for DISTO
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.centralManager.stopScan()
        }
    }

    func connect(to peripheral: CBPeripheral) {
        disto = peripheral
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect() {
        if let disto = disto {
            centralManager.cancelPeripheralConnection(disto)
        }
    }

    func testAllCommands() {
        guard let peripheral = disto, let char = writeChar else {
            addLog("Not ready to test")
            return
        }

        addLog("\n=== TESTING ALL COMMANDS ===\n")

        // Test each command with delay
        for (index, (command, description)) in commands.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 1.5) {
                self.addLog("\nSending: \(description)")
                self.addLog("  Hex: \(command.hexString)")

                // Try both with and without response
                peripheral.writeValue(command, for: char, type: .withoutResponse)

                // Also try with response after 0.5s
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    peripheral.writeValue(command, for: char, type: .withResponse)
                }
            }
        }
    }

    private func addLog(_ message: String) {
        print(message)
        DispatchQueue.main.async {
            self.log += "\(message)\n"
            // Keep log size manageable
            if self.log.count > 10000 {
                self.log = String(self.log.suffix(8000))
            }
        }
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            status = "Ready"
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                       advertisementData: [String : Any], rssi RSSI: NSNumber) {

        if let name = peripheral.name {
            if name.lowercased().contains("disto") {
                addLog("Found DISTO: \(name)")
                connect(to: peripheral)
                centralManager.stopScan()
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        addLog("✅ Connected to \(peripheral.name ?? "DISTO")")
        isConnected = true
        status = "Connected"
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        status = "Disconnected"
        disto = nil
        writeChar = nil
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }

        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let chars = service.characteristics else { return }

        addLog("\nService \(service.uuid):")

        for char in chars {
            addLog("  Char: \(char.uuid)")

            // Subscribe to all notify/indicate characteristics
            if char.properties.contains(.notify) || char.properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: char)
                addLog("    ✅ Subscribed to notifications")
            }

            // Save write characteristic
            if char.uuid == writeUUID {
                writeChar = char
                addLog("    ✅ Found write characteristic")
                status = "Ready to test"
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }

        addLog("\n📡 Response from \(characteristic.uuid.uuidString.suffix(8)):")
        addLog("  Hex: \(data.hexString)")
        addLog("  Bytes: \(data.count)")

        // Try to parse as float if 4 bytes
        if data.count == 4 {
            let distance = data.withUnsafeBytes { $0.load(as: Float32.self) }
            addLog("  📏 As float: \(String(format: "%.3f", distance))m")
        }

        // Also show as string if possible
        if let string = String(data: data, encoding: .utf8) {
            addLog("  As string: \(string)")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            addLog("  ❌ Write error: \(error.localizedDescription)")
        } else {
            addLog("  ✅ Write successful")
        }
    }
}

extension Data {
    var hexString: String {
        return map { String(format: "%02x", $0) }.joined()
    }
}