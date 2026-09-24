import "dart:async";

import "package:flow/api/twitch_auth.dart";
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter/services.dart";

typedef TwitchLoginOpener =
    Future<TwitchAuthConnection?> Function(
      BuildContext context,
      TwitchAuthController authController,
    );

class TwitchLoginScreen extends StatefulWidget {
  const TwitchLoginScreen({required this.authController, super.key});

  final TwitchAuthController authController;

  @override
  State<TwitchLoginScreen> createState() => _TwitchLoginScreenState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TwitchAuthController>("authController", authController));
  }
}

class _TwitchLoginScreenState extends State<TwitchLoginScreen> {
  MethodChannel? _webViewChannel;
  String? _authState;
  var _isCompletingAuth = false;

  Future<void> _initializeWebView(int viewId) async {
    if (!mounted) {
      return;
    }
    final channel = MethodChannel("flow/twitch_login/$viewId");
    _webViewChannel = channel;
    channel.setMethodCallHandler((call) async {
      if (!mounted) {
        return;
      }
      if (call.method == "onUrlChange") {
        await _completeAuthFromUrl(call.arguments as String);
      } else if (call.method == "onError") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't load Twitch sign-in. Please try again.")),
        );
      }
    });
    await _loadAuthUrl();
  }

  Future<void> _loadAuthUrl() async {
    if (!mounted) {
      return;
    }
    try {
      final authUri = await widget.authController.createAuthorizationUri();
      _authState = authUri.queryParameters["state"];
      if (!mounted) {
        final authState = _authState;
        if (authState != null) {
          await _cancelPendingAuth(authState);
        }
        return;
      }
      await _webViewChannel!.invokeMethod<void>("loadUrl", {
        "url": authUri.toString(),
        "redirectUri": widget.authController.config.redirectUri,
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            error is TwitchAuthException ? error.message : "Couldn't open Twitch sign-in.",
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _completeAuthFromUrl(String url) async {
    if (!mounted || _isCompletingAuth) {
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null ||
        !widget.authController.config.isRedirectUri(uri) ||
        !TwitchAuthCallback.hasOAuthResponse(uri)) {
      return;
    }

    _isCompletingAuth = true;
    try {
      final connection = await widget.authController.completeAuth(
        uri,
        prepareWebSession: () async {
          if (!mounted || _webViewChannel == null) {
            throw TwitchAuthException("Twitch sign-in was canceled.");
          }
          await _webViewChannel!.invokeMethod<void>("importWebSession");
        },
      );
      if (mounted) {
        Navigator.of(context).pop(connection);
      }
    } on Object catch (error) {
      debugPrint("Twitch auth completion error: $error");
      _isCompletingAuth = false;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _cancelPendingAuth(String state) async {
    try {
      await widget.authController.cancelPendingAuth(state);
    } on Object catch (error) {
      debugPrint("Couldn't clear the pending Twitch login: $error");
    }
  }

  @override
  void dispose() {
    _webViewChannel?.setMethodCallHandler(null);
    _webViewChannel = null;
    final authState = _authState;
    if (authState != null) {
      unawaited(_cancelPendingAuth(authState));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Connect with Twitch")),
    body: PlatformViewLink(
      viewType: "flow/twitch_login",
      surfaceFactory: (_, controller) => AndroidViewSurface(
        controller: controller as AndroidViewController,
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        gestureRecognizers: const {},
      ),
      onCreatePlatformView: (params) {
        final view = PlatformViewsService.initExpensiveAndroidView(
          id: params.id,
          viewType: params.viewType,
          layoutDirection: TextDirection.ltr,
          onFocus: () => params.onFocusChanged(true),
        );
        view.addOnPlatformViewCreatedListener(params.onPlatformViewCreated);
        view.addOnPlatformViewCreatedListener((id) => unawaited(_initializeWebView(id)));
        unawaited(view.create());
        return view;
      },
    ),
  );
}

Future<TwitchAuthConnection?> openTwitchLoginScreen(
  BuildContext context,
  TwitchAuthController authController,
) => Navigator.of(context).push<TwitchAuthConnection>(
  MaterialPageRoute(
    builder: (_) => TwitchLoginScreen(authController: authController),
  ),
);
