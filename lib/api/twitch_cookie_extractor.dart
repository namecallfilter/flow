import "package:flutter/services.dart";

abstract class TwitchCookieExtractor {
  const TwitchCookieExtractor();

  Future<String?> extractTwitchAuthToken();

  Future<String?> extractTwitchDeviceId() async => null;
}

class MethodChannelTwitchCookieExtractor extends TwitchCookieExtractor {
  const MethodChannelTwitchCookieExtractor();

  static const _channel = MethodChannel("flow/cookie_extractor");

  @override
  Future<String?> extractTwitchAuthToken() =>
      _channel.invokeMethod<String>("extractTwitchAuthToken");

  @override
  Future<String?> extractTwitchDeviceId() async {
    try {
      return await _channel.invokeMethod<String>("extractTwitchDeviceId");
    } on MissingPluginException {
      return null;
    }
  }

  Future<Map<String, String>?> getTwitchIntegrityContext(String authorization) =>
      _channel.invokeMapMethod<String, String>(
        "getTwitchIntegrityContext",
        {"authorization": authorization},
      );
}
