const encoder = new TextEncoder();
const DAY = 86_400_000;
const MAX_AGE = 10 * 60_000;
const json = (value, status = 200) => Response.json(value, { status });
const bytes = (value) => encoder.encode(value);
const base64url = (value) => btoa(String.fromCharCode(...value)).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
const json64 = (value) => base64url(bytes(JSON.stringify(value)));
const validToken = (value) => typeof value === "string" && value.length >= 20 && value.length <= 4096;

async function authorizeDevice(request) {
  const authorization = request.headers.get("Authorization") ?? "";
  if (!/^Bearer [^\s]+$/.test(authorization)) return new Response(null, { status: 401 });
  try {
    const response = await fetch("https://id.twitch.tv/oauth2/validate", {
      headers: { Authorization: `OAuth ${authorization.slice(7)}` }, signal: AbortSignal.timeout(5000),
    });
    if (response.status === 401) return new Response(null, { status: 401 });
    if (!response.ok) return json({ error: "Could not validate Twitch sign-in. Try again." }, 503);
    const account = await response.json();
    return /^[0-9]{1,20}$/.test(account.user_id ?? "") ? account.user_id : new Response(null, { status: 401 });
  } catch {
    return json({ error: "Could not validate Twitch sign-in. Try again." }, 503);
  }
}

async function readBody(request) {
  const reader = request.body?.getReader();
  if (!reader) throw new Error("Empty request");
  const chunks = [];
  let length = 0;
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    length += value.length;
    if (length > 65_536) { await reader.cancel(); throw new Error("Request too large"); }
    chunks.push(value);
  }
  const body = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) { body.set(chunk, offset); offset += chunk.length; }
  return new TextDecoder().decode(body);
}

export async function verifyWebhook(request, body, secret) {
  const id = request.headers.get("Twitch-Eventsub-Message-Id");
  const timestamp = request.headers.get("Twitch-Eventsub-Message-Timestamp");
  const signature = request.headers.get("Twitch-Eventsub-Message-Signature");
  if (!secret || !id || !timestamp || !/^sha256=[0-9a-f]{64}$/.test(signature ?? "") ||
      !Number.isFinite(Date.parse(timestamp)) || Math.abs(Date.now() - Date.parse(timestamp)) > MAX_AGE) return false;
  const key = await crypto.subtle.importKey("raw", bytes(secret), { name: "HMAC", hash: "SHA-256" }, false, ["verify"]);
  const expected = Uint8Array.from(signature.slice(7).match(/../g), (hex) => parseInt(hex, 16));
  return crypto.subtle.verify("HMAC", key, expected, bytes(id + timestamp + body));
}

export default {
  async fetch(request, env) {
    const path = new URL(request.url).pathname;
    if (path === "/health" && request.method === "GET") return json({ ok: true });
    const device = /^\/v1\/devices\/[0-9a-f-]{36}$/i.test(path);
    if (path !== "/webhooks/twitch" && !device) return new Response(null, { status: 404 });
    if (!env.TWITCH_CLIENT_ID || !env.TWITCH_CLIENT_SECRET ||
        !env.TWITCH_WEBHOOK_SECRET || !env.FIREBASE_SERVICE_ACCOUNT) return json({ error: "Relay is not configured." }, 503);
    if (!(device ? ["GET", "PUT", "PATCH", "DELETE"] : ["POST"]).includes(request.method)) return new Response(null, { status: 405 });
    const headers = new Headers(request.headers);
    headers.delete("X-Flow-User-Id");
    if (device) {
      const userId = await authorizeDevice(request);
      if (userId instanceof Response) return userId;
      headers.set("X-Flow-User-Id", userId);
    }
    headers.delete("Authorization");
    let body = "";
    if (["PUT", "PATCH", "POST"].includes(request.method)) {
      try { body = await readBody(request); } catch { return json({ error: "Invalid request body." }, 400); }
    }
    if (!device && !await verifyWebhook(request, body, env.TWITCH_WEBHOOK_SECRET)) return new Response(null, { status: 403 });
    // ponytail: one coordinator shares subscriptions; shard by broadcaster when fan-out outgrows it.
    const relay = env.RELAY.get(env.RELAY.idFromName("relay"));
    return relay.fetch(new Request(request.url, {
      method: request.method, headers, body: body || undefined,
    }));
  },
};

export class GoLiveRelay {
  constructor(ctx, env) {
    this.storage = ctx.storage;
    this.env = env;
  }

