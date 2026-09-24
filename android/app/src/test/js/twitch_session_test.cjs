const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const listeners = {};
const messages = [];
const event = name => ({ addListener: listener => { listeners[name] = listener; } });
let cookies = [{ name: "auth-token", path: "/", domain: ".twitch.tv", value: "example" }];
let readCookies = () => Promise.resolve(cookies);
vm.runInNewContext(fs.readFileSync(path.join(__dirname, "../../main/assets/twitch-login/background.js"), "utf8"), {
  URL,
  browser: {
    runtime: { connectNative: () => ({
      onMessage: event("message"), onDisconnect: event("disconnect"),
      postMessage: message => messages.push(JSON.parse(JSON.stringify(message))),
    }) },
    cookies: { getAll: () => readCookies() },
    webRequest: { onSendHeaders: event("request") },
  },
});
const start = requestId => listeners.message({ type: "observeRequests", requestId, authorization: "OAuth example" });
const stop = requestId => listeners.message({ type: "stopObservingRequests", requestId });
const request = {
  url: "https://gql.twitch.tv/gql", method: "POST",
  requestHeaders: Object.entries({
    authorization: "OAuth example", "client-id": "client", "client-session-id": "session",
    "client-version": "version", "device-id": "device", "client-integrity": "issued",
    "user-agent": "actual browser", Cookie: "private",
  }).map(([name, value]) => ({ name, value })),
};

(async () => {
  await start(1);
  assert.deepEqual(messages.pop(), { type: "contextReady", requestId: 1, matches: true });
  for (const invalid of [
    { ...request, method: "GET" },
    { ...request, url: "https://gql.twitch.tv.attacker.test/gql" },
    { ...request, url: "http://gql.twitch.tv/gql" },
    { ...request, url: "https://gql.twitch.tv/gql/other" },
    { ...request, requestHeaders: request.requestHeaders.filter(header => header.name !== "authorization") },
    { ...request, requestHeaders: request.requestHeaders.filter(header => header.name !== "client-version") },
  ]) listeners.request(invalid);
  assert.equal(messages.length, 0);
  listeners.request(request);
  assert.deepEqual(messages.pop(), { type: "requestContext", requestId: 1, headers: {
    "Client-Id": "client", "Client-Session-Id": "session", "Client-Version": "version",
    "X-Device-ID": "device", "Client-Integrity": "issued", "User-Agent": "actual browser",
  } });
  listeners.request({ ...request, requestHeaders: request.requestHeaders.map(header =>
    header.name === "authorization" ? { ...header, value: "OAuth other-account" } : header) });
  assert.deepEqual(messages.pop(), { type: "contextFailed", requestId: 1 });
  listeners.request(request);
  assert.equal(messages.length, 0);

  for (const savedCookies of [[], [{ ...cookies[0], value: "other-account" }], [...cookies, { ...cookies[0], value: "conflict" }]]) {
    readCookies = () => Promise.resolve(savedCookies);
    await start(2);
    assert.equal(messages.pop().matches, false);
    listeners.request(request);
    assert.equal(messages.length, 0);
  }

  let resolveCookies;
  readCookies = () => new Promise(resolve => { resolveCookies = resolve; });
  const cancelled = start(3);
  listeners.request(request); // Pending cookie validation cannot export context.
  await stop(3);
  resolveCookies(cookies);
  await cancelled;
  assert.equal(messages.length, 0);

  const replaced = start(4);
  const resolveOldCookies = resolveCookies;
  readCookies = () => Promise.resolve(cookies);
  await start(5);
  assert.equal(messages.pop().requestId, 5);
  resolveOldCookies(cookies);
  await replaced;
  await stop(4); // An older operation cannot stop the current one.
  listeners.request(request);
  assert.equal(messages.pop().requestId, 5);
  listeners.disconnect();
  listeners.request(request);
  assert.equal(messages.length, 0);
  console.log("Twitch session observation checks passed.");
})().catch(error => { console.error(error); process.exitCode = 1; });
