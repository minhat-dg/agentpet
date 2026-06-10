//! The `agentpet hook --agent <kind>` command, run by each agent's hook. It
//! reads the agent's payload (explicit flags for the opencode plugin, otherwise
//! JSON on stdin), extracts the essentials, and POSTs them to the running app's
//! localhost listener. ALWAYS exits 0 so it never blocks an agent (Copilot
//! PreToolUse is fail-closed). If the app isn't running, the POST fails silently.

use serde_json::Value;
use std::io::{Read, Write};
use std::net::TcpStream;

pub fn run_hook(args: &[String]) {
    let agent = flag(args, "--agent").unwrap_or_else(|| "unknown".into());

    // Explicit flags win (opencode plugin + the run wrapper). `--event` carries a
    // normalised state directly there.
    if let Some(event) = flag(args, "--event") {
        post_and_exit(
            &agent,
            &event,
            &flag(args, "--session").unwrap_or_default(),
            &flag(args, "--project").unwrap_or_default(),
            &flag(args, "--message").unwrap_or_default(),
            "",
        );
    }

    // Otherwise decode the JSON the agent pipes on stdin. Field names vary by
    // agent (Claude/Codex/Gemini/Kiro/Copilot, Cursor, Windsurf, Antigravity),
    // so we try each convention.
    let mut buf = String::new();
    let _ = std::io::stdin().read_to_string(&mut buf);
    let v: Value = serde_json::from_str(&buf).unwrap_or(Value::Null);

    let event = first_str(&v, &["hook_event_name", "agent_action_name", "hookEventName", "eventName"]);
    let session = first_str(&v, &["session_id", "conversation_id", "trajectory_id", "sessionId", "conversationId"]);
    let project = first_str(&v, &["cwd", "projectRoot"])
        .or_else(|| {
            v.get("workspace_roots")
                .and_then(|a| a.as_array())
                .and_then(|a| a.first())
                .and_then(|x| x.as_str())
                .map(String::from)
        })
        .unwrap_or_default();
    let tool = first_str(&v, &["tool_name", "toolName"]).unwrap_or_default();
    let message = first_str(&v, &["message"])
        .or_else(|| tool_message(&tool, v.get("tool_input")))
        .unwrap_or_default();

    if session.as_deref().unwrap_or("").is_empty() && event.as_deref().unwrap_or("").is_empty() {
        std::process::exit(0); // nothing useful; never block the agent
    }
    post_and_exit(&agent, &event.unwrap_or_default(), &session.unwrap_or_default(), &project, &message, &tool);
}

/// Live-activity text from a tool-use hook (PreToolUse/PostToolUse), used when
/// the agent sent no explicit message. Mirrors the macOS app's activity
/// formatter in spirit: prefer the tool's own description, then the file being
/// touched, then just the tool name.
fn tool_message(tool: &str, input: Option<&Value>) -> Option<String> {
    if tool.is_empty() {
        return None;
    }
    if let Some(input) = input {
        if let Some(d) = input.get("description").and_then(|x| x.as_str()) {
            if !d.is_empty() {
                return Some(d.to_string());
            }
        }
        if let Some(p) = input.get("file_path").and_then(|x| x.as_str()) {
            if let Some(name) = p.rsplit(['/', '\\']).next().filter(|s| !s.is_empty()) {
                return Some(format!("{tool} · {name}"));
            }
        }
    }
    Some(format!("Using {tool}"))
}

fn post_and_exit(agent: &str, event: &str, session: &str, project: &str, message: &str, tool: &str) -> ! {
    let payload = serde_json::json!({
        "agent": agent, "event": event, "session": session, "project": project,
        "message": message, "tool": tool,
    })
    .to_string();
    let _ = post(&payload);
    std::process::exit(0);
}

fn flag(args: &[String], name: &str) -> Option<String> {
    let mut it = args.iter();
    while let Some(a) = it.next() {
        if a == name {
            return it.next().cloned();
        }
    }
    None
}

fn first_str(v: &Value, keys: &[&str]) -> Option<String> {
    for k in keys {
        if let Some(s) = v.get(*k).and_then(|x| x.as_str()) {
            if !s.is_empty() {
                return Some(s.to_string());
            }
        }
    }
    None
}

/// Minimal HTTP POST to the local listener, bounded by short timeouts so a hook
/// never hangs the agent that invoked it.
fn post(body: &str) -> std::io::Result<()> {
    use std::time::Duration;
    let addr = std::net::SocketAddr::from(([127, 0, 0, 1], crate::server::HOOK_PORT));
    let mut stream = TcpStream::connect_timeout(&addr, Duration::from_millis(500))?;
    stream.set_write_timeout(Some(Duration::from_millis(500)))?;
    stream.set_read_timeout(Some(Duration::from_millis(500)))?;
    let req = format!(
        "POST /event HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
        body.len(),
        body
    );
    stream.write_all(req.as_bytes())?;
    let mut _resp = String::new();
    let _ = stream.read_to_string(&mut _resp);
    Ok(())
}
