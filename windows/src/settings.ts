import { invoke } from "@tauri-apps/api/core";
import { emit } from "@tauri-apps/api/event";
import { enable, disable, isEnabled } from "@tauri-apps/plugin-autostart";
import { loadCatalog, savedSlug, saveSlug, type Pet } from "./catalog";
import { t, getLang, setLang, type Lang } from "./i18n";

// ---------------------------------------------------------------- agents ----
interface AgentInfo {
  kind: string;
  display_name: string;
  installed: boolean;
  note: string | null;
}

const agentsRoot = document.getElementById("agents")!;
let agentsCache: AgentInfo[] = [];

async function loadAgents() {
  agentsCache = await invoke<AgentInfo[]>("list_agents");
  renderAgents();
}

function renderAgents() {
  agentsRoot.innerHTML = "";
  for (const a of agentsCache) {
    const row = document.createElement("div");
    row.className = "agent-row";

    const meta = document.createElement("div");
    meta.className = "meta";
    const status = a.note
      ? `<div class="note">${esc(t(a.note))}</div>`
      : a.installed
      ? `<div class="ok">${esc(t("Hook installed"))}</div>`
      : "";
    meta.innerHTML = `<div class="name">${esc(a.display_name)}</div>${status}`;

    const btn = document.createElement("button");
    btn.textContent = a.installed ? t("Remove") : t("Install");
    if (a.installed) btn.classList.add("remove");
    btn.onclick = async () => {
      btn.disabled = true;
      try { await invoke("toggle_install", { kind: a.kind }); } catch (e) { alert(String(e)); }
      await loadAgents();
    };

    row.appendChild(meta);
    row.appendChild(btn);
    agentsRoot.appendChild(row);
  }
}

// ------------------------------------------------------------------ pet ----
const current = document.getElementById("pet-current") as HTMLDivElement;
const search = document.getElementById("pet-search") as HTMLInputElement;
const random = document.getElementById("pet-random") as HTMLButtonElement;
const results = document.getElementById("pet-results") as HTMLDivElement;

let catalog: Pet[] = [];
let currentPet: Pet | undefined;

async function pick(p: Pet) {
  saveSlug(p.slug);
  await emit("set-pet", { slug: p.slug, url: p.spritesheetUrl });
  currentPet = p;
  showCurrent();
  results.innerHTML = "";
  search.value = "";
}

function showCurrent() {
  if (!catalog.length) { current.textContent = t("Couldn't load pets , check your internet connection."); return; }
  current.textContent = `${t("Showing:")} ${currentPet ? currentPet.name : t("(default)")}`;
}

function renderResults(list: Pet[]) {
  results.innerHTML = "";
  for (const p of list.slice(0, 24)) {
    const item = document.createElement("button");
    item.className = "pet-item";
    const cv = document.createElement("canvas");
    cv.width = 44; cv.height = 44; cv.className = "pet-thumb";
    drawThumb(cv, p.spritesheetUrl);
    const label = document.createElement("span");
    label.textContent = p.name;
    item.appendChild(cv);
    item.appendChild(label);
    item.onclick = () => pick(p);
    results.appendChild(item);
  }
}

// Draws frame 0 (first column of the Idle row) of an 8x9 spritesheet as a preview.
function drawThumb(cv: HTMLCanvasElement, url: string) {
  const ctx = cv.getContext("2d");
  if (!ctx) return;
  ctx.imageSmoothingEnabled = false;
  const img = new Image();
  img.onload = () => {
    const fw = img.naturalWidth / 8, fh = img.naturalHeight / 9;
    if (!fw || !fh) return;
    const s = Math.min(cv.width / fw, cv.height / fh);
    const dw = fw * s, dh = fh * s;
    ctx.clearRect(0, 0, cv.width, cv.height);
    ctx.drawImage(img, 0, 0, fw, fh, (cv.width - dw) / 2, (cv.height - dh) / 2, dw, dh);
  };
  img.src = url;
}

async function initPet() {
  catalog = await loadCatalog();
  currentPet = catalog.find((p) => p.slug === savedSlug());
  showCurrent();
  search.addEventListener("input", () => {
    const q = search.value.trim().toLowerCase();
    if (!q) { results.innerHTML = ""; return; }
    renderResults(catalog.filter((p) => p.name.toLowerCase().includes(q)));
  });
  random.addEventListener("click", () => {
    if (catalog.length) pick(catalog[Math.floor(Math.random() * catalog.length)]);
  });
}

// ---------------------------------------------------------------- bubble ----
const MSG_STATES: [string, string][] = [
  ["working", "Working"], ["waiting", "Needs you"], ["done", "Done"], ["idle", "Idle"],
];
const MSG_AGENTS: [string, string][] = [
  ["all", "All agents"], ["claude", "Claude Code"], ["codex", "Codex"], ["gemini", "Gemini CLI"],
  ["cursor", "Cursor"], ["opencode", "opencode"], ["windsurf", "Windsurf"],
  ["antigravity", "Antigravity"], ["kiro", "Kiro CLI"], ["copilot", "GitHub Copilot"],
];

