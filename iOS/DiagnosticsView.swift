import SwiftUI

struct DiagnosticsView: View {
    @StateObject private var model = Diagnostics()
    @State private var showOtherDevices = false
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        NavigationStack {
            List {
                Section("1. Start scanning") {
                    Text(model.status).font(.headline)
                    Text("Read only · no movement commands").font(.caption)
                    Text("Stand near the console, tap Scan BLE and wait about 20–30 seconds. Then select the machine in step 2.").font(.subheadline)
                    Button("Scan BLE", action: model.scan).disabled(!model.canScan || model.scanning)
                    if model.scanning { Button("Stop scanning", action: model.stop) }
                    if model.connected { Button("Disconnect", action: model.disconnect) }
                    if !model.connected && !model.scanning { Button("Try simulated data", action: model.startSimulation) }
                    Text("Keep the app in the foreground during the test.").font(.caption)
                }
                if !model.connected {
                Section("2. Select the machine") {
                    Text("The list updates every 3 seconds without moving existing rows. New devices appear at the bottom. Tap Stop scanning to freeze the values.").font(.caption)
                    Text("RSSI helps compare signals; it does not measure distance or identify the machine. Stand near the console and compare names and identifiers.").font(.caption)
                    if model.devices.isEmpty { Text("No devices found. If the machine does not appear after scanning, go to step 4 and share the report anyway.").foregroundStyle(.secondary) }
                    ForEach(model.devices.prefix(2)) { device in
                        deviceRow(device)
                    }
                    if model.devices.count > 2 {
                        DisclosureGroup("Other devices (\(model.devices.count - 2))", isExpanded: $showOtherDevices) {
                            ForEach(model.devices.dropFirst(2)) { device in
                                deviceRow(device)
                            }
                        }
                    }
                }
                }
                Section("3. Check the data") {
                    Text("After connecting, wait about 30 seconds. If your gym permits it, start the treadmill from its console and compare the readings. If no data arrives, share the report in step 4 anyway.").font(.subheadline)
                    Text(model.ftms)
                    Text("\(model.live.packets) valid packets · \(model.invalidPackets) unparsed").font(.caption)
                    if model.simulated { Label("SIMULATION · example values", systemImage: "testtube.2").font(.headline) }
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        VStack(alignment: .leading, spacing: 18) {
                            ForEach(Metric.allCases, id: \.self) { metric in
                                metricRow(metric, now: context.date)
                            }
                        }.padding(.vertical, 8)
                    }
                    Text("Distance and time are machine counters, not session totals. Speed may be nominal or a setpoint. Pace is calculated from speed, not measured.").font(.caption)
                }
                Section("4. Prepare and share the report") {
                    Text("Tap Prepare updated report, then Share prepared report. Save it to Files or share it for analysis; the app does not send it automatically. Review identifiers before publishing.").font(.subheadline)
                    if let error = model.storageError { Text(error).foregroundStyle(.red) }
                    Button("Prepare updated report", action: model.prepareExport)
                    if let url = model.exportURL { ShareLink("Share prepared report", item: url) }
                    Text("Includes raw data, parsed values and nearby device identifiers. The file is saved progressively in the app. Preparing a report creates a snapshot of the data collected so far.").font(.caption)
                    DisclosureGroup("Recent diagnostic lines") { Text(model.report).font(.caption.monospaced()).textSelection(.enabled) }
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
                Text(device.rssi.map { "\($0) dBm · \(Signal.label($0))" } ?? "Signal unavailable")
                Text("Last seen at \(device.seen.formatted(date: .omitted, time: .standard))\(model.scanning ? "" : " · scan stopped")").font(.caption)
            }.padding(.vertical, 4)
        }.disabled(model.connected || (!model.scanning && Date().timeIntervalSince(device.seen) > 30))
    }
    private func metricRow(_ metric: Metric, now: Date) -> some View {
        let reading = model.live.readings[metric]
        return VStack(alignment: .leading, spacing: 3) {
            Text(metric.title).font(.subheadline).foregroundStyle(.secondary)
            if let reading {
                Text(formatted(metric, reading.value)).font(metric == .speed ? .largeTitle.bold() : .title2).monospacedDigit()
                Text(!model.connected ? "Disconnected · last value" : (reading.isStale(at: now) ? "Stale for over 5 s" : "Updated"))
                    .font(.caption)
                Text((reading.source.hasPrefix("SIMULATION") ? "Simulated · " : "Machine · ") + reading.timestamp.formatted(date: .omitted, time: .standard)).font(.caption).foregroundStyle(.secondary)
            } else {
                Text(metric == .pace && model.live.readings[.speed]?.value == 0 ? "— · zero speed" : "— · never received").foregroundStyle(.secondary)
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
