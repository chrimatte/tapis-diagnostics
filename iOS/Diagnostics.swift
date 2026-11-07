import SwiftUI
import CoreBluetooth

final class Diagnostics: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var devices: [CBPeripheral] = []
    @Published var report = "Diagnostica in sola lettura. Nessun comando di movimento.\n"
    @Published var status = "Inizializzazione"
    private var central: CBCentralManager!
    private var selected: CBPeripheral?
    override init() { super.init(); central = CBCentralManager(delegate: self, queue: .main) }
    private func log(_ message: String) { report += "\(ISO8601DateFormatter().string(from: Date())) \(message)\n" }
    func centralManagerDidUpdateState(_ central: CBCentralManager) { status = "Bluetooth: \(central.state.rawValue)"; log(status) }
    func scan() {
        guard central.state == .poweredOn else { return }
        devices = []; central.scanForPeripherals(withServices: nil)
        status = "Scansione BLE"
    }
    func stop() { central.stopScan(); status = "Scansione arrestata" }
    func select(_ peripheral: CBPeripheral) {
        central.stopScan()
        if let selected { central.cancelPeripheralConnection(selected) }
        selected = peripheral; peripheral.delegate = self
        central.connect(peripheral)
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if !devices.contains(where: { $0.identifier == peripheral.identifier }) { devices.append(peripheral) }
        log("\(peripheral.identifier) \(peripheral.name ?? "Senza nome") RSSI=\(RSSI) advertising=\(advertisementData)")
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        status = "Connesso: \(peripheral.name ?? peripheral.identifier.uuidString)"; log(status)
        peripheral.discoverServices(nil)
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) { status = "Connessione fallita"; log("\(status): \(String(describing: error))") }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) { status = "Disconnesso"; log("\(status): \(String(describing: error))") }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error { log(error.localizedDescription); return }
        for service in peripheral.services ?? [] { log("Servizio \(service.uuid)"); peripheral.discoverCharacteristics(nil, for: service) }
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error { log(error.localizedDescription); return }
        for characteristic in service.characteristics ?? [] {
            log("GATT \(service.uuid)/\(characteristic.uuid) proprietà=\(characteristic.properties.rawValue)")
            // Subscribe only to documented treadmill telemetry, never proprietary control points.
            if service.uuid == CBUUID(string: "1826"), characteristic.uuid == CBUUID(string: "2ACD"), characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) { log("Notifiche \(characteristic.uuid): \(characteristic.isNotifying), errore=\(String(describing: error))") }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        log("RX \(peripheral.identifier)/\(characteristic.uuid) \(characteristic.value?.map { String(format: "%02x", $0) }.joined() ?? "nil") errore=\(String(describing: error))")
    }
}
struct DiagnosticsView: View {
    @StateObject private var model = Diagnostics()
    var body: some View {
        NavigationStack {
            List {
                Section("Sola lettura") {
                    Text(model.status)
                    Button("Scansiona BLE", action: model.scan)
                    Button("Ferma scansione", action: model.stop)
                    Text("Se la macchina non compare, verificare modello e modalità di associazione. Un collegamento audio non dimostra la presenza di telemetria.")
                }
                Section("Seleziona la macchina") {
                    ForEach(model.devices, id: \.identifier) { device in
                        Button { model.select(device) } label: {
                            VStack(alignment: .leading) { Text(device.name ?? "Senza nome"); Text(device.identifier.uuidString).font(.caption) }
                        }
                    }
                }
                Section("Rapporto") {
                    ShareLink("Condividi rapporto", item: model.report)
                    Text(model.report).font(.caption.monospaced()).textSelection(.enabled)
                }
            }.navigationTitle("Tapis · Diagnostica")
        }
    }
}
@main struct TapisApp: App { var body: some Scene { WindowGroup { DiagnosticsView() } } }
