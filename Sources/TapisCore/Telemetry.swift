import Foundation

public struct Sample: Codable, Equatable, Sendable {
    public let timestamp: Date
    public let source: String
    public let speedKmh: Double?
    public let distanceMeters: Double?
    public let inclinePercent: Double?
    public var heartRateBpm: Double? = nil
    public var energyKcal: Double? = nil
    public var elapsedSeconds: Double? = nil
    public var powerWatts: Double? = nil
    public var averageSpeedKmh: Double? = nil
    public var flags: Int = 0
    public var paceSecondsPerKm: Double? { speedKmh.flatMap { $0 > 0 ? 3600 / $0 : nil } }
}
public enum ParseError: Error { case truncated, reservedFlags, trailingBytes }
public enum TreadmillData {
    /// FTMS 0x2ACD. Values describe machine reports, not independent belt measurements.
    public static func parse(_ data: Data, at time: Date, source: String) throws -> Sample {
        let bytes = Array(data)
        var offset = 0
        func read(_ count: Int) throws -> Int {
            guard offset + count <= bytes.count else { throw ParseError.truncated }
            defer { offset += count }
            return (0..<count).reduce(0) { $0 | Int(bytes[offset + $1]) << (8 * $1) }
        }
        let flags = try read(2)
        guard flags & 0xE000 == 0 else { throw ParseError.reservedFlags }
        let speed = flags & 1 == 0 ? Double(try read(2)) / 100 : nil
        let average = flags & 2 != 0 ? Double(try read(2)) / 100 : nil
        let distance = flags & 4 != 0 ? Double(try read(3)) : nil
        var incline: Double?
        if flags & 8 != 0 {
            incline = Double(Int16(bitPattern: UInt16(try read(2)))) / 10
            _ = try read(2)
        }
        for (bit, size) in [(4,4),(5,1),(6,1)] where flags & (1 << bit) != 0 { _ = try read(size) }
        var energy: Double?
        if flags & 128 != 0 {
            let raw = try read(2)
            energy = raw == 65535 ? nil : Double(raw)
            _ = try read(3)
        }
        let heart = flags & 256 != 0 ? Double(try read(1)) : nil
        if flags & 512 != 0 { _ = try read(1) }
        let elapsed = flags & 1024 != 0 ? Double(try read(2)) : nil
        if flags & 2048 != 0 { _ = try read(2) }
        var power: Double?
        if flags & 4096 != 0 { _ = try read(2); power = Double(Int16(bitPattern: UInt16(try read(2)))) }
        guard offset == bytes.count else { throw ParseError.trailingBytes }
        return Sample(timestamp: time, source: source, speedKmh: speed, distanceMeters: distance, inclinePercent: incline,
                      heartRateBpm: heart, energyKcal: energy, elapsedSeconds: elapsed,
                      powerWatts: power, averageSpeedKmh: average, flags: flags)
    }
}

/// An append-only journal. Each successful append is synchronized before returning.
public final class Journal {
    private let handle: FileHandle
    public init(url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) { _ = FileManager.default.createFile(atPath: url.path, contents: nil) }
        handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
    }
    deinit { try? handle.close() }
    public func append(_ sample: Sample) throws {
        var data = try JSONEncoder().encode(sample)
        data.append(10)
        try handle.write(contentsOf: data)
        try handle.synchronize()
    }
    public static func recover(url: URL) throws -> [Sample] {
        let data = try Data(contentsOf: url)
        // Ignore only an incomplete final line after an interrupted write.
        return try data.split(separator: 10, omittingEmptySubsequences: false).dropLast().map { try JSONDecoder().decode(Sample.self, from: Data($0)) }
    }
}
