const port = browser.runtime.connectNative("flow_twitch_login");
let observation = null;

port.onMessage.addListener(async (message) => {
  if (!Number.isSafeInteger(message.requestId)) return;
  if (message.type === "stopObservingRequests") {
    if (observation?.requestId === message.requestId) observation = null;
    return;
  }
  if (message.type === "observeRequests") {
    observation = message;
    observation.ready = false;
    try {
      const cookies = await browser.cookies.getAll({ domain: "twitch.tv", storeId: "firefox-default" });
      if (observation !== message) return;
      const tokens = new Set(cookies.filter(cookie => cookie.name === "auth-token" && cookie.path === "/" &&
        ["twitch.tv", "www.twitch.tv"].includes(cookie.domain.replace(/^\./, ""))).map(cookie => cookie.value));
      const matches = tokens.size === 1 && message.authorization === `OAuth ${[...tokens][0]}`;
      if (matches) observation.ready = true; else observation = null;
      port.postMessage({ type: "contextReady", requestId: message.requestId, matches });
    } catch {
      if (observation === message) {
        observation = null;
        port.postMessage({ type: "contextFailed", requestId: message.requestId });
      }
    }
    return;
  }
  if (message.type !== "exportCookies") return;
  const reply = { type: "cookies", requestId: message.requestId };
  try {
    const cookies = await browser.cookies.getAll({ domain: "twitch.tv", storeId: "firefox-default" });
    port.postMessage({ ...reply, ok: true, cookies });
  } catch {
    port.postMessage({ ...reply, ok: false });
  }
});

browser.webRequest.onSendHeaders.addListener(details => {
  if (!observation?.ready || details.method !== "POST") return;
  const url = new URL(details.url);
  if (url.origin !== "https://gql.twitch.tv" || url.pathname !== "/gql") return;
  const header = name => details.requestHeaders?.find(value => value.name.toLowerCase() === name.toLowerCase())?.value;
  const authorization = header("Authorization");
  if (!authorization) return;
  const reply = { requestId: observation.requestId };
  if (authorization.trim() !== observation.authorization) {
    observation = null;
    port.postMessage({ ...reply, type: "contextFailed" });
    return;
  }
  const headers = {};
  for (const name of ["Client-Id", "Client-Session-Id", "Client-Version", "X-Device-ID"]) {
    const value = header(name) || (name === "X-Device-ID" ? header("Device-ID") : null);
    if (!value?.trim()) return;
    headers[name] = value;
  }
  for (const name of ["Client-Integrity", "User-Agent", "Origin", "Referer"]) {
    const value = header(name);
    if (value?.trim()) headers[name] = value;
  }
  port.postMessage({ ...reply, type: "requestContext", headers });
}, { urls: ["https://gql.twitch.tv/gql*"] }, ["requestHeaders"]);

port.onDisconnect.addListener(() => { observation = null; });
