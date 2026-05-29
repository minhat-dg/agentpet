import AgentPetCore
import Foundation

/// CLI helper invoked by agent hooks: `agentpet hook --event ... --session ...`.
enum HookCLI {
    static func run(arguments: [String]) -> Never {
        // Explicit flags win; otherwise fall back to a Claude Code hook payload
        // on stdin, so the installed hook can simply call `agentpet hook`.
        let now = Date()
        let event = HookArguments.parse(arguments).makeEvent(now: now)
            ?? ClaudeHookPayload.decode(from: FileHandle.standardInput.readDataToEndOfFile())?.makeEvent(now: now)

        guard let event else {
            FileHandle.standardError.write(Data(
                "usage: agentpet hook --event <name> --session <id> [--project <path>] [--agent <kind>] [--message <text>]\n         or pipe a Claude Code hook JSON payload on stdin\n".utf8
            ))
            exit(2)
        }
        EventSender.send(event, socketPath: AgentPetPaths.socketPath, queueDir: AgentPetPaths.queueDir)
        exit(0)
    }
}
