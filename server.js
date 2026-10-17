const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const { URL } = require("node:url");

const ROOT = __dirname;

function loadEnv() {
  const file = path.join(ROOT, ".env");
  if (!fs.existsSync(file)) return;
  for (const line of fs.readFileSync(file, "utf8").split(/\r?\n/)) {
    const match = line.match(/^([^#=]+)=(.*)$/);
    if (match && !process.env[match[1].trim()]) process.env[match[1].trim()] = match[2].trim();
  }
}

loadEnv();

const PUBLIC_DIR = path.join(ROOT, "public");
const DATA_FILE = process.env.KEYS_FILE || path.join(ROOT, "keys.json");
const PORT = Number(process.env.PORT || process.env.API_PORT || 3000);
const KEY_SECRET = String(process.env.KEY_SECRET || "change-this-secret");
const ADMIN_SECRET = String(process.env.ADMIN_SECRET || KEY_SECRET);
const SUPABASE_URL = String(process.env.SUPABASE_URL || "").trim().replace(/\/$/, "");
const SUPABASE_SECRET_KEY = String(process.env.SUPABASE_SECRET_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || "").trim();
const sessions = new Map();

function readDatabase() {
  if (!fs.existsSync(DATA_FILE)) return {};
  try { return JSON.parse(fs.readFileSync(DATA_FILE, "utf8")); } catch { return {}; }
}

const database = readDatabase();
const remoteDatabaseEnabled = Boolean(SUPABASE_URL && SUPABASE_SECRET_KEY);
let persistenceQueue = Promise.resolve();

async function supabaseRequest(resource, options = {}) {
  const response = await fetch(`${SUPABASE_URL}${resource}`, {
    ...options,
    headers: {
      apikey: SUPABASE_SECRET_KEY,
      Authorization: `Bearer ${SUPABASE_SECRET_KEY}`,
      "Content-Type": "application/json",
      ...(options.headers || {})
    }
  });
  const text = await response.text();
  if (!response.ok) throw new Error(`Supabase HTTP ${response.status}: ${text.slice(0, 300)}`);
  return text ? JSON.parse(text) : null;
}

async function syncDatabase() {
  if (!remoteDatabaseEnabled) return;
  const rows = Object.entries(database).map(([id, payload]) => ({ id, payload }));
  if (!rows.length) return;
  await supabaseRequest("/rest/v1/murketa_keys?on_conflict=id", {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates" },
    body: JSON.stringify(rows)
  });
}

async function removeRemoteRecord(id) {
  if (!remoteDatabaseEnabled) return;
  await supabaseRequest(`/rest/v1/murketa_keys?id=eq.${encodeURIComponent(id)}`, { method: "DELETE" });
}

function queuePersistence() {
  if (!remoteDatabaseEnabled) return;
  persistenceQueue = persistenceQueue
    .then(() => syncDatabase())
    .catch(error => console.error(`[MURKETA] Falha ao sincronizar Supabase: ${error.message}`));
}

async function flushPersistence() {
  await persistenceQueue;
}

async function hydrateDatabase() {
  if (!remoteDatabaseEnabled) {
    console.log("[MURKETA] Armazenamento: arquivo local");
    return;
  }

  const rows = await supabaseRequest("/rest/v1/murketa_keys?select=id,payload");
  if (rows.length > 0) {
    for (const row of rows) database[row.id] = row.payload;
    console.log(`[MURKETA] Armazenamento: Supabase (${rows.length} keys carregadas)`);
    return;
  }

  if (Object.keys(database).length > 0) {
    await syncDatabase();
    console.log(`[MURKETA] Migração inicial: ${Object.keys(database).length} keys enviadas ao Supabase`);
  } else {
    console.log("[MURKETA] Armazenamento: Supabase (vazio)");
  }
}

function save() {
  try {
    const temp = `${DATA_FILE}.tmp`;
    fs.writeFileSync(temp, JSON.stringify(database, null, 2));
    fs.renameSync(temp, DATA_FILE);
  } catch (error) {
    console.warn(`[MURKETA] Não foi possível salvar o arquivo local: ${error.message}`);
  }
  queuePersistence();
}

function digest(value) {
  return crypto.createHmac("sha256", KEY_SECRET).update(String(value)).digest("hex");
}

function equalSecret(a, b) {
  const left = Buffer.from(String(a));
  const right = Buffer.from(String(b));
  return left.length === right.length && crypto.timingSafeEqual(left, right);
}

function makeKey() {
  return `MURKETA-${crypto.randomBytes(5).toString("hex").toUpperCase()}-${crypto.randomBytes(5).toString("hex").toUpperCase()}`;
}

function parseDuration(value) {
  const text = String(value || "permanente").trim().toLowerCase();
  if (["permanente", "permanent", "0"].includes(text)) return null;
  const match = text.match(/^(\d+)\s*(m|h|d|w)$/);
  if (!match) return undefined;
  const amount = Number(match[1]);
  const factor = { m: 60000, h: 3600000, d: 86400000, w: 604800000 }[match[2]];
  return new Date(Date.now() + amount * factor).toISOString();
}

function remaining(expiresAt) {
  if (!expiresAt) return "Permanente";
  const ms = Date.parse(expiresAt) - Date.now();
  if (!Number.isFinite(ms) || ms <= 0) return "Expirada";
  let seconds = Math.ceil(ms / 1000);
  const days = Math.floor(seconds / 86400); seconds %= 86400;
  const hours = Math.floor(seconds / 3600); seconds %= 3600;
  const minutes = Math.floor(seconds / 60);
  const parts = [];
  if (days) parts.push(`${days}d`);
  if (hours || days) parts.push(`${hours}h`);
  if (minutes || hours || days) parts.push(`${minutes}min`);
  if (!parts.length) parts.push(`${seconds % 60}s`);
  return parts.join(" ");
}

function encrypt(value) {
  const iv = crypto.randomBytes(12);
  const key = crypto.createHash("sha256").update(KEY_SECRET).digest();
  const cipher = crypto.createCipheriv("aes-256-gcm", key, iv);
  const ciphertext = Buffer.concat([cipher.update(value, "utf8"), cipher.final()]);
  return { iv: iv.toString("base64"), tag: cipher.getAuthTag().toString("base64"), data: ciphertext.toString("base64") };
}

function decrypt(record) {
  if (!record.encryptedKey) return null;
  try {
    const key = crypto.createHash("sha256").update(KEY_SECRET).digest();
    const decipher = crypto.createDecipheriv("aes-256-gcm", key, Buffer.from(record.encryptedKey.iv, "base64"));
    decipher.setAuthTag(Buffer.from(record.encryptedKey.tag, "base64"));
    return Buffer.concat([decipher.update(Buffer.from(record.encryptedKey.data, "base64")), decipher.final()]).toString("utf8");
  } catch { return null; }
}

function updateExpired() {
  let changed = false;
  for (const record of Object.values(database)) {
    if (record.status === "active" && record.expiresAt && Date.now() >= Date.parse(record.expiresAt)) {
      record.status = "expired";
      changed = true;
    }
  }
  if (changed) save();
}

function publicRecord(id, record) {
  return {
    id,
    key: decrypt(record),
    prefix: record.prefix,
    clientName: record.clientName || "Sem cliente",
    owner: record.owner || "",
    status: record.status,
    duration: record.duration,
    expiresAt: record.expiresAt,
    remaining: remaining(record.expiresAt),
    createdAt: record.createdAt,
    lastSeen: record.lastSeen,
    hwidBound: Boolean(record.hwid)
  };
}

function listRecords(search = "") {
  updateExpired();
  const query = search.trim().toLowerCase();
  return Object.entries(database)
    .map(([id, record]) => publicRecord(id, record))
    .filter(record => !query || [record.key, record.prefix, record.clientName, record.owner, record.status].join(" ").toLowerCase().includes(query))
    .sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)));
}

