import "dart:async";
import "dart:math";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_chat.dart";
import "package:flow/api/twitch_predictions.dart";
import "package:flow/shared/external_url_opener.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";

class TwitchPredictionCard extends StatefulWidget {
  const TwitchPredictionCard({
    required this.controller,
    required this.isVisible,
    required this.showSheet,
    this.pinnedChat,
    super.key,
  });

  final TwitchChatController controller;
  final bool isVisible;
  final Future<void> Function(WidgetBuilder builder) showSheet;
  final ({String id, DateTime? createdAt, Widget child})? pinnedChat;

  @override
  State<TwitchPredictionCard> createState() => _TwitchPredictionCardState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TwitchChatController>("controller", controller));
    properties.add(FlagProperty("isVisible", value: isVisible, ifTrue: "visible"));
    properties.add(ObjectFlagProperty<Object>.has("showSheet", showSheet));
    properties.add(ObjectFlagProperty<Object>.has("pinnedChat", pinnedChat));
  }
}

class _TwitchPredictionCardState extends State<TwitchPredictionCard> with WidgetsBindingObserver {
  final _snapshot = ValueNotifier<TwitchChannelPredictions?>(null);
  final _pendingTransactions = <(String, String, String, String, int), String>{};
  Timer? _timer;
  (TwitchChatController, Object)? _loading;
  String? _selected;
  String? _newest;
  String? _pinId;
  DateTime? _pinSeenAt;
  int _predictionRevision = 0;
  final _error = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.predictionUpdates.addListener(_predictionChanged);
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _schedule();

  @override
  void didUpdateWidget(TwitchPredictionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.predictionUpdates.removeListener(_predictionChanged);
      widget.controller.predictionUpdates.addListener(_predictionChanged);
      _snapshot.value = null;
      _error.value = null;
      _selected = null;
      _newest = null;
      _pinId = null;
    }
    if (oldWidget.controller != widget.controller || oldWidget.isVisible != widget.isVisible) {
      _schedule();
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (_isActive) {
      unawaited(_refresh());
      // Reconcile after missed socket updates and update the closing countdown.
      _timer = Timer.periodic(const Duration(seconds: 5), (_) => unawaited(_refresh()));
    }
  }

  bool get _isActive =>
      widget.isVisible &&
      (WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed) ==
          AppLifecycleState.resumed;

