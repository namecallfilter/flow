import "package:flutter/services.dart";

typedef ExternalUrlOpener = Future<void> Function(Uri uri);

abstract final class FlowLinks {
  static final repository = Uri.parse("https://github.com/namecallfilter/flow");
}

class ExternalUrlException implements Exception {
  const ExternalUrlException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract final class ExternalUrlLauncher {
  static const _channel = MethodChannel("flow/external_url");

  static Future<void> open(Uri uri) async {
    final didOpen = await _channel.invokeMethod<bool>("openExternalUrl", uri.toString()) ?? false;
    if (!didOpen) {
      throw ExternalUrlException("Could not open $uri");
    }
  }
}
