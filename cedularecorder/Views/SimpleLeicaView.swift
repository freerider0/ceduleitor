import SwiftUI
import CoreBluetooth

// Simple view that follows Apple's guide exactly
struct SimpleLeicaView: View {
    @StateObject private var btManager = SimpleBTManager()

    var body: some View {
        VStack(spacing: 20) {
            Text("Simple Leica DISTO")
                .font(.largeTitle)
                .padding()

            // Status indicator
            HStack {
                SwiftUI.Circle()
                    .fill(btManager.isReady ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                Text(btManager.statusText)
                    .font(.headline)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)

            // Measurement display
            Text(btManager.measurement)
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .padding()

            // Control buttons
            VStack(spacing: 10) {
                Button("Start Scanning") {
                    btManager.startScanning()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!btManager.isReady)

                if btManager.isConnected {
                    Button("Request Measurement") {
                        btManager.requestMeasurement()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            }

            // Devices list
            if !btManager.devices.isEmpty {
                List(btManager.devices, id: \.identifier) { device in
                    Button(action: {
                        btManager.connect(to: device)
                    }) {
                        HStack {
                            Text(device.name ?? "Unknown")
                            Spacer()
                            if device == btManager.connectedPeripheral {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Leica DISTO")
    }
}

// Simple manager following the guide exactly
class SimpleBTManager: NSObject, ObservableObject {
    // Published properties for UI
    @Published var statusText = "Initializing..."
    @Published var isReady = false
    @Published var devices: [CBPeripheral] = []
    @Published var measurement = "---.---"
    @Published var isConnected = false

    // Core Bluetooth properties
    private var centralManager: CBCentralManager!
    var connectedPeripheral: CBPeripheral?
    private var writeChar: CBCharacteristic?

    // Leica UUIDs
    private let serviceUUID = CBUUID(string: "3AB10100-F831-4395-B29D-570977D5BF94")
    private let writeUUID = CBUUID(string: "3AB10109-F831-4395-B29D-570977D5BF94")

    override init() {
        super.init()
        print("SimpleBTManager: init")

        // Initialize central manager as per guide
        centralManager = CBCentralManager(delegate: self, queue: nil)
        print("SimpleBTManager: CBCentralManager created")
    }

    func startScanning() {
        guard centralManager.state == .poweredOn else {
            print("Cannot scan, state: \(centralManager.state.rawValue)")
            return
        }

        print("Starting scan...")
        devices.removeAll()

        // Scan without service filter first to find all devices
        centralManager.scanForPeripherals(withServices: nil, options: nil)

        // Stop after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            self.centralManager.stopScan()
            print("Scan stopped")
        }
    }

    func connect(to peripheral: CBPeripheral) {
        print("Connecting to \(peripheral.name ?? "device")...")
        centralManager.stopScan()
        centralManager.connect(peripheral, options: nil)
    }

    func requestMeasurement() {
        guard let peripheral = connectedPeripheral,
              let char = writeChar else {
            print("Not ready to send command")
            return
        }

        print("Sending measurement command...")
        let command = Data([0x64]) // 'd'
        peripheral.writeValue(command, for: char, type: .withResponse)
    }
}

// MARK: - CBCentralManagerDelegate
extension SimpleBTManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("\n🎯 centralManagerDidUpdateState called!")
        print("State: \(central.state.rawValue)")

        switch central.state {
        case .unknown:
            statusText = "Unknown"
            isReady = false
        case .resetting:
            statusText = "Resetting"
            isReady = false
        case .unsupported:
            statusText = "Unsupported"
            isReady = false
        case .unauthorized:
            statusText = "Need Permission"
            isReady = false
            print("⚠️ Go to Settings > Privacy > Bluetooth")
        case .poweredOff:
            statusText = "Bluetooth OFF"
            isReady = false
        case .poweredOn:
            statusText = "Ready"
            isReady = true
            print("✅ Bluetooth is ready!")
        @unknown default:
            statusText = "Unknown"
            isReady = false
        }
    }

    func centralManager(_ central: CBCentralManager,
                       didDiscover peripheral: CBPeripheral,
                       advertisementData: [String : Any],
                       rssi RSSI: NSNumber) {

        let name = peripheral.name ?? "Unknown"
        print("Found: \(name) RSSI: \(RSSI)")

        // Check if DISTO
        if name.lowercased().contains("disto") {
            print("🎯 Found DISTO device!")
        }

        // Add to list if not already there
        if !devices.contains(where: { $0.identifier == peripheral.identifier }) {
            devices.append(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager,
                       didConnect peripheral: CBPeripheral) {
        print("✅ Connected to \(peripheral.name ?? "device")")
        connectedPeripheral = peripheral
        isConnected = true
        statusText = "Connected"

        // Set delegate and discover services
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager,
                       didFailToConnect peripheral: CBPeripheral,
                       error: Error?) {
        print("❌ Failed to connect: \(error?.localizedDescription ?? "unknown")")
        isConnected = false
        statusText = "Failed"
    }

    func centralManager(_ central: CBCentralManager,
                       didDisconnectPeripheral peripheral: CBPeripheral,
                       error: Error?) {
        print("Disconnected from \(peripheral.name ?? "device")")
        isConnected = false
        connectedPeripheral = nil
        writeChar = nil
        statusText = "Disconnected"
    }
}

// MARK: - CBPeripheralDelegate
extension SimpleBTManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }

        print("Found \(services.count) services")
        for service in services {
            print("Service: \(service.uuid)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                   didDiscoverCharacteristicsFor service: CBService,
                   error: Error?) {
        guard let chars = service.characteristics else { return }

        print("Found \(chars.count) characteristics")
        for char in chars {
            print("Char: \(char.uuid)")

            if char.uuid == writeUUID {
                print("✅ Found write characteristic")
                writeChar = char
            }

            if char.properties.contains(.notify) {
                print("Subscribing to notifications")
                peripheral.setNotifyValue(true, for: char)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                   didUpdateValueFor characteristic: CBCharacteristic,
                   error: Error?) {
        guard let data = characteristic.value else { return }

        print("Received \(data.count) bytes")

        if data.count >= 4 {
            let distance = data.withUnsafeBytes { $0.load(as: Float32.self) }
            DispatchQueue.main.async {
                self.measurement = String(format: "%.3f", distance)
            }
            print("Distance: \(distance)m")
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                   didWriteValueFor characteristic: CBCharacteristic,
                   error: Error?) {
        if let error = error {
            print("Write error: \(error)")
        } else {
            print("Write successful")
        }
    }
}