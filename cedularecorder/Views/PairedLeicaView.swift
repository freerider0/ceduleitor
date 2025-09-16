import SwiftUI
import CoreBluetooth

struct PairedLeicaView: View {
    @StateObject private var manager = PairedLeicaManager()

    var body: some View {
        VStack(spacing: 20) {
            // Status
            HStack {
                SwiftUI.Circle()
                    .fill(manager.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                Text(manager.status)
                    .font(.headline)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)

            // Distance Display
            Text(manager.lastDistance)
                .font(.system(size: 48, weight: .bold, design: .monospaced))
            Text("meters")
                .font(.caption)

            // Buttons
            if !manager.isConnected {
                Button("Find Paired DISTO") {
                    manager.findPairedDevices()
                }
                .buttonStyle(.borderedProminent)
            } else {
                VStack {
                    Text("Press MEASURE button on DISTO")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Button("Disconnect") {
                        manager.disconnect()
                    }
                    .buttonStyle(.bordered)
                }
            }

            // Paired devices
            if !manager.pairedDevices.isEmpty {
                VStack(alignment: .leading) {
                    Text("Paired Devices:")
                        .font(.headline)

                    ForEach(manager.pairedDevices, id: \.identifier) { device in
                        Button(action: {
                            manager.connectTo(device)
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(device.name ?? "Unknown")
                                        .font(.headline)
                                    Text("Tap to connect")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.blue)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                }
                .padding()
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Leica DISTO")
        .onAppear {
            manager.findPairedDevices()
        }
    }
}

class PairedLeicaManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var status = "Initializing..."
    @Published var lastDistance = "---.---"
    @Published var isConnected = false
    @Published var pairedDevices: [CBPeripheral] = []

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?

    // Leica DISTO UUIDs
    private let serviceUUID = CBUUID(string: "3AB10100-F831-4395-B29D-570977D5BF94")
    private let writeUUID = CBUUID(string: "3AB10109-F831-4395-B29D-570977D5BF94")
    private let notifyUUID1 = CBUUID(string: "3AB10101-F831-4395-B29D-570977D5BF94")
    private let notifyUUID2 = CBUUID(string: "3AB10102-F831-4395-B29D-570977D5BF94")

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func findPairedDevices() {
        guard centralManager.state == .poweredOn else {
            status = "Bluetooth not ready"
            return
        }

        pairedDevices.removeAll()

        // Method 1: Look for devices already connected to iOS with Leica service
        let connectedWithService = centralManager.retrieveConnectedPeripherals(withServices: [serviceUUID])
        print("Devices connected with Leica service: \(connectedWithService.count)")

        // Method 2: Look for ANY connected peripherals (broader search)
        // Try common BLE service UUIDs
        let commonServices = [
            CBUUID(string: "1800"), // Generic Access
            CBUUID(string: "1801"), // Generic Attribute
            CBUUID(string: "180A"), // Device Information
            serviceUUID
        ]

        for service in commonServices {
            let connected = centralManager.retrieveConnectedPeripherals(withServices: [service])
            for device in connected {
                if !pairedDevices.contains(where: { $0.identifier == device.identifier }) {
                    print("Found connected device: \(device.name ?? "Unknown")")

                    // Check if it might be a DISTO
                    if let name = device.name {
                        if name.lowercased().contains("disto") ||
                           name.contains("40240557") ||
                           name.contains("Leica") {
                            print("✅ This looks like a DISTO!")
                            pairedDevices.append(device)
                        }
                    }
                }
            }
        }

        // Also try a quick scan to get device names
        status = "Looking for DISTO..."
        centralManager.scanForPeripherals(withServices: nil, options: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.centralManager.stopScan()

            if self.pairedDevices.isEmpty {
                self.status = "No DISTO found. Make sure it's paired in Settings"
            } else {
                self.status = "Found \(self.pairedDevices.count) DISTO device(s)"
            }
        }
    }

    func connectTo(_ peripheral: CBPeripheral) {
        status = "Connecting..."
        centralManager.stopScan()

        // Save the device ID for future use
        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: "LastLeicaDevice")

        centralManager.connect(peripheral, options: nil)
    }

    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            status = "Ready"
            // Auto-find devices on startup
            findPairedDevices()
        case .poweredOff:
            status = "Bluetooth OFF"
        case .unauthorized:
            status = "Need Permission"
        default:
            status = "Bluetooth: \(central.state.rawValue)"
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                       advertisementData: [String : Any], rssi RSSI: NSNumber) {

        // Only add if it looks like a DISTO
        if let name = peripheral.name {
            if name.lowercased().contains("disto") ||
               name.contains("40240557") ||
               name.contains("Leica") {

                if !pairedDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                    print("Found DISTO in scan: \(name)")
                    pairedDevices.append(peripheral)
                }
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("✅ Connected to \(peripheral.name ?? "device")")
        connectedPeripheral = peripheral
        isConnected = true
        status = "Connected"

        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("❌ Failed to connect: \(error?.localizedDescription ?? "")")
        isConnected = false
        status = "Connection failed"
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        connectedPeripheral = nil
        writeCharacteristic = nil
        status = "Disconnected"
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }

        print("Found \(services.count) services")
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }

        print("Characteristics in service \(service.uuid):")
        for char in characteristics {
            print("  - \(char.uuid): \(char.properties)")

            // Subscribe to the notification characteristics (like Python code)
            if char.uuid == notifyUUID1 || char.uuid == notifyUUID2 {
                print("✅ Subscribing to notifications on \(char.uuid)")
                peripheral.setNotifyValue(true, for: char)
                status = "Ready - Press DISTO button"
            }

            // Also subscribe to any other notify characteristics
            if char.properties.contains(.notify) {
                print("📡 Subscribing to \(char.uuid)")
                peripheral.setNotifyValue(true, for: char)
            }

            // Store write characteristic if needed
            if char.uuid == writeUUID {
                writeCharacteristic = char
                print("✏️ Found write characteristic")
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }

        // Skip the 0000 responses (2 bytes)
        if data.count == 2 && data == Data([0x00, 0x00]) {
            return
        }

        print("\n📡 Received data from \(characteristic.uuid)")
        print("   Hex: \(data.map { String(format: "%02x", $0) }.joined())")
        print("   Bytes: \(data.count)")

        // Parse as 4-byte float (little-endian) like Python struct.unpack('<f', data)
        if data.count == 4 {
            let distance = data.withUnsafeBytes { bytes in
                bytes.load(as: Float32.self)
            }
            print("   📏 DISTANCE: \(distance) meters")

            // Only update if it's a reasonable distance (not 0.005m which seems to be idle)
            DispatchQueue.main.async {
                if distance > 0.01 {
                    self.lastDistance = String(format: "%.3f", distance)
                    self.status = "Measured"
                } else {
                    // Very small distance might mean no measurement
                    self.status = "Ready"
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Write error: \(error)")
            status = "Command failed"
        } else {
            print("✅ Command sent")
        }
    }
}