import { env } from "cloudflare:workers";
import { emptyLibrary, isLibrarySnapshot, type LibrarySnapshot } from "./library";

export type LibraryRecord = {
  revision: number;
  snapshot: LibrarySnapshot;
  updatedAt: string;
};

let initialized = false;

export async function ensureSchema() {
  if (initialized) return;
  await env.DB.batch([
    env.DB.prepare(`CREATE TABLE IF NOT EXISTS libraries (
      user_id TEXT PRIMARY KEY,
      revision INTEGER NOT NULL DEFAULT 0,
      payload TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )`),
    env.DB.prepare(`CREATE TABLE IF NOT EXISTS device_tokens (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      token_hash TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      created_at TEXT NOT NULL,
      last_used_at TEXT,
      revoked_at TEXT
    )`),
    env.DB.prepare("CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id ON device_tokens(user_id)"),
  ]);
  initialized = true;
}

export async function libraryFor(userId: string): Promise<LibraryRecord> {
  await ensureSchema();
  const row = await env.DB.prepare(
    "SELECT revision, payload, updated_at AS updatedAt FROM libraries WHERE user_id = ?",
  ).bind(userId).first<{ revision: number; payload: string; updatedAt: string }>();
  if (!row) {
    const now = new Date().toISOString();
    const snapshot = userId === "local-preview" ? previewLibrary() : emptyLibrary();
    await env.DB.prepare(
      "INSERT INTO libraries (user_id, revision, payload, updated_at) VALUES (?, 0, ?, ?)",
    ).bind(userId, JSON.stringify(snapshot), now).run();
    return { revision: 0, snapshot, updatedAt: now };
  }
  const parsed: unknown = JSON.parse(row.payload);
  return {
    revision: row.revision,
    snapshot: isLibrarySnapshot(parsed) ? parsed : emptyLibrary(),
    updatedAt: row.updatedAt,
  };
}

function previewLibrary(): LibrarySnapshot {
  const createdAt = new Date(Date.now() - 1000 * 60 * 60 * 24 * 5).toISOString();
  const modifiedAt = new Date().toISOString();
  const learningId = "8f19d384-1f8d-4a8b-a1cb-201e86d9e7cb";
  const projectsId = "ef19e4ac-27e5-4574-ad89-84b508612d30";
  return {
    schemaVersion: 1,
    folders: [
      { id: learningId, name: "Learning", sortIndex: 0, createdAt, modifiedAt, favoriteAt: modifiedAt, trashedAt: null, colorHex: "#6C63FF", symbolName: "book.fill", parentId: null },
      { id: projectsId, name: "Projects", sortIndex: 1, createdAt, modifiedAt, favoriteAt: null, trashedAt: null, colorHex: "#E49A5B", symbolName: "folder.fill", parentId: null },
    ],
    items: [
      {
        id: "3a92e91c-332a-48c2-96bf-c5526d52d1bd", title: "How memory actually works", kind: "note", sortIndex: 0,
        noteMarkdown: "## The spacing effect\n\nWe remember information better when learning is spread out over time. Each successful recall strengthens the route back to the idea.\n\n### Useful rules\n\n- Review just before you forget\n- Prefer active recall over rereading\n- Connect new ideas to something you already know\n\nSmall, repeated sessions beat one long cram.",
        createdAt, modifiedAt, favoriteAt: modifiedAt, trashedAt: null, tags: ["learning", "memory"], linkedDeckId: null, folderId: learningId, cards: [],
      },
      {
        id: "6785a78e-efef-4656-a4f4-531088e9910f", title: "Memory essentials", kind: "deck", sortIndex: 1,
        noteMarkdown: "", createdAt, modifiedAt: new Date(Date.now() - 3600000).toISOString(), favoriteAt: null, trashedAt: null, tags: ["review"], linkedDeckId: null, folderId: learningId,
        cards: [
          { id: "19682a32-ea3b-45b7-ac0a-fea43f2d7a39", front: "What is the spacing effect?", back: "Learning improves when review sessions are spread over time.", sortIndex: 0 },
          { id: "82d4813b-c377-4a67-847f-b0ee18e0844b", front: "What is active recall?", back: "Retrieving an answer from memory instead of rereading it.", sortIndex: 1 },
          { id: "8ae53e71-9c57-4c22-90e8-9308de5aad86", front: "When should you review?", back: "Near the point of forgetting, when recall still takes effort.", sortIndex: 2 },
        ],
      },
      {
        id: "a2ae4056-854a-4a28-93e1-2a605e97f359", title: "Ideas for the research project", kind: "note", sortIndex: 2,
        noteMarkdown: "# Questions to explore\n\nHow can short daily reviews compound into durable knowledge?", createdAt,
        modifiedAt: new Date(Date.now() - 86400000 * 2).toISOString(), favoriteAt: null, trashedAt: null, tags: ["ideas"], linkedDeckId: null, folderId: projectsId, cards: [],
      },
    ],
  };
}

export async function saveLibrary(userId: string, expectedRevision: number, snapshot: LibrarySnapshot) {
  await ensureSchema();
  const now = new Date().toISOString();
  const result = await env.DB.prepare(
    `UPDATE libraries SET revision = revision + 1, payload = ?, updated_at = ?
     WHERE user_id = ? AND revision = ?`,
  ).bind(JSON.stringify(snapshot), now, userId, expectedRevision).run();
  if (!result.meta.changes) return null;
  return { revision: expectedRevision + 1, snapshot, updatedAt: now } satisfies LibraryRecord;
}

async function sha256(value: string) {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, "0")).join("");
}

export async function userForRequest(request: Request): Promise<{ userId: string; email: string | null } | null> {
  const directId = request.headers.get("oai-authenticated-user-id");
  if (directId) return { userId: directId, email: request.headers.get("oai-authenticated-user-email") };

  const authorization = request.headers.get("authorization");
  if (authorization?.startsWith("Bearer ")) {
    await ensureSchema();
    const tokenHash = await sha256(authorization.slice(7));
    const row = await env.DB.prepare(
      "SELECT id, user_id AS userId FROM device_tokens WHERE token_hash = ? AND revoked_at IS NULL",
    ).bind(tokenHash).first<{ id: string; userId: string }>();
    if (!row) return null;
    await env.DB.prepare("UPDATE device_tokens SET last_used_at = ? WHERE id = ?")
      .bind(new Date().toISOString(), row.id).run();
    return { userId: row.userId, email: null };
  }

  if (process.env.NODE_ENV === "development") return { userId: "local-preview", email: "you@example.com" };
  return null;
}

export async function createDeviceToken(userId: string, name: string) {
  await ensureSchema();
  const rawToken = `fn_${crypto.randomUUID().replaceAll("-", "")}${crypto.randomUUID().replaceAll("-", "")}`;
  const id = crypto.randomUUID();
  const createdAt = new Date().toISOString();
  await env.DB.prepare(
    "INSERT INTO device_tokens (id, user_id, token_hash, name, created_at) VALUES (?, ?, ?, ?, ?)",
  ).bind(id, userId, await sha256(rawToken), name, createdAt).run();
  return { id, name, createdAt, token: rawToken };
}
