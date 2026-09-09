import Foundation

public enum KeyBrakeStorageError: Error, LocalizedError, Sendable {
    case invalidSchema
    case missingRecovery
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidSchema: return "The KeyBrake recovery schema is not supported."
        case .missingRecovery: return "No unresolved KeyBrake recovery exists."
        case .writeFailed(let message): return message
        }
    }
}

public final class RecoveryStore: @unchecked Sendable {
    public let rootDirectory: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(rootDirectory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.rootDirectory = rootDirectory ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("KeyBrake", isDirectory: true)
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
    }

    public var recoveryURL: URL { rootDirectory.appendingPathComponent("CurrentRecovery.json") }

    public func save(_ snapshot: RecoverySnapshot) throws {
        try atomicWrite(snapshot, to: recoveryURL)
    }

    public func load() throws -> RecoverySnapshot? {
        guard fileManager.fileExists(atPath: recoveryURL.path) else { return nil }
        let data = try Data(contentsOf: recoveryURL)
        let snapshot = try decoder.decode(RecoverySnapshot.self, from: data)
        guard snapshot.schemaVersion == 1 else { throw KeyBrakeStorageError.invalidSchema }
        return snapshot
    }

    public func clear() throws {
        guard fileManager.fileExists(atPath: recoveryURL.path) else { return }
        try fileManager.removeItem(at: recoveryURL)
    }

    private func atomicWrite<T: Encodable>(_ value: T, to destination: URL) throws {
        do {
            try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true, attributes: [FileAttributeKey.posixPermissions: 0o700])
            let data = try encoder.encode(value)
            let temporary = rootDirectory.appendingPathComponent(".\(destination.lastPathComponent).\(UUID().uuidString).tmp")
            try data.write(to: temporary, options: .atomic)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temporary.path)
            if fileManager.fileExists(atPath: destination.path) { try fileManager.removeItem(at: destination) }
            try fileManager.moveItem(at: temporary, to: destination)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
        } catch {
            throw KeyBrakeStorageError.writeFailed(error.localizedDescription)
        }
    }
}
