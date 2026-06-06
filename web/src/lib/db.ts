import { env } from "cloudflare:workers";

// D1 access. Binding `DB` comes from wrangler.jsonc (local in dev via platformProxy,
// real database in prod). Returns null if the binding isn't available.
export function getDB(): any {
  try {
    return (env as any)?.DB ?? null;
  } catch {
    return null;
  }
}

let ready = false;

// Idempotent schema bootstrap, avoids a separate migration step in dev. Cheap and
// safe to call before each query (cached per isolate after the first run).
export async function ensureSchema(db: any): Promise<void> {
  if (ready || !db) return;
  await db
    .prepare(
      "CREATE TABLE IF NOT EXISTS pet_likes (slug TEXT NOT NULL, user_id INTEGER NOT NULL, created_at INTEGER NOT NULL, PRIMARY KEY (slug, user_id))"
    )
    .run();
  ready = true;
}
