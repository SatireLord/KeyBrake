import XCTest
@testable import KeyBrakeCore

final class RecoveryStoreTests: XCTestCase {
    func testRecoverySelectionDefaultsToLeavingVPNDisconnectedAndDecodesLegacyPayload() throws {
        let selection = RecoverySelection(restoreNetwork: true)
        XCTAssertFalse(selection.retainVPNDisconnected)

        let legacyPayload = #"{"restoreNetwork":true,"sharingServiceIDs":[],"restartEspanso":false}"#.data(using: .utf8)!
        let legacySelection = try JSONDecoder().decode(RecoverySelection.self, from: legacyPayload)
        XCTAssertFalse(legacySelection.retainVPNDisconnected)

        let explicitSelection = RecoverySelection(
            restoreNetwork: true,
            retainVPNDisconnected: true
        )
        let decodedExplicitSelection = try JSONDecoder().decode(
            RecoverySelection.self,
            from: JSONEncoder().encode(explicitSelection)
        )
        XCTAssertTrue(decodedExplicitSelection.retainVPNDisconnected)
    }

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

    func testLegacySnapshotDecodesProgressFromResourceArrays() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = RecoveryStore(rootDirectory: directory)
        let snapshot = RecoverySnapshot(
            incidentID: UUID(),
            originalOperationalState: .isolated,
            networkChanges: [
                NetworkChange(id: "wifi", displayName: "Wi-Fi", originalEnabled: true, appliedEnabled: false, currentEnabled: nil, kind: "wifi")
            ],
            vpnConnections: [
                NetworkChange(id: "work-vpn", displayName: "Work VPN", originalEnabled: true, appliedEnabled: false, currentEnabled: false, kind: "vpn", isVPN: true)
            ],
            sharingChanges: [
                SharingChange(id: "remote-login", displayName: "Remote Login", originalEnabled: true, appliedEnabled: false, currentEnabled: false, supported: true)
            ]
        )
        var legacyObject = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any])
        legacyObject.removeValue(forKey: "resourceProgress")
        var legacyNetworkChanges = try XCTUnwrap(legacyObject["networkChanges"] as? [[String: Any]])
        legacyNetworkChanges[0].removeValue(forKey: "stateObservationKnown")
        legacyObject["networkChanges"] = legacyNetworkChanges
        var legacyVPNConnections = try XCTUnwrap(legacyObject["vpnConnections"] as? [[String: Any]])
        legacyVPNConnections[0].removeValue(forKey: "stateObservationKnown")
        legacyObject["vpnConnections"] = legacyVPNConnections
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject, options: [.sortedKeys])
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try legacyData.write(to: store.recoveryURL)

        let decoded = try XCTUnwrap(store.load())
        let progressByID = Dictionary(uniqueKeysWithValues: decoded.resourceProgress.map { ($0.resourceID, $0) })
        XCTAssertEqual(Set(progressByID.keys), ["wifi", "work-vpn", "remote-login"])
        XCTAssertEqual(progressByID["wifi"]?.originalEnabled, true)
        XCTAssertEqual(decoded.networkChanges.first?.stateObservationKnown, false)
        XCTAssertEqual(progressByID["wifi"]?.originalStateKnown, false)
        XCTAssertEqual(progressByID["wifi"]?.appliedEnabled, false)
        XCTAssertNil(progressByID["wifi"]?.observedEnabled)
        XCTAssertEqual(progressByID["work-vpn"]?.subsystem, .network)
        XCTAssertEqual(progressByID["work-vpn"]?.originalStateKnown, false)
        XCTAssertEqual(progressByID["remote-login"]?.subsystem, .sharing)
        XCTAssertEqual(progressByID["remote-login"]?.disposition, .pending)
    }

    func testProgressUpdatesPersistIndependentlyAndKeepHistoricalAppliedState() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = RecoveryStore(rootDirectory: directory)
        var snapshot = RecoverySnapshot(
            incidentID: UUID(),
            originalOperationalState: .isolated,
            networkChanges: [
                NetworkChange(id: "wifi", displayName: "Wi-Fi", originalEnabled: true, appliedEnabled: false, currentEnabled: false, kind: "wifi"),
                NetworkChange(id: "ethernet", displayName: "USB Ethernet", originalEnabled: true, kind: "ethernet")
            ],
            sharingChanges: [
                SharingChange(id: "remote-login", displayName: "Remote Login", originalEnabled: true, supported: true)
            ]
        )
        try store.save(snapshot)

        let failedUpdate = try store.updateProgress(
            in: &snapshot,
            subsystem: .network,
            resourceID: "wifi",
            expectedDisplayName: "Wi-Fi",
            observedEnabled: nil,
            disposition: .failed,
            identityMatches: true
        )
        XCTAssertEqual(failedUpdate, .updated)
        let restoredUpdate = try store.updateProgress(
            in: &snapshot,
            subsystem: .network,
            resourceID: "wifi",
            expectedDisplayName: "Wi-Fi",
            observedEnabled: true,
            disposition: .restored,
            identityMatches: true
        )
        XCTAssertEqual(restoredUpdate, .updated)

        let persisted = try XCTUnwrap(store.load())
        XCTAssertEqual(persisted, snapshot)
        let progressByID = Dictionary(uniqueKeysWithValues: persisted.resourceProgress.map { ($0.resourceID, $0) })
        XCTAssertEqual(progressByID["wifi"]?.originalEnabled, true)
        XCTAssertEqual(progressByID["wifi"]?.appliedEnabled, false)
        XCTAssertEqual(progressByID["wifi"]?.observedEnabled, true)
        XCTAssertEqual(progressByID["wifi"]?.disposition, .restored)
        XCTAssertEqual(progressByID["ethernet"]?.disposition, .pending)
        XCTAssertEqual(progressByID["remote-login"]?.disposition, .pending)
    }

    func testProgressKeepsIdentityMismatchAndUnknownRestoreUnresolved() throws {
        var snapshot = RecoverySnapshot(
            incidentID: UUID(),
            originalOperationalState: .isolated,
            networkChanges: [
                NetworkChange(id: "wifi", displayName: "Wi-Fi", originalEnabled: true, appliedEnabled: false, currentEnabled: false, kind: "wifi")
            ]
        )

        let mismatch = snapshot.updateProgress(
            subsystem: .network,
            resourceID: "wifi",
            expectedDisplayName: "USB Ethernet",
            appliedEnabled: true,
            observedEnabled: true,
            disposition: .restored,
            identityMatches: false,
            observedIdentity: "network-service-ethernet"
        )
        XCTAssertEqual(mismatch, .identityMismatch)
        XCTAssertEqual(snapshot.resourceProgress.first?.originalEnabled, true)
        XCTAssertEqual(snapshot.resourceProgress.first?.appliedEnabled, false)
        XCTAssertNil(snapshot.resourceProgress.first?.observedEnabled)
        XCTAssertEqual(snapshot.resourceProgress.first?.identityMatches, false)
        XCTAssertEqual(snapshot.resourceProgress.first?.observedIdentity, "network-service-ethernet")
        XCTAssertEqual(snapshot.resourceProgress.first?.disposition, .identityMismatch)

        var unknownSnapshot = RecoverySnapshot(
            incidentID: UUID(),
            originalOperationalState: .isolated,
            networkChanges: [
                NetworkChange(id: "wifi", displayName: "Wi-Fi", originalEnabled: true, appliedEnabled: false, currentEnabled: nil, kind: "wifi")
            ]
        )
        let unknownRestore = unknownSnapshot.updateProgress(
            subsystem: .network,
            resourceID: "wifi",
            expectedDisplayName: "Wi-Fi",
            observedEnabled: nil,
            disposition: .restored,
            identityMatches: true
        )
        XCTAssertEqual(unknownRestore, .observationUnknown)
        XCTAssertNil(unknownSnapshot.resourceProgress.first?.observedEnabled)
        XCTAssertEqual(unknownSnapshot.resourceProgress.first?.disposition, .unverified)
    }

    func testProgressWriteFailureLeavesStoredAndInMemorySnapshotsUnchanged() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let normalStore = RecoveryStore(rootDirectory: directory)
        let original = RecoverySnapshot(
            incidentID: UUID(),
            originalOperationalState: .isolated,
            networkChanges: [
                NetworkChange(id: "wifi", displayName: "Wi-Fi", originalEnabled: true, appliedEnabled: false, currentEnabled: false, kind: "wifi")
            ]
        )
        try normalStore.save(original)
        let originalBytes = try Data(contentsOf: normalStore.recoveryURL)
        let failingStore = RecoveryStore(rootDirectory: directory, fileManager: FailingReplacementFileManager())
        var current = try XCTUnwrap(failingStore.load())
        let beforeUpdate = current

        XCTAssertThrowsError(try failingStore.updateProgress(
            in: &current,
            subsystem: .network,
            resourceID: "wifi",
            expectedDisplayName: "Wi-Fi",
            observedEnabled: true,
            disposition: .restored,
            identityMatches: true
        ))

        XCTAssertEqual(current, beforeUpdate)
        XCTAssertEqual(try failingStore.load(), beforeUpdate)
        XCTAssertEqual(try Data(contentsOf: failingStore.recoveryURL), originalBytes)
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

private final class FailingReplacementFileManager: FileManager, @unchecked Sendable {
    private let lock = NSLock()
    private var shouldFailTemporaryReplacement = true

    override func moveItem(at srcURL: URL, to dstURL: URL) throws {
        lock.lock()
        let shouldFail = shouldFailTemporaryReplacement && srcURL.lastPathComponent.hasSuffix(".tmp")
        if shouldFail {
            shouldFailTemporaryReplacement = false
        }
        lock.unlock()

        if shouldFail {
            throw NSError(domain: "RecoveryStoreTests", code: 1)
        }
        try super.moveItem(at: srcURL, to: dstURL)
    }
}
