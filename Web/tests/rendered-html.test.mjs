import assert from "node:assert/strict";
import test from "node:test";

async function render() {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request("http://localhost/", {
      headers: {
        accept: "text/html",
        "oai-authenticated-user-id": "test-user",
        "oai-authenticated-user-email": "test@example.com",
      },
    }),
    { ASSETS: { fetch: async () => new Response("Not found", { status: 404 }) } },
    { waitUntil() {}, passThroughOnException() {} },
  );
}

test("server-renders the FlashNotes loading shell", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /<title>Flashnotes Web · Flashnotes<\/title>/i);
  assert.match(html, /Opening your library/);
  assert.match(html, /class="loading"/);
  assert.doesNotMatch(html, /codex-preview|Your site is taking shape|Building your site/i);
});

test("ships the Mac-parity product surface", async () => {
  const component = await import("node:fs/promises").then(({ readFile }) =>
    readFile(new URL("../app/FlashnotesWeb.tsx", import.meta.url), "utf8"),
  );
  const css = await import("node:fs/promises").then(({ readFile }) =>
    readFile(new URL("../app/globals.css", import.meta.url), "utf8"),
  );

  assert.match(component, /Cloud saved/);
  assert.match(component, /Connect FlashNotes on your Mac/);
  assert.match(component, /setInterval\(load, 4_000\)/);
  assert.match(css, /Shared visual system with the native macOS app/);
  assert.match(css, /prefers-color-scheme:\s*dark/);
  assert.match(css, /--native-selected/);
});
