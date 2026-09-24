const port = browser.runtime.connectNative("flow_twitch_login");

port.onMessage.addListener(async (message) => {
  if (message.type !== "exportCookies" || !Number.isSafeInteger(message.requestId)) return;
  const reply = { type: "cookies", requestId: message.requestId };
  try {
    const cookies = await browser.cookies.getAll({ domain: "twitch.tv", storeId: "firefox-default" });
    port.postMessage({ ...reply, ok: true, cookies });
  } catch {
    port.postMessage({ ...reply, ok: false });
  }
});