  async wake(delay = 1) {
    await this.storage.transaction(async (storage) => {
      const next = Date.now() + Math.max(1, delay);
      const alarm = await storage.getAlarm();
      if (alarm === null || alarm > next) await storage.setAlarm(next);
    });
  }

  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname === "/webhooks/twitch") {
      let payload;
      try { payload = await request.json(); } catch { return new Response(null, { status: 400 }); }
      const type = request.headers.get("Twitch-Eventsub-Message-Type");
      if (payload?.subscription?.type !== "stream.online") return new Response(null, { status: 204 });
      const channel = payload.subscription.condition?.broadcaster_user_id;
      if (type === "webhook_callback_verification") {
        if (typeof payload.challenge !== "string" || !/^[0-9]{1,20}$/.test(channel ?? "")) return new Response(null, { status: 400 });
        await this.storage.put(`channel:${channel}`, { id: payload.subscription.id, ready: true });
        await this.wake(60_000);
        return new Response(payload.challenge);
      }
      if (type === "revocation") {
        const subscription = await this.storage.get(`channel:${channel}`);
        if (subscription?.id === payload.subscription.id) await this.storage.delete(`channel:${channel}`);
        await this.wake(60_000);
      } else if (type === "notification") {
        const event = payload.event;
        if (!event || event.broadcaster_user_id !== channel || event.type !== "live" ||
            typeof event.id !== "string" || !/^[a-zA-Z0-9_]{1,25}$/.test(event.broadcaster_user_login ?? "") ||
            !Number.isFinite(Date.parse(event.started_at)) || Math.abs(Date.now() - Date.parse(event.started_at)) > MAX_AGE) {
          return new Response(null, { status: 204 });
        }
        await this.storage.transaction(async (storage) => {
          const seen = `event:${channel}:${event.id}`;
          if (await storage.get(seen)) return;
          const devices = await storage.list({ prefix: "device:" });
          for (const [key, device] of devices) {
            if (device.channels.includes(channel)) await storage.put(`push:${channel}:${event.id}:${key.slice(7)}`, {
              deviceId: key.slice(7), event, expires: Date.parse(event.started_at) + MAX_AGE, next: 0, attempt: 0,
            });
          }
          await storage.put(seen, Date.now());
          await storage.setAlarm(Date.now() + 1);
        });
      }
      return new Response(null, { status: 204 });
    }
    const userId = request.headers.get("X-Flow-User-Id");
    if (!/^[0-9]{1,20}$/.test(userId ?? "")) return new Response(null, { status: 401 });
    const deviceKey = `device:${userId}:${url.pathname.split("/").at(-1)}`;
    if (request.method === "GET") {
      const device = await this.storage.get(deviceKey);
      const subscriptions = await this.storage.list({ prefix: "channel:" });
      return json({ channels: device?.channels ?? [], readyChannels: [...subscriptions].filter(([key, value]) => value.ready && device?.channels.includes(key.slice(8))).map(([key]) => key.slice(8)), error: await this.storage.get("error") ?? await this.storage.get("deliveryError") ?? null });
    }
    if (request.method === "PATCH") {
      let update;
      try { update = await request.json(); } catch { return json({ error: "Invalid JSON." }, 400); }
      if (!update || !validToken(update.token) || !validToken(update.previousToken)) return json({ error: "Invalid token." }, 400);
      const status = await this.storage.transaction(async (storage) => {
        const device = await storage.get(deviceKey);
        if (!device) return 404;
        if (device.token === update.token) return 204;
        if (device.token !== update.previousToken) return 409;
        await storage.put(deviceKey, { ...device, token: update.token });
        return 204;
      });
      return new Response(null, { status });
    }
    if (request.method === "DELETE") await this.storage.delete(deviceKey);
    else {
      let device;
      try { device = await request.json(); } catch { return json({ error: "Invalid JSON." }, 400); }
      if (!device || !validToken(device.token) ||
          !Array.isArray(device.channels) || device.channels.length > 1000 ||
          device.channels.some((id) => typeof id !== "string" || !/^[0-9]{1,20}$/.test(id))) return json({ error: "Invalid token or channels." }, 400);
      const saved = await this.storage.transaction(async (storage) => {
        const devices = await storage.list({ prefix: `device:${userId}:` });
        if (!devices.has(deviceKey) && devices.size >= 10) return false;
        await storage.put(deviceKey, { token: device.token, channels: [...new Set(device.channels)] });
        return true;
      });
      if (!saved) return json({ error: "Each Twitch account supports up to ten devices." }, 409);
    }
    await this.storage.put("callback", new URL("/webhooks/twitch", url).href);
    await this.wake();
    return new Response(null, { status: request.method === "DELETE" ? 204 : 202 });
  }

  async twitch(path, method = "GET", body) {
    if (!this.twitchToken || this.twitchToken.expires < Date.now() + 60_000) {
      const response = await fetch("https://id.twitch.tv/oauth2/token", {
        method: "POST", body: new URLSearchParams({ client_id: this.env.TWITCH_CLIENT_ID, client_secret: this.env.TWITCH_CLIENT_SECRET, grant_type: "client_credentials" }), signal: AbortSignal.timeout(8000),
      });
      if (!response.ok) throw new Error(`Twitch authorization failed (${response.status}).`);
      const token = await response.json();
      this.twitchToken = { value: token.access_token, expires: Date.now() + token.expires_in * 1000 };
    }
    const response = await fetch(`https://api.twitch.tv/helix${path}`, {
      method, headers: { "Client-Id": this.env.TWITCH_CLIENT_ID, Authorization: `Bearer ${this.twitchToken.value}`, "Content-Type": "application/json" },
      body: body ? JSON.stringify(body) : undefined, signal: AbortSignal.timeout(8000),
    });
    if (response.status === 401) this.twitchToken = null;
    return response;
  }

  async reconcile() {
    const devices = await this.storage.list({ prefix: "device:" });
    const wanted = new Set([...devices.values()].flatMap((device) => device.channels));
    const subscriptions = await this.storage.list({ prefix: "channel:" });
    const callback = await this.storage.get("callback");
    const changes = [
      ...[...subscriptions].filter(([key, value]) => !wanted.has(key.slice(8)) || (!value.ready && Date.now() - value.created > 60_000)).map(([key]) => key.slice(8)),
      ...[...wanted].filter((id) => !subscriptions.has(`channel:${id}`)),
    ];
    // Keep each alarm small so new webhook deliveries are not held behind channel setup.
    const cursor = changes.length ? (await this.storage.get("reconcileCursor") ?? 0) % changes.length : 0;
    const batch = Array.from({ length: Math.min(5, changes.length) }, (_, index) => changes[(cursor + index) % changes.length]);
    await this.storage.put("reconcileCursor", changes.length ? (cursor + batch.length) % changes.length : 0);
    let failure;
    for (const channel of batch) {
      try {
        const previous = subscriptions.get(`channel:${channel}`);
        if (previous) {
          const response = await this.twitch(`/eventsub/subscriptions?id=${encodeURIComponent(previous.id)}`, "DELETE");
          if (!response.ok && response.status !== 404) throw new Error(`Twitch unsubscribe failed (${response.status}).`);
          await this.storage.delete(`channel:${channel}`);
          if (wanted.has(channel)) await this.wake();
        } else {
          const response = await this.twitch("/eventsub/subscriptions", "POST", { type: "stream.online", version: "1", condition: { broadcaster_user_id: channel }, transport: { method: "webhook", callback, secret: this.env.TWITCH_WEBHOOK_SECRET } });
          if (response.status === 409) {
            let cursor = "", found;
            do {
              const existing = await this.twitch(`/eventsub/subscriptions?type=stream.online&first=100${cursor ? `&after=${encodeURIComponent(cursor)}` : ""}`);
              if (!existing.ok) throw new Error(`Twitch subscription lookup failed (${existing.status}).`);
              const page = await existing.json();
              found = page.data.find((item) => item.condition.broadcaster_user_id === channel && item.transport.callback === callback);
              cursor = page.pagination?.cursor ?? "";
            } while (cursor && !found);
            if (!found) throw new Error("A conflicting Twitch subscription must be removed.");
            if (found.status !== "enabled" && found.status !== "webhook_callback_verification_pending") {
              const removed = await this.twitch(`/eventsub/subscriptions?id=${encodeURIComponent(found.id)}`, "DELETE");
              if (!removed.ok && removed.status !== 404) throw new Error(`Twitch subscription repair failed (${removed.status}).`);
              await this.wake();
              continue;
            }
            await this.storage.put(`channel:${channel}`, { id: found.id, ready: found.status === "enabled", created: Date.now() });
            if (found.status !== "enabled") await this.wake(60_001);
          } else {
            if (!response.ok) throw new Error(`Twitch subscribe failed (${response.status}).`);
            const result = await response.json();
            await this.storage.transaction(async (storage) => {
              const current = await storage.get(`channel:${channel}`);
              if (current?.id !== result.data[0].id) await storage.put(`channel:${channel}`, { id: result.data[0].id, ready: false, created: Date.now() });
            });
            await this.wake(60_001);
          }
        }
      } catch (error) { failure = error; }
    }
    if (changes.length > 5) await this.wake(failure ? 60_000 : 1);
    if (failure) throw failure;
  }

  async googleToken() {
    if (this.firebaseToken?.expires > Date.now() + 60_000) return this.firebaseToken.value;
    const account = JSON.parse(this.env.FIREBASE_SERVICE_ACCOUNT);
    const now = Math.floor(Date.now() / 1000);
    const unsigned = `${json64({ alg: "RS256", typ: "JWT" })}.${json64({ iss: account.client_email, scope: "https://www.googleapis.com/auth/firebase.messaging", aud: "https://oauth2.googleapis.com/token", iat: now, exp: now + 3600 })}`;
    const der = Uint8Array.from(atob(account.private_key.replace(/-----[^-]+-----|\s/g, "")), (character) => character.charCodeAt(0));
    const key = await crypto.subtle.importKey("pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
    const signature = new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, bytes(unsigned)));
    const response = await fetch("https://oauth2.googleapis.com/token", { method: "POST", body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: `${unsigned}.${base64url(signature)}` }), signal: AbortSignal.timeout(8000) });
    if (!response.ok) throw new Error(`Firebase authorization failed (${response.status}).`);
    const token = await response.json();
    this.firebaseToken = { value: token.access_token, expires: Date.now() + token.expires_in * 1000 };
    return this.firebaseToken.value;
  }

  async notificationMetadata(event) {
    const key = `metadata:${event.broadcaster_user_id}:${event.id}`;
    const saved = await this.storage.get(key);
    if (saved) return saved;
    const [channel, user] = await Promise.allSettled([
      `/channels?broadcaster_id=${encodeURIComponent(event.broadcaster_user_id)}`,
      `/users?id=${encodeURIComponent(event.broadcaster_user_id)}`,
    ].map(async (path) => {
      const response = await this.twitch(path);
      return response.ok ? (await response.json()).data?.[0] : null;
    }));
    const metadata = {
      stream_title: channel.value?.title ?? "",
      avatar_url: user.value?.profile_image_url ?? "",
    };
    await this.storage.put(key, metadata);
    return metadata;
  }

  async send(device, job) {
    const event = job.event;
    const metadata = await this.notificationMetadata(event);
    if (job.expires <= Date.now()) return;
    const account = JSON.parse(this.env.FIREBASE_SERVICE_ACCOUNT);
    const token = await this.googleToken();
    const response = await fetch(`https://fcm.googleapis.com/v1/projects/${encodeURIComponent(account.project_id)}/messages:send`, {
      method: "POST", signal: AbortSignal.timeout(8000),
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ message: { token: device.token, data: {
        user_id: job.deviceId.split(":")[0],
        channel_login: event.broadcaster_user_login, channel_name: event.broadcaster_user_name,
        broadcaster_id: event.broadcaster_user_id, stream_id: event.id,
        title: `${event.broadcaster_user_name} is live!`, ...metadata,
      }, android: { priority: "HIGH", ttl: `${Math.max(0, Math.floor((job.expires - Date.now()) / 1000))}s` } } }),
    });
    if (response.ok) return;
    if (response.status === 401) this.firebaseToken = null;
    const result = await response.json().catch(() => ({}));
    if (result.error?.details?.some((detail) => detail.errorCode === "UNREGISTERED")) {
      await this.storage.transaction(async (storage) => {
        const current = await storage.get(`device:${job.deviceId}`);
        if (current?.token === device.token) await storage.delete(`device:${job.deviceId}`);
      });
      return;
    }
    throw new Error(`Firebase delivery failed (${response.status}).`);
  }

  async alarm() {
    const jobs = await this.storage.list({ prefix: "push:" });
    const due = [...jobs].filter(([, job]) => job.next <= Date.now() || job.expires <= Date.now());
    for (const [, job] of jobs) if (job.next > Date.now()) await this.wake(Math.min(job.next, job.expires) - Date.now());
    for (const [key, job] of due.slice(0, 20)) {
      if (job.expires <= Date.now()) { await this.storage.delete(key); continue; }
      const device = await this.storage.get(`device:${job.deviceId}`);
      if (!device?.channels.includes(job.event.broadcaster_user_id)) { await this.storage.delete(key); continue; }
      try {
        await this.send(device, job);
        await this.storage.delete(key);
        await this.storage.delete("deliveryError");
      } catch (error) {
        await this.storage.put("deliveryError", /^Firebase (authorization|delivery) failed \([0-9]+\)\.$/.test(error.message) ? error.message : "Firebase delivery failed. Check the relay's service account configuration.");
        job.attempt++;
        job.next = Date.now() + Math.min(60_000, 2000 * 2 ** Math.min(job.attempt, 5));
        await this.storage.put(key, job);
        await this.wake(job.next - Date.now());
      }
    }
    if (due.length > 20) await this.wake();
    try { await this.reconcile(); await this.storage.delete("error"); }
    catch (error) { await this.storage.put("error", error.message); await this.wake(60_000); }
    const events = await this.storage.list({ prefix: "event:" });
    for (const [key, timestamp] of events) if (Date.now() - timestamp > DAY) {
      await this.storage.delete(key);
      await this.storage.delete(`metadata:${key.slice(6)}`);
    }
  }
}
