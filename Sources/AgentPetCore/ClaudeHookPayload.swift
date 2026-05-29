import Foundation

/// The JSON Claude Code writes to a hook's stdin. Only the fields AgentPet
/// needs are decoded; the rest are ignored.
public struct ClaudeHookPayload: Decodable, Equatable {
    public let sessionId: String?
    public let cwd: String?
    public let hookEventName: String?
    public let message: String?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case cwd
        case hookEventName = "hook_event_name"
        case message
    }

    public static func decode(from data: Data) -> ClaudeHookPayload? {
        try? JSONDecoder().decode(ClaudeHookPayload.self, from: data)
    }

    /// Builds an `AgentEvent` from the payload, or `nil` if the essential
    /// fields (session id and event name) are missing.
    public func makeEvent(now: Date) -> AgentEvent? {
        guard let sessionId, let hookEventName else { return nil }
        return AgentEvent(
            sessionId: sessionId, agentKind: .claude, eventName: hookEventName,
            project: cwd, message: message, timestamp: now
        )
    }
}