function stats() {
  const records = listRecords();
  return {
    total: records.length,
    active: records.filter(record => record.status === "active").length,
    waiting: records.filter(record => record.status === "active" && !record.hwidBound).length,
    revoked: records.filter(record => record.status === "revoked").length,
    expired: records.filter(record => record.status === "expired").length
  };
}

function body(request) {
  return new Promise((resolve, reject) => {
    let raw = "";
    request.on("data", chunk => {
      raw += chunk;
      if (raw.length > 20000) request.destroy(new Error("request too large"));
    });
    request.on("end", () => { try { resolve(JSON.parse(raw || "{}")); } catch { reject(new Error("invalid json")); } });
    request.on("error", reject);
  });
}

function send(response, status, payload, headers = {}) {
  const content = typeof payload === "string" ? payload : JSON.stringify(payload);
  response.writeHead(status, { "Content-Type": "application/json; charset=utf-8", "Content-Length": Buffer.byteLength(content), ...headers });
  response.end(content);
}

function cookie(request, name) {
  const header = request.headers.cookie || "";
  return header.split(";").map(item => item.trim()).find(item => item.startsWith(`${name}=`))?.slice(name.length + 1);
}

function isAuthenticated(request) {
  const token = cookie(request, "murk_session");
  return Boolean(token && sessions.has(token) && sessions.get(token) > Date.now());
}

