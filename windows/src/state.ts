// Tracks live agent sessions and derives the pet's current state + bubble line.
// Mirrors the macOS app: highest-priority state wins; done sessions linger
// briefly then drop so the pet returns to idle.

export interface Session {
  agent: string;
  session: string;
  state: string;
  project: string;
  message: string;
  tool: string;
  updatedAt: number;
  stateSince: number;
}

const PRIORITY: Record<string, number> = { working: 4, waiting: 3, done: 2, registered: 1, idle: 0 };
// Timeouts mirror the macOS SessionStore: done sessions linger briefly, then
// drop; sessions that go quiet are removed (the agent died without a Stop).
const DONE_LINGER_MS = 30_000;
const STALE_ACTIVE_MS = 300_000;
const STALE_REGISTERED_MS = 90_000;

export class SessionStore {
  private sessions = new Map<string, Session>();

  update(e: { agent: string; state: string; session: string; project: string; message: string; tool?: string }) {
    const key = `${e.agent}:${e.session}`;
    const now = Date.now();
    const prev = this.sessions.get(key);
    this.sessions.set(key, {
      agent: e.agent, session: e.session, state: e.state, project: e.project,
      message: e.message, tool: e.tool ?? "", updatedAt: now,
      stateSince: prev && prev.state === e.state ? prev.stateSince : now,
    });
  }

  remove(session: string) {
    for (const k of [...this.sessions.keys()]) {
      if (k.endsWith(`:${session}`)) this.sessions.delete(k);
    }
  }

  /// Drop done/stale sessions; returns the active list (highest priority first).
  active(): Session[] {
    const now = Date.now();
    for (const [k, s] of [...this.sessions]) {
      const quiet = now - s.updatedAt;
      if (s.state === "done" && quiet > DONE_LINGER_MS) this.sessions.delete(k);
      else if (s.state === "registered" && quiet > STALE_REGISTERED_MS) this.sessions.delete(k);
      else if ((s.state === "working" || s.state === "waiting") && quiet > STALE_ACTIVE_MS) this.sessions.delete(k);
    }
    return [...this.sessions.values()].sort(
      (a, b) => (PRIORITY[b.state] ?? 0) - (PRIORITY[a.state] ?? 0) || b.updatedAt - a.updatedAt
    );
  }

  topState(): string {
    return this.active()[0]?.state ?? "idle";
  }
}
