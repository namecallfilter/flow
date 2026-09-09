import "dart:async";

import "package:flow/features/player/twitch_report_screen.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
// The installed WebView package's platform interface supplies its test doubles.
// ignore: depend_on_referenced_packages
import "package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart";

void main() {
  late _ReportWebViewPlatform platform;
  setUp(() => WebViewPlatform.instance = platform = _ReportWebViewPlatform());

  testWidgets("loads the official report page and keeps HTTPS links in the WebView", (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: TwitchReportScreen(login: "creator")));
    await tester.pump();
    expect(platform.controller.requests.single, Uri.parse("https://www.twitch.tv/creator/report"));
    expect(platform.controller.javaScriptMode, JavaScriptMode.unrestricted);
    for (final url in [
      "https://www.twitch.tv/creator/report",
      "https://www.twitch.tv/login",
      "https://passport.twitch.tv/login",
      "https://help.twitch.tv/s/article/how-to-file-a-user-report",
    ]) {
      expect(
        await platform.delegate.onNavigationRequest!(
          NavigationRequest(url: url, isMainFrame: true),
        ),
        NavigationDecision.navigate,
      );
    }
    for (final url in [
      "twitch://report/creator",
      "intent://creator/report#Intent;scheme=twitch;end",
      "javascript:alert(1)",
      "file:///private",
      "http://www.twitch.tv/login",
    ]) {
      expect(
        await platform.delegate.onNavigationRequest!(
          NavigationRequest(url: url, isMainFrame: true),
        ),
        NavigationDecision.prevent,
      );
    }
    platform.delegate.onProgress!(100);
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets("WebView Back stays in the report and Close returns to chat", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const TwitchReportScreen(login: "creator")),
              ),
              child: const Text("Chat"),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text("Chat"));
    await tester.pumpAndSettle();
    platform.controller.hasHistory = true;
    platform.delegate.onUrlChange!(const UrlChange(url: "https://www.twitch.tv/login"));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(platform.controller.backCount, 1);
    expect(find.byType(TwitchReportScreen), findsOneWidget);
    await tester.tap(find.byTooltip("Close report"));
    await tester.pumpAndSettle();
    expect(find.text("Chat"), findsOneWidget);
    expect(find.byType(TwitchReportScreen), findsNothing);
  });

  testWidgets("main-frame failures offer retry without leaving the app", (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TwitchReportScreen(login: "creator")));
    await tester.pump();
    for (final isMainFrame in [false, true]) {
      platform.delegate.onWebResourceError!(
        WebResourceError(errorCode: -2, description: "Offline", isForMainFrame: isMainFrame),
      );
      await tester.pump();
      expect(find.text("Try again"), findsNWidgets(isMainFrame ? 1 : 0));
    }
    await tester.tap(find.text("Try again"));
    expect(platform.controller.reloadCount, 1);
    platform.delegate.onPageStarted!("https://www.twitch.tv/creator/report");
    await tester.pump();
    expect(find.text("Try again"), findsNothing);
  });

  testWidgets("closing during WebView initialization ignores the late result", (tester) async {
    final initialization = Completer<void>();
    platform.initialization = initialization.future;
    await tester.pumpWidget(const MaterialApp(home: TwitchReportScreen(login: "creator")));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    initialization.completeError(StateError("WebView was closed"));
    await tester.pump();
    expect(platform.controller.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets("closing while browser history is pending ignores its late error", (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TwitchReportScreen(login: "creator")));
    await tester.pump();
    final history = Completer<bool>();
    platform.controller.pendingHistory = history.future;
    platform.delegate.onUrlChange!(const UrlChange(url: "https://www.twitch.tv/login"));
    await tester.pumpWidget(const SizedBox.shrink());
    history.completeError(StateError("WebView was closed"));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

class _ReportWebViewPlatform extends WebViewPlatform {
  Future<void>? initialization;
  late _ReportWebViewController controller;
  late _ReportNavigationDelegate delegate;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => controller = _ReportWebViewController(params, initialization: initialization);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => delegate = _ReportNavigationDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(PlatformWebViewWidgetCreationParams params) =>
      _ReportWebViewWidget(params);
}

class _ReportWebViewController extends PlatformWebViewController {
  _ReportWebViewController(super.params, {this.initialization}) : super.implementation();

  final Future<void>? initialization;
  Future<bool>? pendingHistory;
  final requests = <Uri>[];
  JavaScriptMode? javaScriptMode;
  bool hasHistory = false;
  int backCount = 0;
  int reloadCount = 0;

  @override
  Future<void> loadRequest(LoadRequestParams params) async => requests.add(params.uri);

  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async => javaScriptMode = mode;

  @override
  Future<void> setUserAgent(String? userAgent) async => initialization;

  @override
  Future<void> setPlatformNavigationDelegate(PlatformNavigationDelegate handler) async {}

  @override
  Future<bool> canGoBack() async => pendingHistory ?? hasHistory;

  @override
  Future<void> goBack() async => backCount++;

  @override
  Future<void> reload() async => reloadCount++;
}

class _ReportNavigationDelegate extends PlatformNavigationDelegate {
  _ReportNavigationDelegate(super.params) : super.implementation();

  NavigationRequestCallback? onNavigationRequest;
  PageEventCallback? onPageStarted;
  PageEventCallback? onPageFinished;
  ProgressCallback? onProgress;
  WebResourceErrorCallback? onWebResourceError;
  UrlChangeCallback? onUrlChange;

  @override
  Future<void> setOnNavigationRequest(NavigationRequestCallback callback) async =>
      onNavigationRequest = callback;

  @override
  Future<void> setOnPageStarted(PageEventCallback callback) async => onPageStarted = callback;

  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async => onPageFinished = callback;

  @override
  Future<void> setOnProgress(ProgressCallback callback) async => onProgress = callback;

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async =>
      onWebResourceError = callback;

  @override
  Future<void> setOnUrlChange(UrlChangeCallback callback) async => onUrlChange = callback;
}

class _ReportWebViewWidget extends PlatformWebViewWidget {
  _ReportWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
