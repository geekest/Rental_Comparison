import Foundation

enum ImportURLRouter {
    static let scheme = "rentalcomparison"

    static func hostAppURL(for sharedURL: URL) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "import"
        components.queryItems = [URLQueryItem(name: "url", value: sharedURL.absoluteString)]
        return components.url
    }

    static func sharedURL(from appURL: URL) -> URL? {
        guard appURL.scheme == scheme, appURL.host == "import",
              let value = URLComponents(url: appURL, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "url" })?.value,
              let url = URL(string: value), url.scheme == "http" || url.scheme == "https" else { return nil }
        return url
    }
}
