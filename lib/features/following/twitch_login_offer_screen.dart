import "dart:async";

import "package:flow/api/twitch_auth.dart";
import "package:flow/app/radius.dart";
import "package:flow/app/spacing.dart";
import "package:flow/features/following/twitch_login_screen.dart";
import "package:flow/shared/widgets/page_header_layout.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

class TwitchLoginOfferScreen extends StatefulWidget {
  const TwitchLoginOfferScreen({
    required this.authController,
    required this.onConnected,
    required this.onContinue,
    super.key,
    this.openTwitchLogin,
    this.statusMessage,
    this.showCloseButton = false,
  });

  final TwitchAuthController authController;
  final ValueChanged<TwitchAuthConnection> onConnected;
  final AsyncCallback onContinue;
  final TwitchLoginOpener? openTwitchLogin;
  final String? statusMessage;
  final bool showCloseButton;

  @override
  State<TwitchLoginOfferScreen> createState() => _TwitchLoginOfferScreenState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<TwitchAuthController>(
        "authController",
        authController,
      ),
    );
    properties.add(
      ObjectFlagProperty<ValueChanged<TwitchAuthConnection>>.has(
        "onConnected",
        onConnected,
      ),
    );
    properties.add(
      ObjectFlagProperty<AsyncCallback>.has("onContinue", onContinue),
    );
    properties.add(
      ObjectFlagProperty<TwitchLoginOpener?>.has(
        "openTwitchLogin",
        openTwitchLogin,
      ),
    );
    properties.add(StringProperty("statusMessage", statusMessage));
    properties.add(
      DiagnosticsProperty<bool>("showCloseButton", showCloseButton),
    );
  }
}

class _TwitchLoginOfferScreenState extends State<TwitchLoginOfferScreen> {
  bool _isLoggingIn = false;
  bool _isContinuing = false;

  Future<void> _logIn() async {
    setState(() => _isLoggingIn = true);

    try {
      if (!widget.authController.config.isConfigured) {
        throw TwitchAuthException(
          "Set TWITCH_CLIENT_ID with --dart-define-from-file=.env to start Twitch auth.",
        );
      }
      final opener = widget.openTwitchLogin ?? openTwitchLoginScreen;
      final connection = await opener(context, widget.authController);
      if (mounted && connection != null) {
        widget.onConnected(connection);
      }
    } on TwitchAuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoggingIn = false);
      }
    }
  }

  Future<void> _continue() async {
    setState(() => _isContinuing = true);
    try {
      await widget.onContinue();
    } finally {
      if (mounted) {
        setState(() => _isContinuing = false);
      }
    }
  }

  Widget _buildWelcome(ThemeData theme, String? statusMessage) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        "Welcome to Flow",
        textAlign: TextAlign.center,
        style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        "Log in with Twitch to see the channels you follow.",
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurface.withValues(
            alpha: 0.62,
          ),
          height: 1.45,
        ),
      ),
      if (statusMessage != null) ...[
        const SizedBox(height: AppSpacing.lg),
        Container(
          key: const ValueKey("login_offer_status"),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer.withValues(
              alpha: 0.72,
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Text(
            statusMessage,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onErrorContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ],
  );

  Widget _buildActions({
    required bool placeholder,
    required double bottomInset,
  }) {
    final actions = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          key: placeholder ? null : const ValueKey("login_offer_button"),
          onPressed: placeholder || _isLoggingIn || _isContinuing
              ? null
              : () => unawaited(_logIn()),
          icon: _isLoggingIn
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.login),
          label: const Text("Log in with Twitch"),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          key: placeholder ? null : const ValueKey("login_offer_continue"),
          onPressed: placeholder || _isLoggingIn || _isContinuing
              ? null
              : () => unawaited(_continue()),
          child: const Text("Continue without an account"),
        ),
      ],
    );
    final insetActions = Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: actions,
    );
    if (!placeholder) {
      return insetActions;
    }
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Opacity(opacity: 0, child: insetActions),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusMessage = widget.statusMessage;
    final safePadding = MediaQuery.paddingOf(context);

    return Scaffold(
      key: const ValueKey("login_offer_screen"),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight > AppSpacing.xl * 2
                        ? constraints.maxHeight - AppSpacing.xl * 2
                        : 0,
                    maxWidth: 520,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        _buildActions(
                          placeholder: true,
                          bottomInset: safePadding.bottom,
                        ),
                        const Spacer(),
                        _buildWelcome(theme, statusMessage),
                        const Spacer(),
                        _buildActions(
                          placeholder: false,
                          bottomInset: safePadding.bottom,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.showCloseButton)
            Positioned(
              left: AppSpacing.sm,
              top: safePadding.top + AppSpacing.md,
              child: SizedBox.square(
                dimension: PageHeaderLayout.searchFieldHeight,
                child: IconButton(
                  key: const ValueKey("login_offer_close"),
                  tooltip: "Close",
                  onPressed: _isLoggingIn || _isContinuing ? null : () => unawaited(_continue()),
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Future<TwitchAuthConnection?> openTwitchLoginOfferScreen(
  BuildContext context,
  TwitchAuthController authController, {
  TwitchLoginOpener? openTwitchLogin,
}) => Navigator.of(context, rootNavigator: true).push<TwitchAuthConnection>(
  MaterialPageRoute(
    builder: (routeContext) => TwitchLoginOfferScreen(
      authController: authController,
      openTwitchLogin: openTwitchLogin,
      showCloseButton: true,
      onConnected: (connection) => Navigator.of(routeContext).pop(connection),
      onContinue: () async => Navigator.of(routeContext).pop(),
    ),
  ),
);
