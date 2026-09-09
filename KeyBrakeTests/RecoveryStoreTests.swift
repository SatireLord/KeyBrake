import XCTest
@testable import KeyBrakeCore

final class RecoveryStoreTests: XCTestCase {
    func testRecoverySnapshotRoundTripsAndClears() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = RecoveryStore(rootDirectory: directory)
        let snapshot = RecoverySnapshot(incidentID: UUID(), originalOperationalState: .normal, networkChanges: [NetworkChange(id: "wifi", displayName: "Wi-Fi", originalEnabled: true, kind: "wifi")])
        try store.save(snapshot)
        XCTAssertEqual(try store.load(), snapshot)
        let attributes = try FileManager.default.attributesOfItem(atPath: store.recoveryURL.path)
        XCTAssertEqual(attributes[.posixPermissions] as? NSNumber, NSNumber(value: 0o600))
        try store.clear()
        XCTAssertNil(try store.load())
    }

    func testIncidentStoreRetainsUnresolvedRecoveryWhenClearingResolvedHistory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let incidents = IncidentStore(rootDirectory: directory)
        var resolved = IncidentRecord(initiatingAction: "resolved", originalState: .isolated, finalState: .normal)
        resolved.completedAt = Date()
        var unresolved = IncidentRecord(initiatingAction: "unresolved", originalState: .normal, finalState: .recoveryRequired)
        unresolved.completedAt = Date()
        try incidents.save(resolved)
        try incidents.save(unresolved)
        try incidents.clearResolvedHistory()
        XCTAssertEqual(try incidents.list().map(\.initiatingAction), ["unresolved"])
    }
}
