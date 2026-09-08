import Foundation

// R3.5.22.3.1 — single native API environment/configuration owner.
enum NUVORIEnvironment {
    static var apiBaseURL: URL {
        let configured = (Bundle.main.object(forInfoDictionaryKey: "NUVORI_API_BASE_URL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let configured, !configured.isEmpty, let url = URL(string: configured), isAllowed(url) {
            return url
        }

        #if DEBUG
        return URL(string: "http://127.0.0.1:8765")!
        #else
        preconditionFailure("NUVORI_API_BASE_URL must be configured with a valid HTTPS URL for Release.")
        #endif
    }

    private static func isAllowed(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), url.host != nil else { return false }

        #if DEBUG
        if scheme == "https" { return true }
        if scheme == "http" {
            let host = url.host?.lowercased() ?? ""
            return host == "127.0.0.1" || host == "localhost" || host == "::1"
        }
        return false
        #else
        return scheme == "https"
        #endif
    }
}
