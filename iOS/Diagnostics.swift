import SwiftUI
import CoreBluetooth

struct NearbyDevice: Identifiable {
    let peripheral: CBPeripheral
    var name: String
    var rssi: Int?
    var seen: Date
    var id: UUID { peripheral.identifier }
}

final class Diagnostics: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var devices: [NearbyDevice] = []
    @Published var report = ""
    @Published var status = "Inizializzazione"
    @Published var live = LiveTelemetry()
    @Published var connected = false
    @Published var scanning = false
    @Published var simulated = false
    @Published var canScan = false
    @Published var ftms = "FTMS: da verificare"
    @Published var invalidPackets = 0
    @Published var storageError: String?
    @Published var exportURL: URL?
    private var central: CBCentralManager!
    private var selected: CBPeripheral?
    private var timer: Timer?
    private var scanRefreshTimer: Timer?
    private var discoveries = StableDiscoveryList<NearbyDevice>()
    private var simulationTick = 0
    private var file: FileHandle?
    private var logURL: URL?
    private var writtenBytes = 0
    override init() {
        super.init()
        do {
            let folder = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let url = folder.appendingPathComponent("diagnostica-\(UUID().uuidString).txt")
            _ = FileManager.default.createFile(atPath: url.path, contents: nil)
            file = try FileHandle(forWritingTo: url)
            logURL = url
        } catch { storageError = error.localizedDescription }
        log("Tapis: sola lettura. Velocità riferita dalla macchina, non misura indipendente del nastro. Distanza e tempo sono contatori macchina. Controllo non verificato e disabilitato.")
        central = CBCentralManager(delegate: self, queue: .main)
        if ProcessInfo.processInfo.arguments.contains("--demo") { startSimulation() }
    }
    deinit { scanRefreshTimer?.invalidate(); timer?.invalidate(); try? file?.close() }
    private func log(_ message: String) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let line = "\(formatter.string(from: Date())) \(message)\n"
        report += line
        if report.count > 16000 { report = String(report.suffix(12000)) }
        guard let file, let data = line.data(using: .utf8) else { return }
        guard writtenBytes + data.count <= 10_000_000 else {
            storageError = "Rapporto completo: limite 10 MB. Riapri l’app per un nuovo rapporto."
            return
        }
        do { try file.write(contentsOf: data); try file.synchronize(); writtenBytes += data.count }
        catch { storageError = "Salvataggio rapporto: \(error.localizedDescription)" }
    }
    func prepareExport() {
        guard let logURL else { return }
        do {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Tapis-\(UUID().uuidString).txt")
            try FileManager.default.copyItem(at: logURL, to: url)
            exportURL = url
        } catch { storageError = error.localizedDescription }
    }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        canScan = central.state == .poweredOn
        guard !simulated else { return }
        switch central.state {
        case .poweredOn: status = "Bluetooth pronto"
        case .poweredOff: status = "Bluetooth spento"
        case .unauthorized: status = "Accesso Bluetooth negato: abilitalo in Impostazioni"
        case .unsupported: status = "Bluetooth non disponibile su questo dispositivo"
        default: status = "Bluetooth in inizializzazione"
        }
        if !canScan { stopScanRefresh(); connected = false; scanning = false }
        log(status)
    }
    func scan() {
        guard canScan else { return }
        disconnect()
        devices = []; discoveries = StableDiscoveryList(); scanning = true
        scanRefreshTimer = Timer.scheduledTimer(withTimeInterval: StableDiscoveryList<NearbyDevice>.refreshInterval, repeats: true) { [weak self] _ in
            guard let self, self.scanning else { return }
            self.publishDiscoveries()
        }
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        status = "Scansione BLE · seleziona la macchina"
    }
    func stop() { central.stopScan(); stopScanRefresh(); scanning = false; if !connected { status = "Scansione arrestata" } }
    func disconnect() {
        timer?.invalidate(); timer = nil
        simulated = false; connected = false
        central.stopScan(); stopScanRefresh(); scanning = false
        if let selected { central.cancelPeripheralConnection(selected) }
        selected = nil
        status = "Disconnesso · dati precedenti non attuali"
        log(status)
    }
    func select(_ device: NearbyDevice) {
        disconnect(); live = LiveTelemetry(); invalidPackets = 0; ftms = "FTMS: verifica in corso"
        selected = device.peripheral; device.peripheral.delegate = self
        status = "Connessione a \(device.name)…"
        log("Selezionato \(device.id) \(device.name)")
        central.connect(device.peripheral)
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard scanning else { return }
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name ?? "Senza nome"
        let device = NearbyDevice(peripheral: peripheral, name: name, rssi: Signal.valid(RSSI.intValue), seen: Date())
        discoveries.receive(device)
        log("ADV \(device.id) \(name) RSSI=\(RSSI) \(advertisementData)")
    }
    private func publishDiscoveries() {
        devices = discoveries.publish { left, right in
            let lhs = left.rssi ?? -999, rhs = right.rssi ?? -999
            return lhs == rhs ? left.id.uuidString < right.id.uuidString : lhs > rhs
        }
    }
    private func stopScanRefresh() {
        scanRefreshTimer?.invalidate(); scanRefreshTimer = nil
        if scanning { publishDiscoveries() }
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard peripheral.identifier == selected?.identifier else { central.cancelPeripheralConnection(peripheral); return }
        connected = true; status = "Connesso: \(peripheral.name ?? "Senza nome")"; log(status)
        peripheral.discoverServices(nil)
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard peripheral.identifier == selected?.identifier else { return }
        connected = false; status = "Connessione fallita"; log("\(status): \(String(describing: error))")
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard peripheral.identifier == selected?.identifier else { return }
        connected = false; status = "Disconnesso · nessuna riconnessione automatica"; log("\(status): \(String(describing: error))")
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard peripheral.identifier == selected?.identifier else { return }
        if let error { log(error.localizedDescription); return }
        ftms = (peripheral.services ?? []).contains { $0.uuid == CBUUID(string: "1826") } ? "FTMS presente · in attesa di telemetria" : "FTMS non trovato · compatibilità da approfondire"
        log(ftms)
        for service in peripheral.services ?? [] { log("Servizio \(service.uuid)"); peripheral.discoverCharacteristics(nil, for: service) }
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard peripheral.identifier == selected?.identifier else { return }
        if let error { log(error.localizedDescription); return }
        for characteristic in service.characteristics ?? [] {
            log("GATT \(service.uuid)/\(characteristic.uuid) proprietà=\(characteristic.properties.rawValue)")
            if service.uuid == CBUUID(string: "1826"), characteristic.uuid == CBUUID(string: "2ACD"), characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard peripheral.identifier == selected?.identifier else { return }
        log("Notifiche \(characteristic.uuid): \(characteristic.isNotifying), errore=\(String(describing: error))")
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard connected, !simulated, peripheral.identifier == selected?.identifier else { return }
        if let error { log("Errore RX: \(error.localizedDescription)"); return }
        guard let data = characteristic.value else { return }
        guard characteristic.uuid == CBUUID(string: "2ACD"), characteristic.service?.uuid == CBUUID(string: "1826") else { return }
        receive(data, source: peripheral.identifier.uuidString + "/1826/2ACD")
    }
    private func receive(_ data: Data, source: String) {
        let now = Date()
        log("RX \(source) \(data.map { String(format: "%02x", $0) }.joined())")
        do {
            let sample = try TreadmillData.parse(data, at: now, source: source)
            live.receive(sample)
            ftms = simulated ? "FTMS simulato" : "Telemetria FTMS ricevuta"
            let fields = Metric.allCases.compactMap { metric -> String? in
                guard let reading = live.readings[metric], reading.timestamp == now else { return nil }
                return "\(metric.rawValue)=\(reading.value)"
            }.joined(separator: " ")
            log("PARSED flags=\(sample.flags) origine=\(source) qualità=\(simulated ? "simulata" : "riferita dalla macchina") \(fields)")
        } catch { invalidPackets += 1; log("Pacchetto non interpretato: \(error)") }
    }
    func startSimulation() {
        disconnect(); simulated = true; connected = true; live = LiveTelemetry(); invalidPackets = 0
        status = "SIMULAZIONE · nessun dato reale"; ftms = "FTMS simulato"; simulationTick = 0
        simulationStep()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.simulationStep() }
    }
    private func simulationStep() {
        simulationTick += 1
        let distance = simulationTick * 3
        receive(Data([0x8C, 0x05, 0xE8, 0x03, UInt8(distance & 255), UInt8((distance >> 8) & 255), UInt8((distance >> 16) & 255), 15, 0, 0, 0, 12, 0, 60, 0, 1, 135, UInt8(simulationTick & 255), UInt8((simulationTick >> 8) & 255)]), source: "SIMULAZIONE/1826/2ACD")
    }
}
