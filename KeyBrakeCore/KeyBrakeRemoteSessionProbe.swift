import Darwin
import Foundation

public enum KeyBrakeRemoteSessionProbe {
    public static func currentNotice() -> KeyBrakeRemoteSessionNotice? {
        KeyBrakeRemoteSessionNotice.notice(
            loginHosts: currentLoginHosts(),
            screenSharingConnected: screenSharingDaemonIsRunning()
        )
    }

    public static func currentLoginHosts(userName: String = NSUserName()) -> [String] {
        var hosts: [String] = []
        let environment = ProcessInfo.processInfo.environment
        if let ssh = environment["SSH_CONNECTION"] ?? environment["SSH_CLIENT"] {
            let host = ssh.split(whereSeparator: { $0 == " " || $0 == "\t" }).first.map(String.init) ?? ""
            if !host.isEmpty {
                hosts.append(host)
            }
        }
        setutxent()
        defer { endutxent() }
        while let entry = getutxent() {
            guard entry.pointee.ut_type == USER_PROCESS else { continue }
            let recordUser = cString(entry.pointee.ut_user)
            guard recordUser == userName else { continue }
            let host = cString(entry.pointee.ut_host)
            if !host.isEmpty {
                hosts.append(host)
            }
        }
        return hosts
    }

    public static func screenSharingDaemonIsRunning() -> Bool {
        let bufferSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard bufferSize > 0 else { return false }
        let count = Int(bufferSize) / MemoryLayout<pid_t>.size
        var pids = [pid_t](repeating: 0, count: max(count, 1))
        let written = pids.withUnsafeMutableBufferPointer { buffer in
            proc_listpids(UInt32(PROC_ALL_PIDS), 0, buffer.baseAddress, Int32(bufferSize))
        }
        guard written > 0 else { return false }
        let available = min(pids.count, Int(written) / MemoryLayout<pid_t>.size)
        for pid in pids.prefix(available) where pid > 0 {
            var path = [CChar](repeating: 0, count: Int(MAXPATHLEN))
            let length = proc_pidpath(pid, &path, UInt32(path.count))
            guard length > 0 else { continue }
            let bytes = path.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
            if String(decoding: bytes, as: UTF8.self).hasSuffix("/screensharingd") {
                return true
            }
        }
        return false
    }

    private static func cString<T>(_ value: T) -> String {
        withUnsafePointer(to: value) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: MemoryLayout<T>.size) {
                String(cString: $0)
            }
        }
    }
}
