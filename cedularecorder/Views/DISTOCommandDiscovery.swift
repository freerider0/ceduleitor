import SwiftUI
import CoreBluetooth

struct DISTOCommandDiscovery: View {
    @StateObject private var discovery = CommandDiscovery()

    var body: some View {
        VStack(spacing: 20) {
            headerSection
            statusSection
            controlSection
            resultsSection
            Spacer()
        }
        .padding()
    }

    var headerSection: some View {
        Text("DISTO Command Discovery")
            .font(.largeTitle)
            .padding()
    }

    var statusSection: some View {
        HStack {
            SwiftUI.Circle()
                .fill(discovery.isConnected ? Color.green : Color.red)
                .frame(width: 12, height: 12)
            Text(discovery.status)
                .font(.headline)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }

    var controlSection: some View {
        Group {
            if !discovery.isConnected {
                Button("Connect to DISTO") {
                    discovery.connect()
                }
                .buttonStyle(.borderedProminent)
            } else {
                VStack(spacing: 10) {
                    Text("Test Range: 0x\(String(format: "%02X", discovery.currentByte)) / 0xFF")
                        .font(.caption)

                    ProgressView(value: Double(discovery.currentByte), total: 255)
                        .padding(.horizontal)

                    HStack(spacing: 20) {
                        Button("Test All Commands") {
                            discovery.testAllBytes()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Test ASCII Only") {
                            discovery.testASCIIOnly()
                        }
                        .buttonStyle(.bordered)

                        Button("Stop") {
                            discovery.stopTesting()
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
            }
        }
    }

    var resultsSection: some View {
        VStack(alignment: .leading) {
            Text("Commands that got responses:")
                .font(.headline)

            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(discovery.workingCommands, id: \.self) { cmd in
                        CommandRow(command: cmd)
                    }
                }
            }
            .frame(maxHeight: 300)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
        .padding()
    }
}

struct CommandRow: View {
    let command: CommandResult

    var body: some View {
        HStack {
            Text("0x\(String(format: "%02X", command.byte))")
                .font(.system(.caption, design: .monospaced))
                .frame(width: 50)

            Group {
                if command.byte >= 32 && command.byte <= 126 {
                    Text("'\(String(UnicodeScalar(command.byte)))'")
                        .font(.system(.caption, design: .monospaced))
                } else {
                    Text("   ")
                }
            }
            .frame(width: 30)

            Text(command.response)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(.horizontal)
    }
}

struct CommandResult: Hashable {
    let byte: UInt8
    let response: String
}

class CommandDiscovery: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var status = "Not connected"
    @Published var isConnected = false
    @Published var currentByte: UInt8 = 0
    @Published var workingCommands: [CommandResult] = []

    private var centralManager: CBCentralManager!
    private var disto: CBPeripheral?
    private var writeChar: CBCharacteristic?
    private var isTesting = false
    private var testQueue: [UInt8] = []
    private var lastCommand: UInt8 = 0
    private var responseTimer: Timer?
    private var responseBuffer = ""

    private let serviceUUID = CBUUID(string: "3AB10100-F831-4395-B29D-570977D5BF94")
    private let writeUUID = CBUUID(string: "3AB10109-F831-4395-B29D-570977D5BF94")

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func connect() {
        guard centralManager.state == .poweredOn else { return }

        let connected = centralManager.retrieveConnectedPeripherals(withServices: [serviceUUID])
        if let device = connected.first {
            connectTo(device)
            return
        }

        centralManager.scanForPeripherals(withServices: nil, options: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.centralManager.stopScan()
        }
    }

    func connectTo(_ peripheral: CBPeripheral) {
        disto = peripheral
        centralManager.stopScan()
        centralManager.connect(peripheral, options: nil)
    }

    func testAllBytes() {
        workingCommands.removeAll()
        testQueue = Array(0...255)
        isTesting = true
        responseBuffer = ""
        testNextCommand()
    }

    func testASCIIOnly() {
        workingCommands.removeAll()
        // Test printable ASCII (32-126) plus common control chars
        testQueue = Array(0...31) + Array(32...126) + Array(127...127)
        isTesting = true
        responseBuffer = ""
        testNextCommand()
    }

    func stopTesting() {
        isTesting = false
        testQueue.removeAll()
        responseTimer?.invalidate()
        status = "Stopped"
    }

    private func testNextCommand() {
        guard isTesting, !testQueue.isEmpty,
              let peripheral = disto,
              let char = writeChar else {
            if isTesting {
                status = "Test complete!"
                isTesting = false
            }
            return
        }

        let byte = testQueue.removeFirst()
        currentByte = byte
        lastCommand = byte
        responseBuffer = ""

        // Send command
        let data = Data([byte])
        peripheral.writeValue(data, for: char, type: .withoutResponse)

        let byteStr = String(format: "0x%02X", byte)
        let asciiStr = (byte >= 32 && byte <= 126) ? " '\(String(UnicodeScalar(byte)))'" : ""
        print("Testing: \(byteStr)\(asciiStr)")
        status = "Testing: \(byteStr)\(asciiStr)"

        // Wait for response, then test next
        responseTimer?.invalidate()
        responseTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            // Check if we got a response
            if !self.responseBuffer.isEmpty {
                let result = CommandResult(
                    byte: self.lastCommand,
                    response: self.responseBuffer
                )
                self.workingCommands.append(result)
                print("✅ Command \(byteStr) got response: \(self.responseBuffer)")
            }

            // Test next command
            self.testNextCommand()
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
                connectTo(peripheral)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
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

        for char in chars {
            if char.properties.contains(.notify) || char.properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: char)
            }

            if char.uuid == writeUUID {
                writeChar = char
                status = "Ready to test"
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }

        // Skip 0000
        if data.count == 2 && data == Data([0x00, 0x00]) {
            return
        }

        let hex = data.map { String(format: "%02x", $0) }.joined()

        // Add to response buffer
        if data.count == 4 {
            let distance = data.withUnsafeBytes { $0.load(as: Float32.self) }
            responseBuffer += String(format: "%.3fm ", distance)
        } else {
            responseBuffer += "0x\(hex) "
        }

        // If ASCII readable, add that too
        if let string = String(data: data, encoding: .ascii), !string.isEmpty {
            let cleaned = string.replacingOccurrences(of: "\0", with: "")
            if !cleaned.isEmpty {
                responseBuffer += "('\(cleaned)') "
            }
        }
    }
}