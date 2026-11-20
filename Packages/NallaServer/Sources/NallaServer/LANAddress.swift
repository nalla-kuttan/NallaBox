import Darwin

public enum LANAddress {
    /// This device's best IPv4 address for phones on the same network.
    public static func current() -> String? {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return nil }
        defer { freeifaddrs(list) }
        var out: [(name: String, address: String)] = []
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let ifa = ptr.pointee
            guard let sa = ifa.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET),
                  (ifa.ifa_flags & UInt32(IFF_UP)) != 0, (ifa.ifa_flags & UInt32(IFF_RUNNING)) != 0 else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(sa, socklen_t(sa.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 else { continue }
            out.append((String(cString: ifa.ifa_name), String(decoding: host.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)))
        }
        return pick(out)
    }

    /// Prefers Wi-Fi/Ethernet (en0, then en1), then any private-range address (Personal Hotspot is bridge100),
    /// then anything else. Never loopback or link-local.
    public static func pick(_ candidates: [(name: String, address: String)]) -> String? {
        let usable = candidates.filter { !$0.address.hasPrefix("127.") && !$0.address.hasPrefix("169.254.") && $0.address.contains(".") }
        func rank(_ c: (name: String, address: String)) -> Int {
            if c.name == "en0" { return 0 }
            if c.name == "en1" { return 1 }
            if isPrivate(c.address) { return 2 }
            return 3
        }
        return usable.min { rank($0) < rank($1) }?.address
    }

    static func isPrivate(_ ip: String) -> Bool {
        let o = ip.split(separator: ".").compactMap { Int($0) }
        guard o.count == 4 else { return false }
        return o[0] == 10 || (o[0] == 172 && (16...31).contains(o[1])) || (o[0] == 192 && o[1] == 168)
    }
}
