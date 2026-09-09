import Foundation

public final class IncidentStore: @unchecked Sendable {
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

    public var incidentsDirectory: URL { rootDirectory.appendingPathComponent("Incidents", isDirectory: true) }

    public func save(_ incident: IncidentRecord) throws {
        try fileManager.createDirectory(at: incidentsDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let data = try encoder.encode(incident)
        let destination = incidentsDirectory.appendingPathComponent("\(incident.id.uuidString).json")
        let temporary = incidentsDirectory.appendingPathComponent(".\(incident.id.uuidString).tmp")
        try data.write(to: temporary, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temporary.path)
        if fileManager.fileExists(atPath: destination.path) { try fileManager.removeItem(at: destination) }
        try fileManager.moveItem(at: temporary, to: destination)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
    }

    public func list() throws -> [IncidentRecord] {
        guard fileManager.fileExists(atPath: incidentsDirectory.path) else { return [] }
        return try fileManager.contentsOfDirectory(at: incidentsDirectory, includingPropertiesForKeys: [.contentModificationDateKey])
            .filter { $0.pathExtension == "json" }
            .compactMap { try? decoder.decode(IncidentRecord.self, from: Data(contentsOf: $0)) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public func clearResolvedHistory() throws {
        for incident in try list() where incident.finalState == .normal {
            let url = incidentsDirectory.appendingPathComponent("\(incident.id.uuidString).json")
            try fileManager.removeItem(at: url)
        }
    }

    public func render(_ incident: IncidentRecord) -> [String] {
        incident.steps.sorted { $0.startedAt < $1.startedAt }.map { step in
            let time = ISO8601DateFormatter().string(from: step.startedAt)
            return "\(time) \(step.targetDisplayName): \(step.operationDescription) [\(step.outcome.rawValue)]"
        }
    }
}
