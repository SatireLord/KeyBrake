import Foundation

public struct EspansoAdapter: Sendable {
    private let commandRunner: CommandRunning
    private let executableCandidates: [URL]

    public init(commandRunner: CommandRunning, executableCandidates: [URL] = EspansoAdapter.defaultExecutableCandidates) {
        self.commandRunner = commandRunner
        self.executableCandidates = executableCandidates
    }

    public static let defaultExecutableCandidates: [URL] = [
        URL(fileURLWithPath: "/opt/homebrew/bin/espanso"),
        URL(fileURLWithPath: "/usr/local/bin/espanso"),
        URL(fileURLWithPath: "/usr/bin/espanso"),
    ]

    public static func isInstalled(
        candidates: [URL] = defaultExecutableCandidates,
        isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) -> Bool {
        candidates.contains { isExecutable($0.path) }
    }

    public func resolveExecutable() -> URL? {
        executableCandidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    public func run(arguments: [String], description: String) async -> OperationStepResult {
        guard let executable = resolveExecutable() else {
            return OperationStepResult(subsystem: "localAutomation", targetID: "espanso", targetDisplayName: "Espanso", requestedState: description, operationDescription: "Espanso executable unavailable", outcome: .skipped)
        }
        let startedAt = Date()
        do {
            let result = try await commandRunner.run(CommandRequest(executableURL: executable, arguments: arguments))
            let outcome: OperationOutcome = result.terminationStatus == 0 && !result.timedOut ? .succeeded : .failed
            return OperationStepResult(subsystem: "localAutomation", targetID: "espanso", targetDisplayName: "Espanso", requestedState: description, operationDescription: "espanso " + arguments.joined(separator: " "), outcome: outcome, terminationStatus: result.terminationStatus, sanitizedStandardError: result.sanitizedStandardError, startedAt: startedAt, finishedAt: result.finishedAt)
        } catch {
            return OperationStepResult(subsystem: "localAutomation", targetID: "espanso", targetDisplayName: "Espanso", requestedState: description, operationDescription: error.localizedDescription, outcome: .failed, sanitizedStandardError: error.localizedDescription, startedAt: startedAt, finishedAt: Date())
        }
    }

    public func stop() async -> [OperationStepResult] {
        [await run(arguments: ["cmd", "disable"], description: "expansions disabled"), await run(arguments: ["stop"], description: "stopped")]
    }

    public func start() async -> OperationStepResult { await run(arguments: ["start"], description: "started") }
    public func restart() async -> OperationStepResult { await run(arguments: ["restart"], description: "restarted") }
    public func status() async -> OperationStepResult { await run(arguments: ["status"], description: "status verified") }
}
