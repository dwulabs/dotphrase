import Foundation

enum Log {
    static let path = "/tmp/dotphrase.log"

    static func write(_ line: String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        let msg = "\(ts) \(line)\n"
        if let data = msg.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: path) {
                if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
                    try? handle.seekToEnd()
                    try? handle.write(contentsOf: data)
                    try? handle.close()
                    return
                }
            }
            try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }
}