function initBubble() {
  const changed = () => { emit("bubble-changed", null); };
  const theme = document.getElementById("theme") as HTMLSelectElement;
  const opacity = document.getElementById("opacity") as HTMLInputElement;
  const fontSize = document.getElementById("font-size") as HTMLInputElement;
  const fontFamily = document.getElementById("font-family") as HTMLSelectElement;
  const msgAgent = document.getElementById("msg-agent") as HTMLSelectElement;
  const editors = document.getElementById("msg-editors")!;

  theme.value = localStorage.getItem("ap_theme") || "dark";
  opacity.value = localStorage.getItem("ap_opacity") || "92";
  fontSize.value = localStorage.getItem("ap_font_size") || "12";
  fontFamily.value = localStorage.getItem("ap_font_family") || "system";

  theme.onchange = () => { localStorage.setItem("ap_theme", theme.value); changed(); };
  opacity.oninput = () => { localStorage.setItem("ap_opacity", opacity.value); changed(); };
  fontSize.oninput = () => { localStorage.setItem("ap_font_size", fontSize.value); changed(); };
  fontFamily.onchange = () => { localStorage.setItem("ap_font_family", fontFamily.value); changed(); };

  msgAgent.innerHTML = "";
  for (const [k, name] of MSG_AGENTS) {
    const o = document.createElement("option");
    o.value = k;
    o.textContent = k === "all" ? t("All agents") : name; // brand names stay
    msgAgent.appendChild(o);
  }

  const build = (agent: string) => {
    editors.innerHTML = "";
    for (const [st, label] of MSG_STATES) {
      const wrap = document.createElement("div");
      wrap.className = "msg-editor";
      const lbl = document.createElement("div");
      lbl.className = "msg-label";
      lbl.dataset.label = label;
      lbl.textContent = t(label);
      const ta = document.createElement("textarea");
      const key = `ap_msg_${agent}_${st}`;
      ta.value = localStorage.getItem(key) || "";
      ta.addEventListener("input", () => { localStorage.setItem(key, ta.value); changed(); });
      wrap.appendChild(lbl);
      wrap.appendChild(ta);
      editors.appendChild(wrap);
    }
  };
  msgAgent.onchange = () => build(msgAgent.value);
  build("all");
}

// --------------------------------------------------------- notifications ----
function initNotify() {
  const box = document.getElementById("notify") as HTMLInputElement;
  box.checked = localStorage.getItem("ap_notify") !== "0";
  box.addEventListener("change", () => localStorage.setItem("ap_notify", box.checked ? "1" : "0"));
}

// --------------------------------------------------------------- startup ----
async function initAutostart() {
  const box = document.getElementById("autostart") as HTMLInputElement;
  try { box.checked = await isEnabled(); } catch {}
  box.addEventListener("change", async () => {
    try { box.checked ? await enable() : await disable(); } catch (e) { alert(String(e)); }
  });
}

// ----------------------------------------------------------------- i18n ----
function applyStatic() {
  document.documentElement.lang = getLang();
  const set = (id: string, key: string) => { const el = document.getElementById(id); if (el) el.textContent = t(key); };
  set("t-pet", "Your pet");
  set("t-pet-sub", "Pick the companion that floats on your desktop.");
  set("t-bubble", "Bubble");
  set("t-theme", "Theme");
  set("t-opacity", "Opacity");
  set("t-msg-help", "Custom messages (one per line, leave empty for default)");
  set("o-dark", "Dark");
  set("o-light", "Light");
  set("t-fontsize", "Text size");
  set("t-font", "Font");
  set("o-system", "System");
  set("o-rounded", "Rounded");
  set("o-mono", "Monospace");
  set("t-msg-agent", "For agent");
  const allOpt = document.querySelector<HTMLOptionElement>('#msg-agent option[value="all"]');
  if (allOpt) allOpt.textContent = t("All agents");
  document.querySelectorAll<HTMLElement>(".msg-label").forEach((el) => {
    if (el.dataset.label) el.textContent = t(el.dataset.label);
  });
  set("t-agents", "Agent integrations");
  set("t-agents-sub", "Install a hook so AgentPet can see when an agent works, finishes, or needs you.");
  set("t-notif", "Notifications");
  set("t-notify", "Notify when an agent finishes or needs you");
  set("t-startup", "Startup");
  set("t-autostart", "Start AgentPet when Windows starts");
  search.placeholder = t("Search pets by name...");
}

function initLang() {
  const sel = document.getElementById("lang") as HTMLSelectElement;
  sel.value = getLang();
  applyStatic();
  // Tell the tray (Rust) + the pet window about the initial language too.
  invoke("set_lang", { code: getLang() }).catch(() => {});
  sel.addEventListener("change", async () => {
    setLang(sel.value as Lang);
    applyStatic();
    renderAgents();
    showCurrent();
    invoke("set_lang", { code: getLang() }).catch(() => {});
    await emit("lang-changed", getLang());
  });
}

function esc(s: string): string {
  return s.replace(/[&<>]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;" }[c] || c));
}

initLang();
loadAgents();
initPet();
initBubble();
initNotify();
initAutostart();
