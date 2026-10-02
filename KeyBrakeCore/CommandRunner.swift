import Darwin
import Foundation

public struct CommandRequest: Sendable, Equatable {
    public let executableURL: URL
    public let arguments: [String]
    public let environment: [String: String]
    public let timeout: Duration
    public let outputLimitBytes: Int

    public init(executableURL: URL, arguments: [String] = [], environment: [String: String] = [:], timeout: Duration = .seconds(15), outputLimitBytes: Int = 32 * 1024) {
        precondition(executableURL.isFileURL && executableURL.path.hasPrefix("/"), "Command executables must be absolute file URLs")
        self.executableURL = executableURL
        self.arguments = arguments
        self.environment = environment
        self.timeout = timeout
        self.outputLimitBytes = max(256, outputLimitBytes)
    }
}

public struct CommandResult: Sendable, Equatable {
    public let terminationStatus: Int32
    public let standardOutput: Data
    public let standardError: Data
    public let timedOut: Bool
    public let startedAt: Date
    public let finishedAt: Date

    public init(terminationStatus: Int32, standardOutput: Data, standardError: Data, timedOut: Bool, startedAt: Date, finishedAt: Date) {
        self.terminationStatus = terminationStatus
        self.standardOutput = standardOutput
        self.standardError = standardError
        self.timedOut = timedOut
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }

    public var sanitizedStandardError: String {
        let value = String(decoding: standardError, as: UTF8.self)
        return value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(2_000)
            .description
    }
}

public protocol CommandRunning: Sendable {
    func run(_ request: CommandRequest) async throws -> CommandResult
}

public enum CommandRunnerError: Error, LocalizedError, Sendable {
    case launchFailed(String)
    case timedOut

    public var errorDescription: String? {
        switch self {
        case .launchFailed(let message): return message
        case .timedOut: return "Command timed out"
        }
    }
}

public final class ProcessCommandRunner: CommandRunning, @unchecked Sendable {
    public init() {}

    public func run(_ request: CommandRequest) async throws -> CommandResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let startedAt = Date()
                let process = Process()
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.executableURL = request.executableURL
                process.arguments = request.arguments
                process.environment = request.environment.isEmpty ? nil : request.environment
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: CommandRunnerError.launchFailed(error.localizedDescription))
                    return
                }

                let outputCollector = BoundedDataCollector(limit: request.outputLimitBytes)
                let errorCollector = BoundedDataCollector(limit: request.outputLimitBytes)
                let drainGroup = DispatchGroup()
                Self.drain(outputPipe.fileHandleForReading, into: outputCollector, group: drainGroup)
                Self.drain(errorPipe.fileHandleForReading, into: errorCollector, group: drainGroup)

                let timeoutSeconds = Double(request.timeout.components.seconds) + Double(request.timeout.components.attoseconds) / 1_000_000_000_000_000_000
                let deadline = Date().addingTimeInterval(max(0.1, timeoutSeconds))
                while process.isRunning && Date() < deadline {
                    Thread.sleep(forTimeInterval: 0.01)
                }
                let timedOut = process.isRunning
                if timedOut {
                    process.terminate()
                    let terminateDeadline = Date().addingTimeInterval(0.5)
                    while process.isRunning && Date() < terminateDeadline {
                        Thread.sleep(forTimeInterval: 0.01)
                    }
                    if process.isRunning {
                        _ = kill(process.processIdentifier, SIGKILL)
                    }
                }
                process.waitUntilExit()
                drainGroup.wait()
                let result = CommandResult(
                    terminationStatus: process.terminationStatus,
                    standardOutput: outputCollector.data,
                    standardError: errorCollector.data,
                    timedOut: timedOut,
                    startedAt: startedAt,
                    finishedAt: Date()
                )
                continuation.resume(returning: result)
            }
        }
    }

    private static func drain(_ handle: FileHandle, into collector: BoundedDataCollector, group: DispatchGroup) {
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            defer { group.leave() }
            while true {
                let chunk = handle.readData(ofLength: 16 * 1024)
                if chunk.isEmpty { break }
                collector.append(chunk)
            }
        }
    }
}

private final class BoundedDataCollector: @unchecked Sendable {
    private let lock = NSLock()
    private let limit: Int
    private var storage = Data()

    init(limit: Int) {
        self.limit = max(256, limit)
    }

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ chunk: Data) {
        lock.lock()
        defer { lock.unlock() }
        guard storage.count < limit else { return }
        storage.append(chunk.prefix(limit - storage.count))
    }
}

public final class RecordingCommandRunner: CommandRunning, @unchecked Sendable {
    public struct Call: Sendable, Equatable {
        public let request: CommandRequest
        public init(request: CommandRequest) { self.request = request }
    }

    private let lock = NSLock()
    private var queuedResults: [Result<CommandResult, Error>]
    private var recordedCalls: [Call] = []

    public init(results: [Result<CommandResult, Error>] = []) {
        self.queuedResults = results
    }

    public var calls: [Call] {
        lock.lock(); defer { lock.unlock() }
        return recordedCalls
    }

    public func enqueue(_ result: Result<CommandResult, Error>) {
        lock.lock(); defer { lock.unlock() }
        queuedResults.append(result)
    }

    public func run(_ request: CommandRequest) async throws -> CommandResult {
        let next = recordAndDequeue(request)
        if let next { return try next.get() }
        throw CommandRunnerError.launchFailed("RecordingCommandRunner has no queued result for \(request.executableURL.path)")
    }

    private func recordAndDequeue(_ request: CommandRequest) -> Result<CommandResult, Error>? {
        lock.lock()
        recordedCalls.append(Call(request: request))
        let next = queuedResults.isEmpty ? nil : queuedResults.removeFirst()
        lock.unlock()
        return next
    }
}
