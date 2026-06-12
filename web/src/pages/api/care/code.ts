import type { APIRoute } from "astro";
import { env } from "cloudflare:workers";
import { verifySession, SESSION_COOKIE } from "../../../lib/auth";
import { getDB, ensureSchema } from "../../../lib/db";

export const prerender = false;

const v = (n: string): string => {
  try { const e = (env as any)?.[n]; if (e) return String(e); } catch {}
  return (import.meta as any).env?.[n] ?? "";
};

// No 0/O or 1/I — the user types this into the app by hand.
const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

// Issues a short-lived pairing code for the signed-in user. The desktop app
// exchanges it for a device token at /api/care/pair.
export const POST: APIRoute = async ({ cookies }) => {
  const token = cookies.get(SESSION_COOKIE)?.value || "";
  const user = token ? await verifySession(token, v("SESSION_SECRET")) : null;
  if (!user) return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401 });

  const db = getDB();
  if (!db) return new Response(JSON.stringify({ error: "no db" }), { status: 500 });
  await ensureSchema(db);

  const bytes = new Uint8Array(6);
  crypto.getRandomValues(bytes);
  const code = Array.from(bytes, (b) => ALPHABET[b % ALPHABET.length]).join("");
  const now = Date.now();

  await db.batch([
    // One pending code per user; issuing a new one invalidates the old.
    db.prepare("DELETE FROM care_pair_codes WHERE user_id=? OR expires_at<?").bind(user.id, now),
    db.prepare("INSERT INTO care_pair_codes (code, user_id, expires_at) VALUES (?,?,?)")
      .bind(code, user.id, now + 10 * 60 * 1000),
  ]);

  return new Response(JSON.stringify({ code, expiresInSeconds: 600 }), {
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });
};
