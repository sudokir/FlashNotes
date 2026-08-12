import { env } from "cloudflare:workers";
import { createDeviceToken, ensureSchema, userForRequest } from "../../../lib/server-library";

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const user = await userForRequest(request);
  if (!user) return Response.json({ error: "Authentication required" }, { status: 401 });
  await ensureSchema();
  const result = await env.DB.prepare(
    `SELECT id, name, created_at AS createdAt, last_used_at AS lastUsedAt
     FROM device_tokens WHERE user_id = ? AND revoked_at IS NULL ORDER BY created_at DESC`,
  ).bind(user.userId).all();
  return Response.json({ devices: result.results });
}

export async function POST(request: Request) {
  const user = await userForRequest(request);
  if (!user) return Response.json({ error: "Authentication required" }, { status: 401 });
  const body = await request.json().catch(() => ({})) as { name?: string };
  const name = body.name?.trim().slice(0, 60) || "My Mac";
  return Response.json(await createDeviceToken(user.userId, name), { status: 201 });
}

export async function DELETE(request: Request) {
  const user = await userForRequest(request);
  if (!user) return Response.json({ error: "Authentication required" }, { status: 401 });
  const id = new URL(request.url).searchParams.get("id");
  if (!id) return Response.json({ error: "Device id required" }, { status: 400 });
  await ensureSchema();
  await env.DB.prepare("UPDATE device_tokens SET revoked_at = ? WHERE id = ? AND user_id = ?")
    .bind(new Date().toISOString(), id, user.userId).run();
  return Response.json({ ok: true });
}
