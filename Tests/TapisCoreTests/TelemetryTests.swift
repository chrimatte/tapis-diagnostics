import XCTest
@testable import TapisCore
final class TelemetryTests: XCTestCase {
    func testValuesAndSignedIncline() throws {
        let sample = try TreadmillData.parse(Data([12,0,232,3,100,0,0,246,255,0,0]), at: Date(), source: "fixture")
        XCTAssertEqual(sample.speedKmh, 10)
        XCTAssertEqual(sample.distanceMeters, 100)
        XCTAssertEqual(sample.inclinePercent, -1)
        XCTAssertEqual(sample.paceSecondsPerKm, 360)
    }
    func testTruncation() {
        let bytes: [UInt8] = [12,0,232,3,100,0,0,246,255,0,0]
        for count in 0..<bytes.count { XCTAssertThrowsError(try TreadmillData.parse(Data(bytes.prefix(count)), at: Date(), source: "fixture")) }
    }
    func testAbsentAndZero() throws {
        XCTAssertNil(try TreadmillData.parse(Data([1,0]), at: Date(), source: "fixture").speedKmh)
        XCTAssertNil(try TreadmillData.parse(Data([0,0,0,0]), at: Date(), source: "fixture").paceSecondsPerKm)
    }
    func testJournalRecovery() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let journal = try Journal(url: url)
        let sample = try TreadmillData.parse(Data([0,0,0,0]), at: Date(), source: "fixture")
        try journal.append(sample)
        XCTAssertEqual(try Journal.recover(url: url), [sample])
    }
}
