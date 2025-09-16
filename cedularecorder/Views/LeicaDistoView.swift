import SwiftUI
import CoreBluetooth

struct LeicaDistoView: View {
    @StateObject private var bluetooth = LeicaBluetoothManager()

    var body: some View {
        VStack(spacing: 20) {
            // Status
            HStack {
                SwiftUI.Circle()
                    .fill(bluetooth.isConnected ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(bluetooth.statusMessage)
                    .font(.headline)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)

            // Distance Display
            VStack {
                Text(bluetooth.lastMeasurement ?? "---.---")
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                Text("meters")
                    .font(.caption)
            }
            .padding()

            // Action Buttons
            VStack(spacing: 15) {
                Button(action: {
                    bluetooth.initialize()
                }) {
                    Label("Initialize Bluetooth", systemImage: "antenna.radiowaves.left.and.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(bluetooth.isInitialized)

                Button(action: {
                    bluetooth.startScanning()
                }) {
                    Label("Scan for DISTO", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!bluetooth.canScan || bluetooth.isScanning)

                if bluetooth.isConnected {
                    Button(action: {
                        bluetooth.requestMeasurement()
                    }) {
                        Label("Request Measurement", systemImage: "ruler")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            }
            .padding(.horizontal)

            // Found Devices
            if !bluetooth.foundDevices.isEmpty {
                VStack(alignment: .leading) {
                    Text("Found Devices:")
                        .font(.headline)
                    ForEach(bluetooth.foundDevices, id: \.identifier) { device in
                        Button(action: {
                            bluetooth.connectToDevice(device)
                        }) {
                            HStack {
                                Text(device.name ?? "Unknown")
                                Spacer()
                                Text("Connect")
                                    .foregroundColor(.blue)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }

            // Debug Log
            ScrollView {
                Text(bluetooth.debugLog)
                    .font(.system(size: 10, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 150)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)

            Spacer()
        }
        .padding()
        .navigationTitle("Leica DISTO")
        .onAppear {
            bluetooth.initialize()
        }
    }
}

class LeicaBluetoothManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var statusMessage = "Not initialized"
    @Published var lastMeasurement: String?
    @Published var debugLog = ""
    @Published var isInitialized = false
    @Published var isConnected = false
    @Published var isScanning = false
    @Published var canScan = false
    @Published var foundDevices: [CBPeripheral] = []

    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    private var leicaPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?

    // Leica DISTO BLE UUIDs from Python code
    private let serviceUUID = CBUUID(string: "3AB10100-F831-4395-B29D-570977D5BF94")
    private let writeUUID = CBUUID(string: "3AB10109-F831-4395-B29D-570977D5BF94")
    private let notifyUUID = CBUUID(string: "3AB10101-F831-4395-B29D-570977D5BF94")

    override init() {
        super.init()
        log("LeicaBluetoothManager created")
    }

    func initialize() {
        guard !isInitialized else {
            log("Already initialized")
            return
        }

        log("=== INITIALIZING BLUETOOTH ===")
        log("Creating CBCentralManager...")

        // Create central manager WITHOUT options first
        centralManager = CBCentralManager(delegate: self, queue: nil)
        isInitialized = true

        log("CBCentralManager created")
        log("Initial state: \(centralManager.state.rawValue)")

        // Check state after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.log("State after 0.5s: \(self.centralManager.state.rawValue)")
            self.updateState(self.centralManager.state)
        }
    }

    func startScanning() {
        guard canScan, !isScanning else {
            log("Cannot scan - canScan: \(canScan), isScanning: \(isScanning)")
            return
        }

        log("=== STARTING SCAN ===")
        foundDevices.removeAll()
        isScanning = true

        // Scan specifically for Leica service UUID
        centralManager.scanForPeripherals(
            withServices: [serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        log("Scanning for Leica DISTO devices...")
        statusMessage = "Scanning..."

        // Also try scanning for all devices
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self = self, self.foundDevices.isEmpty else { return }
            self.log("No Leica devices found with service UUID, scanning for all...")
            self.centralManager.stopScan()
            self.centralManager.scanForPeripherals(withServices: nil, options: nil)
        }

        // Stop scanning after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.stopScanning()
        }
    }

    func stopScanning() {
        guard isScanning else { return }
        log("Stopping scan")
        centralManager.stopScan()
        isScanning = false

        if foundDevices.isEmpty {
            statusMessage = "No devices found"
        } else {
            statusMessage = "Found \(foundDevices.count) device(s)"
        }
    }

    func connectToDevice(_ peripheral: CBPeripheral) {
        log("=== CONNECTING TO DEVICE ===")
        log("Device: \(peripheral.name ?? "Unknown") - \(peripheral.identifier)")

        stopScanning()
        leicaPeripheral = peripheral
        peripheral.delegate = self

        statusMessage = "Connecting..."
        centralManager.connect(peripheral, options: nil)
    }

    func requestMeasurement() {
        guard let characteristic = writeCharacteristic else {
            log("ERROR: No write characteristic available")
            return
        }

        log("Sending measurement request...")
        // Send 'd' command as per Python code
        let command = Data([0x64]) // 'd' in ASCII
        leicaPeripheral?.writeValue(command, for: characteristic, type: .withResponse)
    }


    private func updateState(_ state: CBManagerState) {
        switch state {
        case .poweredOn:
            statusMessage = "Bluetooth Ready"
            canScan = true
        case .poweredOff:
            statusMessage = "Bluetooth is OFF"
            canScan = false
        case .unauthorized:
            statusMessage = "Bluetooth Permission Required"
            canScan = false
        case .unsupported:
            statusMessage = "Bluetooth Not Supported"
            canScan = false
        case .resetting:
            statusMessage = "Bluetooth Resetting"
            canScan = false
        case .unknown:
            statusMessage = "Bluetooth State Unknown"
            canScan = false
        @unknown default:
            statusMessage = "Unknown State"
            canScan = false
        }
    }

    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)"
        print(logMessage)

        DispatchQueue.main.async {
            self.debugLog += "\(logMessage)\n"
            // Keep log size manageable
            if self.debugLog.count > 5000 {
                self.debugLog = String(self.debugLog.suffix(4000))
            }
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension LeicaBluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        log("🎉 centralManagerDidUpdateState called! State: \(central.state.rawValue)")
        updateState(central.state)

        // Log detailed state info
        switch central.state {
        case .unknown:
            log("State: Unknown (0) - Waiting for Bluetooth state")
        case .resetting:
            log("State: Resetting (1) - Bluetooth is resetting")
        case .unsupported:
            log("State: Unsupported (2) - Device doesn't support Bluetooth LE")
        case .unauthorized:
            log("State: Unauthorized (3) - App needs Bluetooth permission")
            log("User needs to grant permission in Settings > Privacy > Bluetooth")
        case .poweredOff:
            log("State: PoweredOff (4) - Bluetooth is turned off")
        case .poweredOn:
            log("State: PoweredOn (5) - Ready to scan!")
        @unknown default:
            log("State: Unknown future state")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                       advertisementData: [String : Any], rssi RSSI: NSNumber) {

        let name = peripheral.name ?? "Unknown Device"
        log("Found device: \(name) (RSSI: \(RSSI))")

        // Check if it's a DISTO device
        if name.lowercased().contains("disto") || name.contains("40240557") {
            log("🎯 FOUND LEICA DISTO!")
        }

        // Add to found devices if not already there
        if !foundDevices.contains(where: { $0.identifier == peripheral.identifier }) {
            foundDevices.append(peripheral)
        }

        // Log advertisement data
        if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            log("Service UUIDs: \(serviceUUIDs)")
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        log("✅ Connected to: \(peripheral.name ?? "Unknown")")
        isConnected = true
        statusMessage = "Connected"

        // Discover services
        log("Discovering services...")
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        log("❌ Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
        isConnected = false
        statusMessage = "Connection failed"
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        log("Disconnected from: \(peripheral.name ?? "Unknown")")
        isConnected = false
        statusMessage = "Disconnected"
        writeCharacteristic = nil
        notifyCharacteristic = nil
    }
}

// MARK: - CBPeripheralDelegate
extension LeicaBluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            log("❌ Error discovering services: \(error.localizedDescription)")
            return
        }

        log("Services discovered: \(peripheral.services?.count ?? 0)")

        for service in peripheral.services ?? [] {
            log("Service UUID: \(service.uuid)")

            if service.uuid == serviceUUID {
                log("✅ Found Leica DISTO service!")
                peripheral.discoverCharacteristics([writeUUID, notifyUUID], for: service)
            } else {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            log("❌ Error discovering characteristics: \(error.localizedDescription)")
            return
        }

        log("Characteristics discovered for service \(service.uuid)")

        for characteristic in service.characteristics ?? [] {
            log("Characteristic UUID: \(characteristic.uuid)")
            log("Properties: \(characteristic.properties)")

            if characteristic.uuid == writeUUID {
                log("✅ Found write characteristic")
                writeCharacteristic = characteristic
            }

            if characteristic.uuid == notifyUUID || characteristic.properties.contains(.notify) {
                log("✅ Found notify characteristic")
                notifyCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }

        if writeCharacteristic != nil && notifyCharacteristic != nil {
            log("🎉 Ready to communicate with DISTO!")
            statusMessage = "Ready"
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            log("❌ Error reading value: \(error.localizedDescription)")
            return
        }

        guard let data = characteristic.value else {
            log("No data received")
            return
        }

        log("Received data: \(data.count) bytes")

        // Parse as 4-byte float (little-endian) as per Python code
        if data.count >= 4 {
            let distance = data.withUnsafeBytes { bytes in
                bytes.load(as: Float32.self)
            }

            lastMeasurement = String(format: "%.3f", distance)
            log("📏 Distance: \(distance) meters")
            statusMessage = "Measurement received"
        } else {
            log("Unexpected data format: \(data.hexEncodedString())")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            log("❌ Error writing value: \(error.localizedDescription)")
        } else {
            log("✅ Command sent successfully")
        }
    }
}

// Helper extension for debugging
extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}