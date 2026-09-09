import XCTest
@testable import KeyBrakeCore

final class CommandRunnerTests: XCTestCase {
    func testRecordingRunnerPreservesAbsoluteExecutableAndArgumentArray() async throws {
        let runner = RecordingCommandRunner()
        _ = try await runner.run(CommandRequest(executableURL: URL(fileURLWithPath: "/usr/bin/true"), arguments: ["value with spaces", "é"], outputLimitBytes: 256))
        XCTAssertEqual(runner.calls.first?.request.executableURL.path, "/usr/bin/true")
        XCTAssertEqual(runner.calls.first?.request.arguments, ["value with spaces", "é"])
    }

    func testCommandResultSanitizesAndBoundsErrorForLog() {
        let result = CommandResult(terminationStatus: 1, standardOutput: Data(), standardError: Data((String(repeating: "x", count: 3_000) + "\n").utf8), timedOut: false, startedAt: Date(), finishedAt: Date())
        XCTAssertLessThanOrEqual(result.sanitizedStandardError.count, 2_000)
        XCTAssertFalse(result.sanitizedStandardError.contains("\n"))
    }
}
