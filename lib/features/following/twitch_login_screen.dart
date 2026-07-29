import "dart:async";

import "package:flow/api/twitch_auth.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:webview_flutter/webview_flutter.dart";

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
  late final WebViewController _webViewController;
  String? _authState;
  var _isCompletingAuth = false;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController();
    unawaited(_initializeWebView());
  }

  Future<void> _initializeWebView() async {
    await _webViewController.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _webViewController.setUserAgent(
      "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Mobile Safari/537.36",
    );
    await _webViewController.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: _handleNavigation,
        onUrlChange: (change) {
          final url = change.url;
          if (url != null) {
            unawaited(_completeAuthFromUrl(url));
          }
        },
        onPageStarted: (url) => unawaited(_completeAuthFromUrl(url)),
        onWebResourceError: (error) {
          debugPrint("Twitch auth WebView error: ${error.description}");
        },
        onPageFinished: (url) {
          unawaited(_completeAuthFromUrl(url));
          unawaited(_patchCookieBanner());
        },
      ),
    );
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
      await _webViewController.loadRequest(authUri);
    } on TwitchAuthException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      Navigator.of(context).pop();
    }
  }

  Future<NavigationDecision> _handleNavigation(
    NavigationRequest request,
  ) async {
    debugPrint("Twitch auth navigation: ${request.url}");
    unawaited(_completeAuthFromUrl(request.url));
    return NavigationDecision.navigate;
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
      final connection = await widget.authController.completeAuth(uri);
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

  Future<void> _patchCookieBanner() async {
    try {
      await _webViewController.runJavaScript("""
        {
          function modifyElement(element) {
            element.style.maxHeight = '20vh';
            element.style.overflow = 'auto';
          }

          const observer = new MutationObserver((mutations) => {
            for (let mutation of mutations) {
              if (mutation.type === 'childList') {
                const element = document.querySelector('.fAVISI');
                if (element) {
                  modifyElement(element);
                  observer.disconnect();
                  break;
                }
              }
            }
          });

          observer.observe(document.body, {
            childList: true,
            subtree: true
          });
        }
      """);
    } on Object catch (error) {
      debugPrint("Twitch auth WebView JavaScript error: $error");
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
    final authState = _authState;
    if (authState != null) {
      unawaited(_cancelPendingAuth(authState));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Connect with Twitch")),
    body: WebViewWidget(controller: _webViewController),
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
