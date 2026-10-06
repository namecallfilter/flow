# Flow go-live relay

Twitch sends `stream.online` webhooks to this Worker. One SQLite Durable Object
stores Twitch-enabled channels last synced by each app, private FCM device tokens, deduplication records,
and pending deliveries. Durable alarms send high-priority FCM data messages and
retry failures. Flow posts the Android notification and opens the selected stream.
The phone does not poll, hold a separate socket, or run a foreground service.

Any signed-in Twitch user can register up to ten devices with 1,000 channels per
device. Every device operation validates the existing Twitch bearer and is scoped
to that account's user ID. The Worker neither stores nor logs user tokens, and no
shared secret is embedded in the app. One coordinator shares Twitch subscriptions
across users; large deployments need to shard this coordinator and account for
Twitch subscription and Cloudflare resource limits.

## Required accounts

- A Cloudflare account with Workers access. SQLite Durable Objects are available
  on [Workers Free](https://developers.cloudflare.com/durable-objects/platform/pricing/).
  This configuration does not enable a paid plan.
- An owned [Twitch developer application](https://dev.twitch.tv/console/apps)
  with its client ID and client secret. `stream.online` needs no authorization
  from the streamer; webhook registration requires an app access token.
- A Firebase project with Cloud Messaging enabled and a service account allowed
  to send FCM messages. Register both Android package names as needed:
  `com.namecallfilter.flow` and `com.namecallfilter.flow.debug`.

Build Flow with the Firebase app ID, project ID, sender ID (project number),
and API key for its package, using `FLOW_FIREBASE_APP_ID`,
`FLOW_FIREBASE_PROJECT_ID`, `FLOW_FIREBASE_SENDER_ID`, and `FLOW_FIREBASE_API_KEY`
Dart defines, plus the public Worker origin in `FLOW_GO_LIVE_RELAY_URL`.
These are Firebase client options; the service-account private key
and Twitch client secret must stay on the Worker.

```powershell
flutter build apk --debug --dart-define=FLOW_GO_LIVE_RELAY_URL=https://flow-go-live.example.workers.dev --dart-define=FLOW_FIREBASE_APP_ID=... --dart-define=FLOW_FIREBASE_API_KEY=... --dart-define=FLOW_FIREBASE_SENDER_ID=... --dart-define=FLOW_FIREBASE_PROJECT_ID=...
```

The native build generates Firebase resources; no Google Services Gradle plugin
or `google-services.json` is required. Users enable **Live Notifications** and
grant Android notification permission. Flow automatically uses their existing
Twitch sign-in and Twitch's per-channel live-notification preferences. There is
no relay setup or separate channel-selection screen in the app.
Only channels set to **Always** or **Go Live Only** receive alerts; **Personalized**
and disabled notifications are excluded.
Preferences synchronize when enabling notifications, starting or resuming Flow.
Changes made on Twitch while Flow is closed take effect on the next sync; the
Worker cannot discover those changes from `stream.online` events alone.
Native FCM token callbacks update an existing registration in the background.
If the network, locked credential storage, or a concurrent update prevents this,
the next app resume retries synchronization. Turning notifications off stops
them locally immediately; a failed server deletion retries on resume or enable.
Switching accounts turns alerts off. If the old account's expired token prevents
cleanup, enabling for the new account invalidates the old FCM token first.

## Deploy

Run commands from this directory. Wrangler deploys Workers; `cloudflared` manages
[Cloudflare Tunnels](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/).
A tunnel's `cert.pem` does not authenticate Wrangler. No tunnel or always-running
local server is needed for this relay.

```powershell
npx --yes wrangler@4.147.0 login
npx --yes wrangler@4.147.0 deploy
npx --yes wrangler@4.147.0 secret put TWITCH_CLIENT_ID
npx --yes wrangler@4.147.0 secret put TWITCH_CLIENT_SECRET
npx --yes wrangler@4.147.0 secret put TWITCH_WEBHOOK_SECRET
Get-Content -Raw -LiteralPath 'C:\secure\service-account.json' | npx --yes wrangler@4.147.0 secret put FIREBASE_SERVICE_ACCOUNT
```

Generate a random `TWITCH_WEBHOOK_SECRET` of at least 32 characters (Twitch allows
webhook secrets of 10–100 characters).
The first deployment refuses registration until every secret is configured.
Build Flow with the final HTTPS Worker origin. Keep this origin stable:
Twitch subscriptions point to `/webhooks/twitch` on the origin used at registration.
If changing origins, remove the old EventSub subscriptions before re-enabling.

## Configured release

The deployed relay is `https://flow-go-live.jacobyb0508.workers.dev`, using Firebase
project `flow-ac486` and the **Flow Live Notifications** confidential Twitch app.
The existing public **flow-watch** app still handles the single user sign-in.
Server credentials are Worker secrets and are kept outside this repository.

On this workstation, the release client options are saved in
`$env:LOCALAPPDATA\Flow\notifications\android-build.json`. From the repository root:

```powershell
flutter build apk --release --split-per-abi --target-platform android-arm64 --dart-define-from-file="$env:LOCALAPPDATA\Flow\notifications\android-build.json"
```

Include this configuration when building future releases; a build without it
does not enable live notifications. It targets `com.namecallfilter.flow`; a debug
build needs Firebase options for its separate package name.

## Device API

Every device request requires `Authorization: Bearer <current Twitch user token>`.
The Worker validates this with Twitch and binds the request to the returned
`user_id`, overwriting any caller-supplied internal identity header. Invalid tokens
return `401`; validation outages return `503`. OAuth and Twitch web-session tokens
are accepted if Twitch validates them as belonging to a user. There is no endpoint
that returns registration tokens or secrets.

- `PUT /v1/devices/<uuid>` with `{"token":"<FCM token>","channels":["1234"]}`
  atomically replaces that device's token and channel selection. Returns `202`
  after durable acceptance. Subscription setup runs asynchronously.
- `GET /v1/devices/<uuid>` returns `channels`, `readyChannels`, and `error`.
  A channel becomes ready after Twitch's signed verification callback. Refresh
  this only when opening or changing settings; no background polling is needed.
- `PATCH /v1/devices/<uuid>` with `{"token":"<new token>","previousToken":"<old token>"}`
  updates only an existing device's token, preserving selected channels. Returns
  `204` if updated or already current, `409` for a stale previous token, and `404`
  after deletion. A background token callback cannot re-enable a deleted device.
- `DELETE /v1/devices/<uuid>` returns `204` and removes the device immediately.
  Pending sends check the current selection; unused Twitch subscriptions are removed.
- `POST /webhooks/twitch` accepts authenticated Twitch EventSub messages only.
- `GET /health` reports HTTP reachability, not credential or push readiness.

FCM data keys: recipient `user_id`, `channel_login`, `channel_name`, `broadcaster_id`,
`stream_id`, `title`, `stream_title`, and `avatar_url`. Channel title and profile image
come from Helix once per stream event, shared across devices and delivery retries.
Missing metadata does not prevent an alert. Android must reject messages for another signed-in user,
suppress duplicate `stream_id` values per broadcaster, and ignore messages after
local opt-out. Server delivery is at least once: a
process can fail after FCM accepts a message but before the receipt is persisted.

Notifications expire ten minutes after the stream starts. Twitch retries are
deduplicated for 24 hours; the last synchronized channel choices are checked again
before sending. Invalid FCM tokens remove their device. Failed subscriptions are exposed
through `error` and retried; push delivery retries back off to one minute.
Neither FCM nor mobile networking guarantees an exact delivery time.

## Verification on Pixel 9

`device-check.html` is a standalone browser check of authentication, signed
webhooks, account isolation, token refresh races, duplicate suppression, filtering, opt-out, notification metadata, retry scheduling and
subscription progress after channel failures using
in-memory storage. Serve this directory only to the local device through an ADB
reverse port, open the page on Pixel 9 using agent-device, and press **Run checks**.
It never contacts Twitch or Firebase and is not a Worker endpoint.

After deployment, enable a channel's bell on Twitch and Live Notifications in
Flow on Pixel 9, confirm the channel appears in
`readyChannels`, background the app, and trigger a real `stream.online` event or
an authenticated Twitch CLI event. Verify one notification, tap-to-stream,
duplicates, opt-out, token refresh, and delivery during Android Doze. Complete
delivery testing requires the real Firebase/Twitch credentials and configuration.

On October 5, 2026, the configured release passed physical Pixel 9 checks through
the deployed Worker and real FCM: delivery with Flow's process closed, delivery
while Android remained in deep Doze, tap-to-stream from a cold start, duplicate
suppression, and opt-out. These used clearly labeled, signed synthetic go-live
events. Twitch's actual subscriptions completed webhook verification and were
`enabled`. Live Notifications was left on and normal device power state restored.

The notification appearance update passed 23 browser checks on Pixel 9 and real
FCM delivery during deep Doze. Expanded and collapsed alerts show the streamer
avatar with Flow's small app badge and the stream title, without a report action.
Cold and warm notification taps loaded the actual player avatar, title and
category; chat-only headers and Android media metadata also refreshed correctly.

Sources: [EventSub webhooks](https://dev.twitch.tv/docs/eventsub/handling-webhook-events/),
[Twitch token validation](https://dev.twitch.tv/docs/authentication/validate-tokens/),
[EventSub subscriptions](https://dev.twitch.tv/docs/eventsub/manage-subscriptions/),
[Channel information](https://dev.twitch.tv/docs/api/reference/#get-channel-information),
[User profiles](https://dev.twitch.tv/docs/api/reference/#get-users),
[FCM HTTP v1](https://firebase.google.com/docs/cloud-messaging/send/v1-api),
[Android Doze guidance](https://developer.android.com/training/monitoring-device-state/doze-standby),
[Durable Object alarms](https://developers.cloudflare.com/durable-objects/api/alarms/).
