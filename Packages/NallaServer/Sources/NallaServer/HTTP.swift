import Foundation

public struct HTTPRequest: Equatable, Sendable {
    public var method: String
    public var path: String
    public var query: [String: String]
    public init(method: String, path: String, query: [String: String]) { self.method = method; self.path = path; self.query = query }

    public static let maxHead = 8192

    /// Parses the request line of an HTTP/1.x head. Nil when malformed or longer than 8 KB.
    public static func parse(_ head: Data) -> HTTPRequest? {
        guard head.count <= maxHead, let text = String(data: head, encoding: .utf8),
              let line = text.components(separatedBy: "\r\n").first else { return nil }
        let parts = line.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count == 3, parts[2].hasPrefix("HTTP/1."), parts[1].hasPrefix("/") else { return nil }
        let target = String(parts[1])
        let pieces = target.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        var query: [String: String] = [:]
        if pieces.count == 2 {
            for pair in pieces[1].split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                let key = String(kv[0]).removingPercentEncoding ?? String(kv[0])
                query[key] = kv.count > 1 ? (String(kv[1]).removingPercentEncoding ?? String(kv[1])) : ""
            }
        }
        return HTTPRequest(method: String(parts[0]), path: String(pieces[0]), query: query)
    }
}

public struct HTTPResponse: Sendable {
    public var status: Int
    public var headers: [(String, String)]
    public var body: Data

    public init(status: Int, headers: [(String, String)] = [], body: Data = Data()) {
        self.status = status; self.headers = headers; self.body = body
    }

    static let reasons = [200: "OK", 400: "Bad Request", 404: "Not Found", 405: "Method Not Allowed"]

    public func serialized() -> Data {
        var head = "HTTP/1.1 \(status) \(Self.reasons[status] ?? "Error")\r\n"
        for (k, v) in headers { head += "\(k): \(v)\r\n" }
        head += "Content-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        return Data(head.utf8) + body
    }

    static func text(_ status: Int, _ message: String) -> HTTPResponse {
        HTTPResponse(status: status, headers: [("Content-Type", "text/plain; charset=utf-8"), ("Cache-Control", "no-store")],
                     body: Data(message.utf8))
    }
}

/// Serves the bundled controller folder: GET only, `/` → index.html, no directory listing, nothing outside the root.
public enum StaticFiles {
    static let types: [String: String] = [
        "html": "text/html; charset=utf-8", "js": "text/javascript; charset=utf-8", "mjs": "text/javascript; charset=utf-8",
        "css": "text/css; charset=utf-8", "json": "application/json", "svg": "image/svg+xml", "png": "image/png",
        "woff2": "font/woff2", "ttf": "font/ttf", "ico": "image/x-icon", "txt": "text/plain; charset=utf-8",
    ]

    public static func response(for req: HTTPRequest, root: URL) -> HTTPResponse {
        guard req.method == "GET" || req.method == "HEAD" else { return .text(405, "Method not allowed") }
        guard let decoded = req.path.removingPercentEncoding else { return .text(404, "Not found") }
        let rel = decoded == "/" ? "index.html" : String(decoded.dropFirst())
        let components = rel.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.contains(where: { $0 == ".." || $0 == "." || $0.isEmpty }), !rel.contains("\\") else {
            return .text(404, "Not found")
        }
        let base = root.standardizedFileURL.resolvingSymlinksInPath()
        let url = base.appendingPathComponent(rel).standardizedFileURL.resolvingSymlinksInPath()
        guard url.path.hasPrefix(base.path + "/") else { return .text(404, "Not found") }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue,
              let body = try? Data(contentsOf: url) else { return .text(404, "Not found") }
        let type = types[url.pathExtension.lowercased()] ?? "application/octet-stream"
        return HTTPResponse(status: 200, headers: [("Content-Type", type), ("Cache-Control", "no-store"),
                                                   ("X-Content-Type-Options", "nosniff")],
                            body: req.method == "HEAD" ? Data() : body)
    }
}
