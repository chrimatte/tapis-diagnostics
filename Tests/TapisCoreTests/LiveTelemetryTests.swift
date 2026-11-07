import XCTest
@testable import TapisCore
final class LiveTelemetryTests: XCTestCase {
    let date = Date(timeIntervalSince1970: 1000)
    func testOptionalMetrics() throws {
        let data = Data([0x8C, 0x05, 0xE8, 0x03, 30, 0, 0, 15, 0, 0, 0, 12, 0, 60, 0, 1, 135, 10, 0])
        let s = try TreadmillData.parse(data, at: date, source: "fixture")
        XCTAssertEqual(s.speedKmh, 10)
        XCTAssertEqual(s.inclinePercent, 1.5)
        XCTAssertEqual(s.distanceMeters, 30)
        XCTAssertEqual(s.heartRateBpm, 135)
        XCTAssertEqual(s.energyKcal, 12)
        XCTAssertEqual(s.elapsedSeconds, 10)
        for count in 0..<data.count { XCTAssertThrowsError(try TreadmillData.parse(data.prefix(count), at: date, source: "fixture")) }
    }
    func testAllFieldsAndSignedPower() throws {
        var data = Data([0xFE, 0x1F])
        // All flags except More Data: speed, average, distance, incline/angle,
        // elevation, pace, energy, HR, MET, time, remaining, force/power.
        data.append(contentsOf: [232,3,132,3,100,0,0,10,0,0,0,20,0,30,0,60,70,12,0,60,0,1,135,10,20,0,30,0,255,255,246,255])
        let sample = try TreadmillData.parse(data, at: date, source: "fixture")
        XCTAssertEqual(sample.averageSpeedKmh, 9)
        XCTAssertEqual(sample.powerWatts, -10)
        XCTAssertEqual(sample.elapsedSeconds, 20)
    }
    func testPartialPacketsDoNotRefreshOldMetric() throws {
        var live = LiveTelemetry()
        live.receive(try TreadmillData.parse(Data([0,0,232,3]), at: date, source: "fixture"))
        live.receive(try TreadmillData.parse(Data([1,1,135]), at: date.addingTimeInterval(8), source: "fixture"))
        XCTAssertTrue(try XCTUnwrap(live.readings[.speed]).isStale(at: date.addingTimeInterval(8)))
        XCTAssertFalse(try XCTUnwrap(live.readings[.heartRate]).isStale(at: date.addingTimeInterval(8)))
        XCTAssertNil(live.readings[.distance])
    }
    func testZeroClearsPace() throws {
        var live = LiveTelemetry()
        for bytes: [UInt8] in [[0,0,232,3], [0,0,0,0]] {
            live.receive(try TreadmillData.parse(Data(bytes), at: date, source: "fixture"))
        }
        XCTAssertNil(live.readings[.pace])
        XCTAssertEqual(live.readings[.speed]?.value, 0)
    }
    func testMalformedAndReserved() {
        for bytes: [UInt8] in [[0,32,0,0], [0,0,0,0,99]] {
            XCTAssertThrowsError(try TreadmillData.parse(Data(bytes), at: date, source: "fixture"))
        }
    }
    func testSignalUnavailable() {
        XCTAssertNil(Signal.valid(127))
        XCTAssertEqual(Signal.valid(-65), -65)
        XCTAssertEqual(Signal.label(-50), "Strong")
    }
}
