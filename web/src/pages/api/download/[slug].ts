import type { APIRoute } from "astro";
import { petsBase } from "../../../lib/pets";
import { getDB, ensureSchema, incrementDownload } from "../../../lib/db";

export const prerender = false;
const SLUG = /^[a-z0-9][a-z0-9._-]{0,80}$/i;

// Downloads a pet's spritesheet (as an attachment) and counts the download. Proxied
// so the origin stays hidden. ?kind=json downloads the pet.json instead.
export const GET: APIRoute = async ({ params, url }) => {
  const slug = params.slug ?? "";
  if (!SLUG.test(slug)) return new Response("bad request", { status: 400 });
  const base = petsBase();
  if (!base) return new Response("not configured", { status: 500 });

  const wantsJson = url.searchParams.get("kind") === "json";
  let upstream: Response, filename: string, ctype: string;
  if (wantsJson) {
    upstream = await fetch(`${base}/pets/${slug}/pet.json`);
    filename = `${slug}.pet.json`; ctype = "application/json";
  } else {
    upstream = await fetch(`${base}/pets/${slug}/spritesheet.webp`);
    let ext = "webp";
    if (!upstream.ok) { upstream = await fetch(`${base}/pets/${slug}/spritesheet.png`); ext = "png"; }
    filename = `${slug}.${ext}`; ctype = upstream.headers.get("content-type") || (ext === "png" ? "image/png" : "image/webp");
  }
  if (!upstream.ok) return new Response("not found", { status: upstream.status });

  const db = getDB();
  if (db) { await ensureSchema(db); await incrementDownload(db, slug); }

  return new Response(upstream.body, {
    headers: {
      "content-type": ctype,
      "content-disposition": `attachment; filename="${filename}"`,
      "cache-control": "no-store",
    },
  });
};
