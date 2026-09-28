import XCTest
@testable import KeyBrakeCore

@MainActor
final class KeyBrakeSystemSettingsRouteTests: XCTestCase {
    func testCanonicalKeyboardURLParsesAndHasNoMutationPayload() throws {
        let url = KeyBrakeSystemSettingsRoute.canonicalKeyboardURL

        XCTAssertEqual(url.absoluteString, "keybrake://settings/keyboard")
        XCTAssertEqual(KeyBrakeSystemSettingsRoute.parse(url), .keyboard)

        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertNil(components.percentEncodedQuery)
        XCTAssertNil(components.percentEncodedFragment)
        XCTAssertNil(components.user)
        XCTAssertNil(components.password)
        XCTAssertNil(components.port)
    }

    func testParserRejectsAlternateAndMutatingURLs() throws {
        let rejectedURLs = [
            "keybrake://settings/keyboard?target=com.example.target",
            "keybrake://settings/keyboard?services=ListenEvent,PostEvent",
            "keybrake://settings/keyboard?reset=all",
            "keybrake://settings/keyboard#reset",
            "keybrake://settings/keyboard?",
            "keybrake://settings/keyboard#",
            "keybrake://settings/keyboard/",
            "keybrake://settings/keyboard/reset",
            "keybrake://settings/keyboard%2Freset",
            "keybrake://settings/%6Beyboard",
            "keybrake://settings//keyboard",
            "keybrake://settings/keyboard/..",
            "keybrake://reset/keyboard",
            "keybrake://settings/reset",
            "keybrake://user@settings/keyboard",
            "keybrake://settings:443/keyboard",
            "KEYBRAKE://settings/keyboard",
            "keybrake://SETTINGS/keyboard",
            "https://settings/keyboard",
            "keybrake:settings/keyboard",
            "keybrake:///keyboard"
        ]

        for rawValue in rejectedURLs {
            if let url = URL(string: rawValue) {
                XCTAssertNil(KeyBrakeSystemSettingsRoute.parse(url), "Accepted noncanonical route: \(rawValue)")
            }
        }
    }

    func testHandoffOpensOnlyCanonicalKeyboardRouteForOneRegisteredCopy() {
        let registeredApplication = URL(fileURLWithPath: "/Applications/KeyBrake.app")
        var openedRoute: URL?
        var openedApplication: URL?
        var outcome: KeyBrakeSystemSettingsHandoff.Outcome?
        let handoff = makeHandoff(
            registeredApplications: [registeredApplication],
            openRoute: { route, application, completion in
                openedRoute = route
                openedApplication = application
                completion(.opened)
            }
        )

        handoff.openKeyboardSettings { outcome = $0 }

        XCTAssertEqual(openedRoute, KeyBrakeSystemSettingsRoute.canonicalKeyboardURL)
        XCTAssertEqual(openedApplication, registeredApplication)
        XCTAssertEqual(outcome, .opened)
    }

    func testHandoffReportsMissingConfigurationAndMissingApplication() {
        var outcomes: [KeyBrakeSystemSettingsHandoff.Outcome] = []
        let missingConfiguration = makeHandoff(hostBundleIdentifier: nil)
        missingConfiguration.openKeyboardSettings { outcomes.append($0) }

        let missingApplication = makeHandoff(registeredApplications: [])
        missingApplication.openKeyboardSettings { outcomes.append($0) }

        XCTAssertEqual(outcomes, [
            .failed(.missingHostBundleIdentifier),
            .failed(.applicationNotRegistered)
        ])
    }

    func testHandoffRejectsInstalledApplicationWithoutKeyboardRouteHandler() {
        var openerCalled = false
        var outcome: KeyBrakeSystemSettingsHandoff.Outcome?
        let handoff = makeHandoff(
            registeredApplications: [URL(fileURLWithPath: "/Applications/KeyBrake.app")],
            keyboardRouteIsSupported: false,
            openRoute: { _, _, _ in openerCalled = true }
        )

        handoff.openKeyboardSettings { outcome = $0 }

        XCTAssertFalse(openerCalled)
        XCTAssertEqual(outcome, .failed(.keyboardRouteNotRegistered))
    }

    func testHandoffRejectsMultipleRegisteredCopiesWithoutOpeningEither() {
        var openerCalled = false
        var outcome: KeyBrakeSystemSettingsHandoff.Outcome?
        let handoff = makeHandoff(
            registeredApplications: [
                URL(fileURLWithPath: "/Applications/KeyBrake.app"),
                URL(fileURLWithPath: "/Users/test/Applications/KeyBrake.app")
            ],
            openRoute: { _, _, _ in openerCalled = true }
        )

        handoff.openKeyboardSettings { outcome = $0 }

        XCTAssertFalse(openerCalled)
        XCTAssertEqual(outcome, .failed(.multipleRegisteredApplications(2)))
    }

