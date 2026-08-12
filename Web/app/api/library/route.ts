import { isLibrarySnapshot } from "../../../lib/library";
import { libraryFor, saveLibrary, userForRequest } from "../../../lib/server-library";

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const user = await userForRequest(request);
  if (!user) return Response.json({ error: "Authentication required" }, { status: 401 });
  return Response.json(await libraryFor(user.userId), { headers: { "cache-control": "no-store" } });
}

export async function PUT(request: Request) {
  const user = await userForRequest(request);
  if (!user) return Response.json({ error: "Authentication required" }, { status: 401 });
  const body = await request.json() as { revision?: unknown; snapshot?: unknown };
  if (!Number.isInteger(body.revision) || !isLibrarySnapshot(body.snapshot)) {
    return Response.json({ error: "Invalid library snapshot" }, { status: 400 });
  }
  const saved = await saveLibrary(user.userId, body.revision as number, body.snapshot);
  if (!saved) {
    return Response.json({ error: "The library changed on another device", current: await libraryFor(user.userId) }, { status: 409 });
  }
  return Response.json(saved);
}