function requireAuth(request, response) {
  if (isAuthenticated(request)) return true;
  send(response, 401, { ok: false, error: "UNAUTHORIZED" });
  return false;
}

async function api(request, response, url) {
  if (request.method === "POST" && url.pathname === "/api/login") {
    const input = await body(request);
    if (!equalSecret(input.secret, ADMIN_SECRET)) return send(response, 401, { ok: false, error: "INVALID_SECRET" });
    const token = crypto.randomBytes(32).toString("hex");
    sessions.set(token, Date.now() + 12 * 60 * 60 * 1000);
    return send(response, 200, { ok: true }, { "Set-Cookie": `murk_session=${token}; HttpOnly; SameSite=Strict; Path=/; Max-Age=43200` });
  }

  if (request.method === "POST" && url.pathname === "/api/logout") {
    const token = cookie(request, "murk_session");
    if (token) sessions.delete(token);
    return send(response, 200, { ok: true }, { "Set-Cookie": "murk_session=; HttpOnly; SameSite=Strict; Path=/; Max-Age=0" });
  }

  if (!requireAuth(request, response)) return;

  if (request.method === "GET" && url.pathname === "/api/stats") return send(response, 200, { ok: true, stats: stats() });
  if (request.method === "GET" && url.pathname === "/api/keys") return send(response, 200, { ok: true, keys: listRecords(url.searchParams.get("search") || "") });

  if (request.method === "POST" && url.pathname === "/api/keys/generate") {
    const input = await body(request);
    const expiresAt = parseDuration(input.duration || "permanente");
    if (expiresAt === undefined) return send(response, 400, { ok: false, error: "INVALID_DURATION" });
    let key;
    do { key = makeKey(); } while (database[digest(key)]);
    database[digest(key)] = {
      encryptedKey: encrypt(key), prefix: key.slice(0, 15), clientName: String(input.clientName || "Sem cliente").slice(0, 80),
      owner: String(input.owner || "").slice(0, 80), status: "active", duration: String(input.duration || "permanente"), expiresAt,
      createdAt: new Date().toISOString(), hwid: null, boundAt: null, lastSeen: null
    };
    save();
    await flushPersistence();
    return send(response, 201, { ok: true, key: publicRecord(digest(key), database[digest(key)]) });
  }

  if (request.method === "POST" && url.pathname === "/api/keys/cleanup") {
    updateExpired();
    let removed = 0;
    const removedIds = [];
    for (const [id, record] of Object.entries(database)) {
      if (record.status === "expired" || record.status === "revoked") {
        delete database[id];
        removedIds.push(id);
        removed += 1;
      }
    }
    if (removed) {
      save();
      await flushPersistence();
      await Promise.all(removedIds.map(removeRemoteRecord));
    }
    return send(response, 200, { ok: true, removed });
  }

  const action = url.pathname.match(/^\/api\/keys\/([a-f0-9]{64})\/(revoke|reset|delete)$/);
  if (request.method === "POST" && action && database[action[1]]) {
    const record = database[action[1]];
    if (action[2] === "revoke") record.status = "revoked";
    else if (action[2] === "reset") { record.hwid = null; record.boundAt = null; }
    else {
      if (record.status === "active") return send(response, 400, { ok: false, error: "ACTIVE_KEY" });
      delete database[action[1]];
      save();
      await flushPersistence();
      await removeRemoteRecord(action[1]);
      return send(response, 200, { ok: true, deleted: true });
    }
    save();
    await flushPersistence();
    return send(response, 200, { ok: true, key: publicRecord(action[1], record) });
  }

  return send(response, 404, { ok: false, error: "NOT_FOUND" });
}