    func testHandoffUsesOneMatchingRunningCopyToResolveRegisteredDuplicates() {
        let runningCopy = URL(fileURLWithPath: "/Users/test/Applications/KeyBrake.app")
        var openedApplication: URL?
        var outcome: KeyBrakeSystemSettingsHandoff.Outcome?
        let handoff = makeHandoff(
            registeredApplications: [
                URL(fileURLWithPath: "/Applications/KeyBrake.app"),
                runningCopy
            ],
            runningApplications: [.init(bundleURL: runningCopy)],
            openRoute: { _, application, completion in
                openedApplication = application
                completion(.opened)
            }
        )

        handoff.openKeyboardSettings { outcome = $0 }

        XCTAssertEqual(openedApplication, runningCopy)
        XCTAssertEqual(outcome, .opened)
    }

    func testHandoffRejectsMultipleRunningCopiesAndDifferentRunningCopy() {
        let registeredApplication = URL(fileURLWithPath: "/Applications/KeyBrake.app")
        var outcomes: [KeyBrakeSystemSettingsHandoff.Outcome] = []
        let multipleRunning = makeHandoff(
            registeredApplications: [registeredApplication],
            runningApplications: [
                .init(bundleURL: registeredApplication),
                .init(bundleURL: registeredApplication)
            ]
        )
        multipleRunning.openKeyboardSettings { outcomes.append($0) }

        let differentRunning = makeHandoff(
            registeredApplications: [registeredApplication],
            runningApplications: [.init(bundleURL: URL(fileURLWithPath: "/Users/test/KeyBrake.app"))]
        )
        differentRunning.openKeyboardSettings { outcomes.append($0) }

        XCTAssertEqual(outcomes, [
            .failed(.multipleRunningApplications(2)),
            .failed(.differentApplicationIsRunning)
        ])
    }

    func testHandoffReportsRunningCopyWithoutKnownBundleLocation() {
        var outcome: KeyBrakeSystemSettingsHandoff.Outcome?
        let handoff = makeHandoff(
            registeredApplications: [URL(fileURLWithPath: "/Applications/KeyBrake.app")],
            runningApplications: [.init(bundleURL: nil)]
        )

        handoff.openKeyboardSettings { outcome = $0 }

        XCTAssertEqual(outcome, .failed(.runningApplicationLocationUnavailable))
    }

    func testHandoffSurfacesLaunchFailureAndAllowsRetry() {
        var openCount = 0
        var outcomes: [KeyBrakeSystemSettingsHandoff.Outcome] = []
        let handoff = makeHandoff(
            registeredApplications: [URL(fileURLWithPath: "/Applications/KeyBrake.app")],
            openRoute: { _, _, completion in
                openCount += 1
                completion(openCount == 1 ? .failed("Launch denied") : .opened)
            }
        )

        handoff.openKeyboardSettings { outcomes.append($0) }
        handoff.openKeyboardSettings { outcomes.append($0) }

        XCTAssertEqual(openCount, 2)
        XCTAssertEqual(outcomes, [.failed(.launchFailed("Launch denied")), .opened])
    }

    func testHandoffRejectsOnlyConcurrentDuplicateAndAllowsLaterFocusRequest() {
        var finishOpening: (@MainActor (KeyBrakeSystemSettingsHandoff.RouteOpenResult) -> Void)?
        var openCount = 0
        var outcomes: [KeyBrakeSystemSettingsHandoff.Outcome] = []
        let handoff = makeHandoff(
            registeredApplications: [URL(fileURLWithPath: "/Applications/KeyBrake.app")],
            openRoute: { _, _, completion in
                openCount += 1
                finishOpening = completion
            }
        )

        handoff.openKeyboardSettings { outcomes.append($0) }
        handoff.openKeyboardSettings { outcomes.append($0) }
        XCTAssertEqual(outcomes, [.failed(.duplicateInvocation)])
        XCTAssertEqual(openCount, 1)

        finishOpening?(.opened)
        XCTAssertEqual(outcomes, [.failed(.duplicateInvocation), .opened])

        handoff.openKeyboardSettings { outcomes.append($0) }
        XCTAssertEqual(outcomes.last, .opened)
        XCTAssertEqual(openCount, 2)
    }

    private func makeHandoff(
        hostBundleIdentifier: String? = "org.example.KeyBrake",
        registeredApplications: [URL] = [],
        runningApplications: [KeyBrakeSystemSettingsHandoff.RunningApplication] = [],
        keyboardRouteIsSupported: Bool = true,
        openRoute: @escaping KeyBrakeSystemSettingsHandoff.RouteOpener = { _, _, completion in completion(.opened) }
    ) -> KeyBrakeSystemSettingsHandoff {
        KeyBrakeSystemSettingsHandoff(
            hostBundleIdentifier: hostBundleIdentifier,
            registeredApplicationResolver: { _ in registeredApplications },
            runningApplicationResolver: { _ in runningApplications },
            keyboardRouteSupportChecker: { _ in keyboardRouteIsSupported },
            routeOpener: openRoute
        )
    }
}
