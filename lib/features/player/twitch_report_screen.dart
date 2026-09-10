import "dart:async";

import "package:flow/shared/external_url_opener.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:webview_flutter/webview_flutter.dart";

class TwitchReportScreen extends StatefulWidget {
  const TwitchReportScreen({required this.login, super.key}) : _subscribe = false;

  const TwitchReportScreen.subscribe({required this.login, super.key}) : _subscribe = true;

  final String login;
  final bool _subscribe;

  Uri get _uri => _subscribe
      ? Uri(scheme: "https", host: "subs.twitch.tv", pathSegments: [login])
      : Uri(scheme: "https", host: "www.twitch.tv", pathSegments: [login, "report"]);

  @override
  State<TwitchReportScreen> createState() => _TwitchReportScreenState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty("login", login));
  }
}

class _TwitchReportScreenState extends State<TwitchReportScreen> {
  late final WebViewController _controller;
  bool _canGoBack = false;
  bool _loadFailed = false;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await _controller.setUserAgent(
        "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Mobile Safari/537.36",
      );
      await _controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            return uri != null && uri.scheme == "https" && uri.host.isNotEmpty
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onProgress: (progress) {
            if (mounted) {
              setState(() => _progress = progress);
            }
          },
          onPageStarted: (_) {
            if (mounted) {
              setState(() => _loadFailed = false);
            }
          },
          onUrlChange: (_) => unawaited(_updateBackNavigation()),
          onPageFinished: (_) => unawaited(_updateBackNavigation()),
          onWebResourceError: (error) {
            if (mounted && error.isForMainFrame == true) {
              setState(() => _loadFailed = true);
            }
          },
        ),
      );
      if (mounted) {
        await _controller.loadRequest(widget._uri);
      }
    } on Object {
      if (mounted) {
        setState(() => _loadFailed = true);
      }
    }
  }

  Future<void> _updateBackNavigation() async {
    if (!mounted) {
      return;
    }
    try {
      final canGoBack = await _controller.canGoBack();
      if (mounted && _canGoBack != canGoBack) {
        setState(() => _canGoBack = canGoBack);
      }
    } on Object {
      if (mounted) {
        setState(() => _canGoBack = false);
      }
    }
  }

  Future<void> _goBack() async {
    try {
      final canGoBack = await _controller.canGoBack();
      if (!mounted) {
        return;
      }
      if (canGoBack) {
        await _controller.goBack();
      } else {
        Navigator.of(context).pop();
      }
    } on Object {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _openBrowser() async {
    try {
      await ExternalUrlLauncher.open(widget._uri);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't open your browser. Try again.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_canGoBack,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) {
        unawaited(_goBack());
      }
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget._subscribe ? "Subscribe to ${widget.login}" : "Report ${widget.login}"),
        leading: BackButton(onPressed: _goBack),
        actions: [
          if (widget._subscribe)
            IconButton(
              tooltip: "Open in browser",
              onPressed: _openBrowser,
              icon: const Icon(Icons.open_in_browser_rounded),
            ),
          IconButton(
            tooltip: widget._subscribe ? "Close subscription" : "Close report",
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_progress < 100 && !_loadFailed) LinearProgressIndicator(value: _progress / 100),
          if (_loadFailed)
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Couldn't load Twitch. Check your connection."),
                      TextButton.icon(
                        onPressed: _controller.reload,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text("Try again"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
