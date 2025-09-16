import SwiftUI
import CoreBluetooth

struct WorkingLeicaView: View {
    @StateObject private var leicaManager = WorkingLeicaManager()

    var body: some View {
        VStack(spacing: 20) {
            // Status
            HStack {
                SwiftUI.Circle()
                    .fill(leicaManager.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                Text(leicaManager.status)
                    .font(.headline)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)

            // Distance Display
            Text(leicaManager.lastDistance)
                .font(.system(size: 48, weight: .bold, design: .monospaced))
            Text("meters")
                .font(.caption)

            // Buttons
            if !leicaManager.isConnected {
                Button("Scan for DISTO") {
                    leicaManager.startScanning()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Request Measurement") {
                    leicaManager.requestMeasurement()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }

            // Found devices
            if !leicaManager.foundDevices.isEmpty {
                List(leicaManager.foundDevices, id: \.identifier) { device in
                    Button(action: {
                        leicaManager.connectTo(device)
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(device.name ?? "Unknown Device")
                                    .font(.headline)
                                Spacer()
                                Text("Connect")
                                    .foregroundColor(.blue)
                            }
                            Text("ID: \(device.identifier.uuidString.prefix(8))...")
                                .font(.caption)
                                .foregroundColor(.gray)
                            if let rssi = leicaManager.deviceRSSI[device.identifier] {
                                Text("Signal: \(rssi) dBm")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .frame(maxHeight: 300)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Leica DISTO")
    }
}

class WorkingLeicaManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var status = "Initializing..."
    @Published var lastDistance = "---.---"
    @Published var isConnected = false
    @Published var foundDevices: [CBPeripheral] = []
    @Published var deviceRSSI: [UUID: NSNumber] = [:]

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?

    // Leica DISTO UUIDs from Python
    private let serviceUUID = CBUUID(string: "3AB10100-F831-4395-B29D-570977D5BF94")
    private let writeUUID = CBUUID(string: "3AB10109-F831-4395-B29D-570977D5BF94")

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScanning() {
        guard centralManager.state == .poweredOn else {
            status = "Bluetooth not ready"
            return
        }

        foundDevices.removeAll()
        status = "Scanning..."

        // FIRST: Check for already connected devices with Leica service
        let connectedPeripherals = centralManager.retrieveConnectedPeripherals(withServices: [serviceUUID])
        print("Already connected devices with Leica service: \(connectedPeripherals.count)")
        for peripheral in connectedPeripherals {
            print("Connected device: \(peripheral.name ?? "Unknown") - \(peripheral.identifier)")
            if !foundDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                foundDevices.append(peripheral)
                deviceRSSI[peripheral.identifier] = NSNumber(value: -50) // Assume good signal for connected
            }
        }

        // ALSO: Check for known peripherals (previously paired)
        if let savedIdentifiers = UserDefaults.standard.array(forKey: "SavedLeicaDevices") as? [String] {
            let uuids = savedIdentifiers.compactMap { UUID(uuidString: $0) }
            let knownPeripherals = centralManager.retrievePeripherals(withIdentifiers: uuids)
            print("Known devices from previous connections: \(knownPeripherals.count)")
            for peripheral in knownPeripherals {
                print("Known device: \(peripheral.name ?? "Unknown") - \(peripheral.identifier)")
                if !foundDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                    foundDevices.append(peripheral)
                    deviceRSSI[peripheral.identifier] = NSNumber(value: -60) // Assume medium signal
                }
            }
        }

        // THEN: Scan for new devices
        centralManager.scanForPeripherals(withServices: nil, options: nil)

        // Stop after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            self.centralManager.stopScan()
            if self.foundDevices.isEmpty {
                self.status = "No devices found"
            } else {
                self.status = "Found \(self.foundDevices.count) devices"
            }
        }
    }

    func connectTo(_ peripheral: CBPeripheral) {
        centralManager.stopScan()
        status = "Connecting..."
        centralManager.connect(peripheral, options: nil)
    }

    func requestMeasurement() {
        guard let peripheral = connectedPeripheral,
              let characteristic = writeCharacteristic else {
            print("Not ready to send command")
            return
        }

        // Send 'd' command to request distance
        let command = Data([0x64]) // ASCII 'd'
        peripheral.writeValue(command, for: characteristic, type: .withResponse)
        status = "Measuring..."
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            status = "Ready"
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

        let name = peripheral.name ?? "Unknown"

        // Store RSSI for signal strength
        deviceRSSI[peripheral.identifier] = RSSI

        // Log all advertisement data to help identify DISTO
        print("\n=== Device Found ===")
        print("Name: \(name)")
        print("ID: \(peripheral.identifier)")
        print("RSSI: \(RSSI)")

        // Check advertisement data
        if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            print("Services: \(serviceUUIDs)")
            // Check if it advertises Leica service
            if serviceUUIDs.contains(serviceUUID) {
                print("⭐ THIS IS A LEICA DEVICE!")
            }
        }

        if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {
            print("Manufacturer Data: \(manufacturerData.hexEncodedString())")
        }

        // Check if it's a DISTO (name contains DISTO or specific ID)
        if name.lowercased().contains("disto") || name.contains("40240557") {
            print("🎯 FOUND DISTO: \(name)")
        }

        // Add all devices to list
        if !foundDevices.contains(where: { $0.identifier == peripheral.identifier }) {
            foundDevices.append(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "device")")
        connectedPeripheral = peripheral
        isConnected = true
        status = "Connected"

        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect: \(error?.localizedDescription ?? "")")
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
            print("Service: \(service.uuid)")

            if service.uuid == serviceUUID {
                print("Found Leica service!")
                peripheral.discoverCharacteristics([writeUUID], for: service)
            } else {
                // Check other services too
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }

        for char in characteristics {
            print("Characteristic: \(char.uuid), properties: \(char.properties)")

            // Store write characteristic
            if char.uuid == writeUUID {
                print("Found write characteristic!")
                writeCharacteristic = char
                status = "Ready to measure"
            }

            // Subscribe to notifications
            if char.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: char)
                print("Subscribed to notifications")
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }

        print("Received \(data.count) bytes from \(characteristic.uuid)")

        // Parse distance (4-byte float)
        if data.count >= 4 {
            let distance = data.withUnsafeBytes { $0.load(as: Float32.self) }
            DispatchQueue.main.async {
                self.lastDistance = String(format: "%.3f", distance)
                self.status = "Measured"
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Write error: \(error)")
            status = "Command failed"
        } else {
            print("Command sent successfully")
        }
    }
}

