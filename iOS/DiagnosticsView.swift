import SwiftUI

struct DiagnosticsView: View {
    @StateObject private var model = Diagnostics()
    @State private var showOtherDevices = false
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        NavigationStack {
            List {
                Section("1. Avvia la scansione") {
                    Text(model.status).font(.headline)
                    Text("Sola lettura · nessun comando di movimento").font(.caption)
                    Text("Avvicinati alla console, premi Scansiona BLE e attendi circa 20–30 secondi. Poi seleziona la macchina nel passaggio 2.").font(.subheadline)
                    Button("Scansiona BLE", action: model.scan).disabled(!model.canScan || model.scanning)
                    if model.scanning { Button("Ferma scansione", action: model.stop) }
                    if model.connected { Button("Disconnetti", action: model.disconnect) }
                    if !model.connected && !model.scanning { Button("Prova dati simulati", action: model.startSimulation) }
                    Text("Tieni l’app in primo piano durante la prova.").font(.caption)
                }
                if !model.connected {
                Section("2. Seleziona la macchina") {
                    Text("RSSI aiuta a confrontare i segnali, non misura la distanza né identifica la macchina. Avvicinati alla console e confronta nome e identificativo.").font(.caption)
                    if model.devices.isEmpty { Text("Nessun dispositivo trovato. Se dopo la scansione la macchina non compare, vai al passaggio 4 e condividi comunque il rapporto.").foregroundStyle(.secondary) }
                    ForEach(model.devices.prefix(2)) { device in
                        deviceRow(device)
                    }
                    if model.devices.count > 2 {
                        DisclosureGroup("Altri dispositivi (\(model.devices.count - 2))", isExpanded: $showOtherDevices) {
                            ForEach(model.devices.dropFirst(2)) { device in
                                deviceRow(device)
                            }
                        }
                    }
                }
                }
                Section("3. Verifica i dati") {
                    Text("Dopo il collegamento, attendi circa 30 secondi. Se consentito dalla palestra, avvia il tapis dalla console e confronta i valori. Se non arrivano dati, condividi comunque il rapporto al passaggio 4.").font(.subheadline)
                    Text(model.ftms)
                    Text("\(model.live.packets) pacchetti validi · \(model.invalidPackets) non interpretati").font(.caption)
                    if model.simulated { Label("SIMULAZIONE · valori di esempio", systemImage: "testtube.2").font(.headline) }
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        VStack(alignment: .leading, spacing: 18) {
                            ForEach(Metric.allCases, id: \.self) { metric in
                                metricRow(metric, now: context.date)
                            }
                        }.padding(.vertical, 8)
                    }
                    Text("La distanza e il tempo sono i contatori della macchina, non della sessione. La velocità può essere nominale o un setpoint. Passo calcolato dalla velocità, non misurato.").font(.caption)
                }
                Section("4. Prepara e condividi il rapporto") {
                    Text("Premi prima Prepara rapporto aggiornato, poi Condividi rapporto preparato. Salvalo in File o condividilo per l’analisi; l’app non lo invia automaticamente. Controlla gli identificativi prima di pubblicarlo.").font(.subheadline)
                    if let error = model.storageError { Text(error).foregroundStyle(.red) }
                    Button("Prepara rapporto aggiornato", action: model.prepareExport)
                    if let url = model.exportURL { ShareLink("Condividi rapporto preparato", item: url) }
                    Text("Include dati grezzi, valori interpretati e identificativi dei dispositivi vicini. Il file è salvato progressivamente nell’app. La preparazione crea una copia dei dati raccolti fino a quel momento.").font(.caption)
                    DisclosureGroup("Ultime righe tecniche") { Text(model.report).font(.caption.monospaced()).textSelection(.enabled) }
                }
            }.navigationTitle("Tapis Scan")
        }
        .onChange(of: model.scanning) { scanning in
            if scanning { showOtherDevices = false }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active { model.disconnect() }
        }
    }
    private func deviceRow(_ device: NearbyDevice) -> some View {
        Button { model.select(device) } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(device.name).font(.headline)
                Text(String(device.id.uuidString.prefix(8))).font(.caption.monospaced())
                Text(device.rssi.map { "\($0) dBm · \(Signal.label($0))" } ?? "Segnale non disponibile")
                Text("Rilevato alle \(device.seen.formatted(date: .omitted, time: .standard))\(model.scanning ? "" : " · scansione ferma")").font(.caption)
            }.padding(.vertical, 4)
        }.disabled(model.connected || (!model.scanning && Date().timeIntervalSince(device.seen) > 30))
    }
    private func metricRow(_ metric: Metric, now: Date) -> some View {
        let reading = model.live.readings[metric]
        return VStack(alignment: .leading, spacing: 3) {
            Text(metric.title).font(.subheadline).foregroundStyle(.secondary)
            if let reading {
                Text(formatted(metric, reading.value)).font(metric == .speed ? .largeTitle.bold() : .title2).monospacedDigit()
                Text(!model.connected ? "Disconnesso · ultimo valore" : (reading.isStale(at: now) ? "Non aggiornato da oltre 5 s" : "Aggiornato"))
                    .font(.caption)
                Text((reading.source.hasPrefix("SIMULAZIONE") ? "Simulato · " : "Macchina · ") + reading.timestamp.formatted(date: .omitted, time: .standard)).font(.caption).foregroundStyle(.secondary)
            } else {
                Text(metric == .pace && model.live.readings[.speed]?.value == 0 ? "— · velocità zero" : "— · mai ricevuto").foregroundStyle(.secondary)
            }
        }.accessibilityElement(children: .combine)
    }
    private func formatted(_ metric: Metric, _ value: Double) -> String {
        if metric == .pace {
            let seconds = Int(value.rounded())
            return String(format: "%d:%02d", seconds / 60, seconds % 60)
        }
        return value.formatted(.number.precision(.fractionLength(0...2)))
    }
}
@main struct TapisApp: App { var body: some Scene { WindowGroup { DiagnosticsView() } } }