  void _predictionChanged() {
    _predictionRevision++;
    if (_isActive) {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    final controller = widget.controller;
    if (_loading?.$1 == controller) {
      return;
    }
    final operation = (controller, Object());
    final revision = _predictionRevision;
    _loading = operation;
    try {
      final data = await (await controller.clientLoader()).fetchPredictions(controller.channel);
      if (mounted && _loading == operation && controller == widget.controller) {
        _error.value = null;
        _snapshot.value = data;
      }
    } on Object {
      if (mounted && _loading == operation && controller == widget.controller) {
        _error.value = "Could not refresh predictions.";
      }
    } finally {
      if (_loading == operation) {
        _loading = null;
        if (mounted &&
            controller == widget.controller &&
            _isActive &&
            revision != _predictionRevision) {
          unawaited(_refresh());
        }
      }
    }
  }

  Future<void> _open(TwitchPrediction event) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await widget.showSheet(
      (context) => _PredictionSheet(
        event: event,
        controller: widget.controller,
        snapshot: _snapshot,
        refresh: _refresh,
        refreshError: _error,
        pendingTransactions: _pendingTransactions,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.predictionUpdates.removeListener(_predictionChanged);
    _timer?.cancel();
    _snapshot.dispose();
    _error.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_snapshot, _error]),
    builder: (context, _) {
      final snapshot = _snapshot.value;
      final events = snapshot?.events ?? const <TwitchPrediction>[];
      final pin = widget.pinnedChat;
      if (_pinId != pin?.id) {
        _pinId = pin?.id;
        _pinSeenAt = DateTime.now();
      }
      final entries =
          <({String id, DateTime createdAt, TwitchPrediction? event})>[
            if (pin != null)
              (id: "pin-${pin.id}", createdAt: pin.createdAt ?? _pinSeenAt!, event: null),
            for (final event in events)
              (id: "prediction-${event.id}", createdAt: event.createdAt, event: event),
          ]..sort((a, b) {
            final order = b.createdAt.compareTo(a.createdAt);
            return order == 0 ? a.id.compareTo(b.id) : order;
          });
      if (entries.isEmpty) {
        _selected = null;
        _newest = null;
        if (_error.value case final error?) {
          return _retry(context, error);
        }
        return const SizedBox.shrink();
      }
      if (_newest != entries.first.id || !entries.any((entry) => entry.id == _selected)) {
        _newest = entries.first.id;
        _selected = _newest;
      }
      final index = entries.indexWhere((entry) => entry.id == _selected);
      final event = entries[index].event;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (entries.length > 1)
              Material(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: "Previous highlight",
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(
                        () => _selected = entries[(index - 1) % entries.length].id,
                      ),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text("${index + 1} / ${entries.length}"),
                    IconButton(
                      tooltip: "Next highlight",
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(
                        () => _selected = entries[(index + 1) % entries.length].id,
                      ),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
            if (event == null) pin!.child else _prediction(context, event),
            if (events.isEmpty && _error.value != null) _retry(context, _error.value!),
          ],
        ),
      );
    },
  );

  Widget _retry(BuildContext context, String error) => Material(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: ListTile(
      dense: true,
      title: Text(error, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        tooltip: "Retry predictions",
        onPressed: () => unawaited(_refresh()),
        icon: const Icon(Icons.refresh),
      ),
    ),
  );

  Widget _prediction(BuildContext context, TwitchPrediction event) {
    final colors = Theme.of(context).colorScheme;
    return Card.outlined(
      key: ValueKey("prediction-${event.id}"),
      margin: const EdgeInsets.only(bottom: 4),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Predict with Channel Points",
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => unawaited(_open(event)),
                  child: Text(event.isOpen ? "Predict" : "Results"),
                ),
              ],
            ),
            for (final outcome in event.outcomes.take(2))
              Row(
                children: [
                  Expanded(
                    child: Text(
                      outcome.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _points(outcome.points),
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            if (event.outcomes.length > 2)
              Text(
                "+${event.outcomes.length - 2} outcomes",
                style: Theme.of(context).textTheme.labelSmall,
              ),
            if (_status(event) case final status?) ...[
              const SizedBox(height: 6),
              Text(
                status,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: colors.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PredictionSheet extends StatefulWidget {
  const _PredictionSheet({
    required this.event,
    required this.controller,
    required this.snapshot,
    required this.refresh,
    required this.refreshError,
    required this.pendingTransactions,
  });

  final TwitchPrediction event;
  final TwitchChatController controller;
  final ValueNotifier<TwitchChannelPredictions?> snapshot;
  final Future<void> Function() refresh;
  final ValueListenable<String?> refreshError;
  final Map<(String, String, String, String, int), String> pendingTransactions;

  @override
  State<_PredictionSheet> createState() => _PredictionSheetState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TwitchPrediction>("event", event));
    properties.add(DiagnosticsProperty<TwitchChatController>("controller", controller));
    properties.add(
      DiagnosticsProperty<ValueNotifier<TwitchChannelPredictions?>>("snapshot", snapshot),
    );
    properties.add(ObjectFlagProperty<Object>.has("refresh", refresh));
    properties.add(ObjectFlagProperty<Object>.has("refreshError", refreshError));
    properties.add(ObjectFlagProperty<Object>.has("pendingTransactions", pendingTransactions));
  }
}

class _PredictionSheetState extends State<_PredictionSheet> {
  final _amount = TextEditingController();
  String? _outcome;
  String? _error;
  bool _acceptTerms = false;
  bool _submitting = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _outcome = widget.event.selectedOutcomeId;
    unawaited(widget.refresh());
  }

  Future<void> _submit(TwitchPrediction event, TwitchChannelPredictions snapshot) async {
    final points = event.isPointsRestricted ? 0 : int.tryParse(_amount.text);
    if (_submitting || _outcome == null || points == null) {
      return;
    }
    final outcomeId = _outcome!;
    final choice = (snapshot.viewerId!, snapshot.channelId, event.id, outcomeId, points);
    final transactionId = widget.pendingTransactions.putIfAbsent(choice, () {
      final hex = List.generate(
        4,
        (_) => Random.secure().nextInt(1 << 32).toRadixString(16).padLeft(8, "0"),
      ).join();
      return "${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}";
    });
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final client = await widget.controller.clientLoader();
      await client.makePrediction(
        channelLogin: widget.controller.channel,
        eventId: event.id,
        outcomeId: outcomeId,
        points: points,
        transactionId: transactionId,
        viewerId: snapshot.viewerId!,
        acceptTerms: _acceptTerms,
      );
      if (widget.pendingTransactions[choice] == transactionId) {
        widget.pendingTransactions.remove(choice);
      }
      if (mounted) {
        setState(() => _submitted = true);
      }
      await widget.refresh();
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _error = error is TwitchApiException
              ? error.message
              : "Could not confirm your prediction. Retry with the same amount.",
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.snapshot, widget.refreshError]),
    builder: (context, _) {
      final snapshot = widget.snapshot.value;
      final current = snapshot?.events.where((event) => event.id == widget.event.id).firstOrNull;
      final event = current ?? widget.event;
      final remaining = 250000 - event.pointsSpent;
      final maximum = min(snapshot?.balance ?? 0, remaining);
      final points = event.isPointsRestricted ? 0 : int.tryParse(_amount.text);
      final unavailable = snapshot?.viewerId == null
          ? "Sign in to Twitch to predict."
          : snapshot!.viewerId == snapshot.channelId
          ? "You cannot predict on your own channel."
          : !event.viewerStateAvailable
          ? "Your prediction details are unavailable. Try again."
          : event.restriction != null && !event.isPointsRestricted
          ? "Twitch has restricted participation in this prediction."
          : current == null || !event.isOpen
          ? "Predictions are closed."
          : !event.isPointsRestricted && snapshot.balance == null
          ? "Your Channel Points balance is unavailable. Try again."
          : !event.isPointsRestricted && maximum < 1
          ? remaining < 1
                ? "You have reached the 250,000-point limit for this prediction."
                : "You do not have any Channel Points available for this prediction."
          : null;
      final enabled =
          !_submitting &&
          !_submitted &&
          unavailable == null &&
          _outcome != null &&
          (event.selectedOutcomeId == null || event.selectedOutcomeId == _outcome) &&
          points != null &&
          (event.isPointsRestricted || points >= 1 && points <= maximum) &&
          (snapshot!.hasAcceptedTerms || _acceptTerms);
      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Predict with Channel Points", style: Theme.of(context).textTheme.labelMedium),
              Text(event.title, style: Theme.of(context).textTheme.titleLarge),
              if (_status(event) case final status?) Text(status),
              const SizedBox(height: 12),
              for (final outcome in event.outcomes)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  enabled:
                      !_submitting &&
                      !_submitted &&
                      unavailable == null &&
                      (event.selectedOutcomeId == null || event.selectedOutcomeId == outcome.id),
                  selected: (_outcome ?? event.selectedOutcomeId) == outcome.id,
                  leading: Icon(
                    outcome.id == event.winningOutcomeId
                        ? Icons.emoji_events_outlined
                        : (_outcome ?? event.selectedOutcomeId) == outcome.id
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: outcome.color == "PINK"
                        ? const Color(0xFFE46BD4)
                        : const Color(0xFF55AFFF),
                  ),
                  title: Text(outcome.title),
                  subtitle: Text(
                    "${_points(outcome.points)} points · ${_points(outcome.users)} viewers",
                  ),
                  onTap: () => setState(() => _outcome = outcome.id),
                ),
              if (event.selectedOutcomeId != null)
                Text(
                  "Your prediction: ${_points(event.pointsSpent)} points. Your outcome cannot be changed.",
                ),
              if (unavailable != null)
                Text(unavailable)
              else if (!_submitted) ...[
                if (event.isPointsRestricted)
                  const Text(
                    "In your region, you can predict with 0 points. You cannot win Channel Points.",
                  )
                else ...[
                  Text("Balance: ${_points(snapshot!.balance ?? 0)} Channel Points"),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amount,
                    enabled: !_submitting,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: "Channel Points",
                      helperText: "1–${_points(maximum)} points",
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  event.isPointsRestricted
                      ? "You cannot change your pick."
                      : "Your points will be spent on the selected outcome. You cannot change your pick.",
                ),
                if (!snapshot!.hasAcceptedTerms) ...[
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("I accept Twitch's Predictions Terms & Conditions"),
                    value: _acceptTerms,
                    onChanged: _submitting
                        ? null
                        : (value) => setState(() => _acceptTerms = value ?? false),
                  ),
                  TextButton(
                    onPressed: () async {
                      try {
                        await ExternalUrlLauncher.open(
                          Uri.parse(
                            "https://www.twitch.tv/p/legal/predictions-terms-and-conditions/",
                          ),
                        );
                      } on Object catch (error) {
                        if (mounted) {
                          setState(() => _error = error.toString());
                        }
                      }
                    },
                    child: const Text("Read Twitch's prediction terms"),
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: enabled ? () => unawaited(_submit(event, snapshot)) : null,
                  child: Text(
                    _submitting
                        ? "Submitting…"
                        : "Predict with ${points == null ? '…' : _points(points)} points",
                  ),
                ),
              ],
              if (_submitted)
                const Text("Prediction submitted.", semanticsLabel: "Prediction submitted"),
              if (_error ?? widget.refreshError.value case final error?)
                Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ),
        ),
      );
    },
  );
}

String _points(int value) =>
    value.toString().replaceAllMapped(RegExp(r"\B(?=(\d{3})+(?!\d))"), (_) => ",");

String? _status(TwitchPrediction event) {
  if (event.isOpen) {
    return "Closes in ${event.closesAt.difference(DateTime.now()).inSeconds}s";
  }
  if (event.status == "RESOLVED" || event.status == "RESOLVE_PENDING") {
    final winner = event.outcomes
        .where((outcome) => outcome.id == event.winningOutcomeId)
        .firstOrNull;
    return winner == null ? "Resolved" : "Winner: ${winner.title}";
  }
  return event.status == "CANCELED" || event.status == "CANCEL_PENDING"
      ? "Canceled · points returned"
      : null;
}
