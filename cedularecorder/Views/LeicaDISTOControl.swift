import SwiftUI
import CoreBluetooth

struct LeicaDISTOControl: View {
    @StateObject private var disto = DISTOController()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Status
                HStack {
                    SwiftUI.Circle()
                        .fill(disto.isConnected ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    Text(disto.status)
                        .font(.headline)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)

                // Distance Display
                VStack {
                    Text(disto.lastMeasurement)
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                    Text("meters")
                        .font(.caption)
                }
                .padding()

                if !disto.isConnected {
                    Button("Connect to DISTO") {
                        disto.connect()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    // Command buttons
                    VStack(spacing: 15) {
                        Text("Commands")
                            .font(.headline)

                        // Activation button
                        Button("🔄 Activate DISTO") {
                            disto.activateMeasurements()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {

                            Button("📏 Measure (g)") {
                                disto.sendCommand("g")
                            }
                            .buttonStyle(.bordered)

                            Button("📐 Distance (d)") {
                                disto.sendCommand("d")
                            }
                            .buttonStyle(.bordered)

                            Button("✅ On (o)") {
                                disto.sendCommand("o")
                            }
                            .buttonStyle(.bordered)

                            Button("❌ Off (p)") {
                                disto.sendCommand("p")
                            }
                            .buttonStyle(.bordered)

                            Button("💡 Laser (l)") {
                                disto.sendCommand("l")
                            }
                            .buttonStyle(.bordered)

                            Button("🔋 Battery (b)") {
                                disto.sendCommand("b")
                            }
                            .buttonStyle(.bordered)

                            Button("🗑 Clear (c)") {
                                disto.sendCommand("c")
                            }
                            .buttonStyle(.bordered)

                            Button("⏱ Timer (t)") {
                                disto.sendCommand("t")
                            }
                            .buttonStyle(.bordered)

                            Button("📦 Area (a)") {
                                disto.sendCommand("a")
                            }
                            .buttonStyle(.bordered)

                            Button("📊 Volume (v)") {
                                disto.sendCommand("v")
                            }
                            .buttonStyle(.bordered)

                            Button("ℹ️ Status (s)") {
                                disto.sendCommand("s")
                            }
                            .buttonStyle(.bordered)

                            Button("Disconnect") {
                                disto.disconnect()
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                    }
                    .padding()
                }

                // Response log
                VStack(alignment: .leading) {
                    Text("Last Response:")
                        .font(.headline)
                    Text(disto.lastResponse)
                        .font(.system(size: 12, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding()
            }
            .padding()
        }
        .navigationTitle("DISTO Control")
        .onAppear {
            // Auto-connect when view appears
            if !disto.isConnected {
                disto.connect()
            }
        }
    }
}

class DISTOController: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var status = "Not connected"
    @Published var isConnected = false
    @Published var lastMeasurement = "---.---"
    @Published var lastResponse = "No response yet"

    private var centralManager: CBCentralManager!
    private var disto: CBPeripheral?
    private var writeChar: CBCharacteristic?

    private let serviceUUID = CBUUID(string: "3AB10100-F831-4395-B29D-570977D5BF94")
    private let writeUUID = CBUUID(string: "3AB10109-F831-4395-B29D-570977D5BF94")
    private let notifyUUID1 = CBUUID(string: "3AB10101-F831-4395-B29D-570977D5BF94")
    private let notifyUUID2 = CBUUID(string: "3AB10102-F831-4395-B29D-570977D5BF94")

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func connect() {
        guard centralManager.state == .poweredOn else { return }

        status = "Searching..."

        // Look for paired DISTO
        let connected = centralManager.retrieveConnectedPeripherals(withServices: [serviceUUID])
        if let device = connected.first {
            connectTo(device)
            return
        }

        // Scan
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.centralManager.stopScan()
        }
    }

    func connectTo(_ peripheral: CBPeripheral) {
        disto = peripheral
        disto?.delegate = self  // Set delegate BEFORE connecting
        centralManager.stopScan()
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect() {
        if let disto = disto {
            centralManager.cancelPeripheralConnection(disto)
        }
    }

    func sendCommand(_ letter: String) {
        guard let peripheral = disto,
              let char = writeChar,
              let data = letter.data(using: .ascii) else {
            print("Cannot send command - not ready")
            return
        }

        print("\n📤 Sending command: '\(letter)' (0x\(data.map { String(format: "%02x", $0) }.joined()))")
        print("   To characteristic: \(char.uuid)")

        // Update UI
        DispatchQueue.main.async {
            self.lastResponse = "Sent: '\(letter)'"
        }

        // Use withoutResponse for DISTO (it doesn't support withResponse)
        peripheral.writeValue(data, for: char, type: .withoutResponse)
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
        print("\n✅✅ CONNECTED to \(peripheral.name ?? "DISTO")")
        print("   Peripheral ID: \(peripheral.identifier)")

        isConnected = true
        status = "Connected"

        // Make sure we keep the reference
        self.disto = peripheral
        peripheral.delegate = self

        print("   Discovering Leica service: \(serviceUUID)")
        // Try discovering ONLY the Leica service first
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        status = "Disconnected"
        disto = nil
        writeChar = nil
        lastMeasurement = "---.---"
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("❌ Error discovering services: \(error)")
            return
        }

        guard let services = peripheral.services else {
            print("❌ No services found!")
            return
        }

        print("\n📱 Found \(services.count) service(s)")

        for service in services {
            print("   Service: \(service.uuid)")
            if service.uuid == serviceUUID {
                print("   🎯 This is the Leica service! Discovering characteristics...")
                // Discover ALL characteristics for the Leica service
                peripheral.discoverCharacteristics(nil, for: service)
            } else {
                print("   (Other service, skipping)")
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let chars = service.characteristics else { return }

        print("\n📋 Service \(service.uuid):")
        for char in chars {
            let properties = char.properties
            var propString = ""
            if properties.contains(.read) { propString += "read " }
            if properties.contains(.write) { propString += "write " }
            if properties.contains(.writeWithoutResponse) { propString += "writeNoResp " }
            if properties.contains(.notify) { propString += "notify " }
            if properties.contains(.indicate) { propString += "indicate " }

            print("  - \(char.uuid): \(propString)")

            // Subscribe to the MAIN measurement characteristic (from Python code)
            if char.uuid == notifyUUID1 {
                print("    🎯🎯🎯 FOUND THE MEASUREMENT CHARACTERISTIC! Subscribing...")
                peripheral.setNotifyValue(true, for: char)
            } else if char.uuid == notifyUUID2 {
                print("    ✅ Subscribing to secondary notify characteristic")
                peripheral.setNotifyValue(true, for: char)
            } else if char.properties.contains(.notify) || char.properties.contains(.indicate) {
                // Subscribe to ALL notify/indicate characteristics to see what sends data
                print("    📡 Subscribing to other characteristic: \(char.uuid)")
                peripheral.setNotifyValue(true, for: char)
            }

            if char.uuid == writeUUID {
                writeChar = char
                print("    ✅✅ Found write characteristic - READY!")

                // Mark as ready
                DispatchQueue.main.async {
                    self.status = "Ready - Press DISTO button"
                    print("\n🎯 READY! Press the MEASURE button on your DISTO")
                }
            }
        }
    }

    func activateMeasurements() {
        // Don't send any commands - the DISTO sends data automatically when measure button is pressed
        print("DISTO is ready - press the measure button on your device")
        status = "Ready - Press DISTO button"
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("❌ Failed to subscribe to \(characteristic.uuid): \(error)")
        } else {
            if characteristic.uuid == notifyUUID1 {
                print("🎯🎯🎯 MEASUREMENT CHARACTERISTIC SUBSCRIPTION SUCCESS!")
                print("   Characteristic: \(characteristic.uuid)")
                print("   Is notifying: \(characteristic.isNotifying)")

                if characteristic.isNotifying {
                    // Try reading the characteristic directly to test
                    peripheral.readValue(for: characteristic)
                    print("   Attempting to read initial value...")
                }
            } else {
                print("✅ Subscribed to \(characteristic.uuid)")
                print("   Is notifying: \(characteristic.isNotifying)")
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }

        // Log which characteristic sent data
        print("\n🎯🎯🎯 DATA RECEIVED!")
        print("   From characteristic: \(characteristic.uuid)")
        print("   Hex: \(data.map { String(format: "%02x", $0) }.joined())")
        print("   Bytes: \(data.count)")

        // Check if this is from the measurement characteristic (3AB10101)
        if characteristic.uuid == notifyUUID1 && data.count == 4 {
            // Parse as 4-byte float (little-endian) - same as Python struct.unpack('f', data)[0]
            let distance = data.withUnsafeBytes { bytes in
                bytes.load(as: Float32.self)
            }
            print("   📏📏📏 MEASUREMENT: \(distance) meters")

            // Update UI
            DispatchQueue.main.async {
                self.lastMeasurement = String(format: "%.3f", distance)
                self.status = "Measured ✓"
                self.lastResponse = "Distance: \(String(format: "%.3f", distance))m"
            }
        } else if data.count == 4 {
            // Any other 4-byte data, try to parse as float
            let value = data.withUnsafeBytes { bytes in
                bytes.load(as: Float32.self)
            }
            print("   Value as float: \(value)")

            DispatchQueue.main.async {
                self.lastResponse = "Value: \(String(format: "%.3f", value))"
            }
        } else {
            print("   Other data: \(data.count) bytes")
            DispatchQueue.main.async {
                self.lastResponse = "Got \(data.count) bytes: 0x\(data.map { String(format: "%02x", $0) }.joined())"
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("❌ Write failed: \(error)")
        } else {
            print("✅ Command sent successfully to \(characteristic.uuid)")
        }
    }
}