import XCTest
@testable import TapisCore
final class StableDiscoveryListTests: XCTestCase {
    struct Device: Identifiable { let id: Int; let rssi: Int }
    func testSignalChangesDoNotMoveRowsAndNewDevicesAppend() {
        var list = StableDiscoveryList<Device>()
        list.receive(Device(id: 1, rssi: -80))
        list.receive(Device(id: 2, rssi: -50))
        XCTAssertEqual(list.publish { $0.rssi > $1.rssi }.map(\.id), [2, 1])
        list.receive(Device(id: 1, rssi: -30))
        list.receive(Device(id: 3, rssi: -20))
        let next = list.publish { $0.rssi > $1.rssi }
        XCTAssertEqual(next.map(\.id), [2, 1, 3])
        XCTAssertEqual(next[1].rssi, -30)
    }
    func testDuplicatesAreCoalescedAndSnapshotsStayUnchanged() {
        var list = StableDiscoveryList<Device>()
        list.receive(Device(id: 1, rssi: -70))
        let snapshot = list.publish { $0.rssi > $1.rssi }
        for rssi in -65 ... -40 { list.receive(Device(id: 1, rssi: rssi)) }
        XCTAssertEqual(snapshot[0].rssi, -70)
        let updated = list.publish { $0.rssi > $1.rssi }
        XCTAssertEqual(updated.count, 1)
        XCTAssertEqual(updated[0].rssi, -40)
        list = StableDiscoveryList()
        XCTAssertTrue(list.publish { $0.rssi > $1.rssi }.isEmpty)
    }
}
