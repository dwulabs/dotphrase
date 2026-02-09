import Foundation

public struct Phrase: Codable, Equatable, Sendable {
    public let trigger: String
    public let body: String
    public let description: String?

    public init(trigger: String, body: String, description: String? = nil) {
        self.trigger = trigger
        self.body = body
        self.description = description
    }
}
