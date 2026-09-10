import XCTest
@testable import KeyBrakeCore

final class CommandRunnerTests: XCTestCase {
    func testRecordingRunnerPreservesAbsoluteExecutableAndArgumentArray() async throws {
        let runner = RecordingCommandRunner()
        runner.enqueue(.success(CommandResult(terminationStatus: 0, standardOutput: Data(), standardError: Data(), timedOut: false, startedAt: Date(), finishedAt: Date())))
        _ = try await runner.run(CommandRequest(executableURL: URL(fileURLWithPath: "/usr/bin/true"), arguments: ["value with spaces", "é"], outputLimitBytes: 256))
        XCTAssertEqual(runner.calls.first?.request.executableURL.path, "/usr/bin/true")
        XCTAssertEqual(runner.calls.first?.request.arguments, ["value with spaces", "é"])
    }

    func testRecordingRunnerFailsWhenNoQueuedResult() async {
        let runner = RecordingCommandRunner()
        do {
            _ = try await runner.run(CommandRequest(executableURL: URL(fileURLWithPath: "/usr/bin/false")))
            XCTFail("Expected missing queued result to fail")
        } catch CommandRunnerError.launchFailed(let message) {
            XCTAssertTrue(message.contains("no queued result"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCommandResultSanitizesAndBoundsErrorForLog() {
        let result = CommandResult(terminationStatus: 1, standardOutput: Data(), standardError: Data((String(repeating: "x", count: 3_000) + "\n").utf8), timedOut: false, startedAt: Date(), finishedAt: Date())
        XCTAssertLessThanOrEqual(result.sanitizedStandardError.count, 2_000)
        XCTAssertFalse(result.sanitizedStandardError.contains("\n"))
    }

    func testProcessRunnerDrainsLargeOutputWithoutExceedingBound() async throws {
        let request = CommandRequest(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "head -c 100000 /dev/zero"],
            timeout: .seconds(2),
            outputLimitBytes: 256
        )

        let result = try await ProcessCommandRunner().run(request)

        XCTAssertEqual(result.terminationStatus, 0)
        XCTAssertFalse(result.timedOut)
        XCTAssertEqual(result.standardOutput.count, 256)
    }

    func testProcessRunnerTerminatesTimedOutCommand() async throws {
        let request = CommandRequest(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "sleep 2"],
            timeout: .milliseconds(100)
        )

        let result = try await ProcessCommandRunner().run(request)

        XCTAssertTrue(result.timedOut)
        XCTAssertNotEqual(result.terminationStatus, 0)
    }
}
