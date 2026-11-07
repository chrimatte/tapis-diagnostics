import Foundation

public enum Metric: String, CaseIterable, Sendable {
    case speed, pace, distance, incline, heartRate, energy, elapsed, power, averageSpeed
    public var title: String {
        switch self {
        case .speed: return "Speed · km/h"
        case .pace: return "Derived pace · min/km"
        case .distance: return "Machine distance counter · m"
        case .incline: return "Incline · %"
        case .heartRate: return "Heart rate · bpm"
        case .energy: return "Energy · kcal"
        case .elapsed: return "Machine time · s"
        case .power: return "Power · W"
        case .averageSpeed: return "Machine average speed · km/h"
        }
    }
    func value(in sample: Sample) -> Double? {
        switch self {
        case .speed: return sample.speedKmh
        case .pace: return sample.paceSecondsPerKm
        case .distance: return sample.distanceMeters
        case .incline: return sample.inclinePercent
        case .heartRate: return sample.heartRateBpm
        case .energy: return sample.energyKcal
        case .elapsed: return sample.elapsedSeconds
        case .power: return sample.powerWatts
        case .averageSpeed: return sample.averageSpeedKmh
        }
    }
}
public struct Reading: Sendable {
    public let value: Double
    public let timestamp: Date
    public let source: String
    public func isStale(at now: Date) -> Bool { now.timeIntervalSince(timestamp) > 5 }
}
public struct LiveTelemetry: Sendable {
    public private(set) var readings: [Metric: Reading] = [:]
    public private(set) var packets = 0
    public init() {}
    public mutating func receive(_ sample: Sample) {
        packets += 1
        for metric in Metric.allCases {
            if let value = metric.value(in: sample) {
                readings[metric] = Reading(value: value, timestamp: sample.timestamp, source: sample.source)
            }
        }
        // Zero speed makes derived pace undefined; never keep a previous running pace.
        if sample.speedKmh == 0 { readings.removeValue(forKey: .pace) }
    }
}

public enum Signal {
    public static func valid(_ rssi: Int) -> Int? { (-127...20).contains(rssi) ? rssi : nil }
    public static func label(_ rssi: Int) -> String {
        rssi >= -60 ? "Strong" : (rssi >= -80 ? "Medium" : "Weak")
    }
}
