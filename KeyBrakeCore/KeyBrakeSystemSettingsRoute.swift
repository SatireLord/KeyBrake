import Foundation

public enum KeyBrakeSystemSettingsRoute: Equatable, Sendable {
    case keyboard

    public static let canonicalKeyboardURL = URL(string: "keybrake://settings/keyboard")!

    public static func parse(_ url: URL) -> KeyBrakeSystemSettingsRoute? {
        guard url.absoluteString == canonicalKeyboardURL.absoluteString,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "keybrake",
              components.host == "settings",
              components.percentEncodedPath == "/keyboard",
              components.user == nil,
              components.password == nil,
              components.port == nil,
              components.percentEncodedQuery == nil,
              components.percentEncodedFragment == nil else {
            return nil
        }

        return .keyboard
    }
}