async function activate(request, response) {
  try {
    const input = await body(request);
    updateExpired();
    const key = String(input.key || "").trim().toUpperCase();
    const hwid = String(input.hwid || "").trim();
    const id = digest(key);
    const record = database[id];
    if (!record) return send(response, 401, { ok: false, error: "INVALID_KEY" });
    if (record.status !== "active") return send(response, 403, { ok: false, error: record.status === "expired" ? "EXPIRED_KEY" : "REVOKED_KEY" });
    if (!hwid) return send(response, 400, { ok: false, error: "MISSING_HWID" });
    if (record.hwid && record.hwid !== digest(hwid)) return send(response, 403, { ok: false, error: "HWID_MISMATCH" });
    if (!record.hwid) { record.hwid = digest(hwid); record.boundAt = new Date().toISOString(); }
    record.lastSeen = new Date().toISOString();
    save();
    await flushPersistence();
    const ms = record.expiresAt ? Math.max(0, Date.parse(record.expiresAt) - Date.now()) : null;
    return send(response, 200, { ok: true, expiresAt: record.expiresAt, remainingMs: ms, remainingSeconds: ms === null ? null : Math.ceil(ms / 1000) });
  } catch {
    return send(response, 400, { ok: false, error: "BAD_REQUEST" });
  }
}

function serveStatic(request, response, url) {
  const requested = url.pathname === "/" ? "/index.html" : url.pathname;
  const file = path.normalize(path.join(PUBLIC_DIR, requested));
  if (!file.startsWith(PUBLIC_DIR)) return send(response, 403, { ok: false, error: "FORBIDDEN" });
  if (!fs.existsSync(file) || !fs.statSync(file).isFile()) return send(response, 404, { ok: false, error: "NOT_FOUND" });
  const types = { ".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8", ".css": "text/css; charset=utf-8" };
  response.writeHead(200, { "Content-Type": types[path.extname(file)] || "application/octet-stream" });
  fs.createReadStream(file).pipe(response);
}

const databaseReady = hydrateDatabase().catch(error => {
  console.error(`[MURKETA] Supabase indisponível; usando dados locais: ${error.message}`);
});

const server = http.createServer(async (request, response) => {
  const url = new URL(request.url, `http://${request.headers.host || "localhost"}`);
  try {
    await databaseReady;
    if (request.method === "GET" && url.pathname === "/health") return send(response, 200, { ok: true, service: "murketa-hub" });
    if (request.method === "POST" && url.pathname === "/activate") return activate(request, response);
    if (url.pathname.startsWith("/api/")) return await api(request, response, url);
    return serveStatic(request, response, url);
  } catch (error) {
    console.error(`[MURKETA] ${error.message}`);
    return send(response, 500, { ok: false, error: "INTERNAL_ERROR" });
  }
});

databaseReady.then(() => server.listen(PORT, () => console.log(`[MURKETA] Painel online em http://localhost:${PORT}`)));
