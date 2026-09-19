import "dart:async";
import "dart:math";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_chat.dart";
import "package:flow/api/twitch_polls.dart";
import "package:flow/api/twitch_predictions.dart";
import "package:flow/features/player/twitch_poll_card.dart";
import "package:flow/shared/external_url_opener.dart";
import "package:flow/shared/twitch/twitch_display_mappers.dart";
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
  final _pollSnapshot = ValueNotifier<TwitchChannelPoll?>(null);
  final _pendingTransactions = <(String, String, String, String, int), String>{};
  Timer? _timer;
  Timer? _presentationTimer;
  (TwitchChatController, Object)? _loading;
  String? _selected;
  String? _newest;
  String? _pinId;
  DateTime? _pinSeenAt;
  bool _showAll = false;
  final _collapsedPredictions = <String>{};
  bool _showTotals = false;
  final _predictionPhases = <String, String>{};
  final _predictionHighlights = <String, ({DateTime shownAt, DateTime expiresAt})>{};
  final _expiryTimers = <String, Timer>{};
  String? _dismissedPoll;
  String? _pollError;
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
      _pollSnapshot.value = null;
      _error.value = null;
      _selected = null;
      _newest = null;
      _pinId = null;
      _showAll = false;
      _collapsedPredictions.clear();
      _showTotals = false;
      _predictionPhases.clear();
      _predictionHighlights.clear();
      for (final timer in _expiryTimers.values) {
        timer.cancel();
      }
      _expiryTimers.clear();
      _dismissedPoll = null;
      _pollError = null;
    }
    if (oldWidget.controller != widget.controller || oldWidget.isVisible != widget.isVisible) {
      _schedule();
    }
  }

  void _schedule() {
    _timer?.cancel();
    _presentationTimer?.cancel();
    if (_isActive) {
      unawaited(_refresh());
      // Reconcile after missed socket updates and update the closing countdown.
      _timer = Timer.periodic(const Duration(seconds: 5), (_) => unawaited(_refresh()));
      _presentationTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        setState(() => _showTotals = !_showTotals);
      });
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
      final client = await controller.clientLoader();
      await Future.wait([
        () async {
          try {
            final data = await client.fetchPredictions(controller.channel);
            if (mounted && _loading == operation && controller == widget.controller) {
              _error.value = null;
              _reconcilePredictions(data.events);
              _snapshot.value = data;
            }
          } on Object {
            if (mounted && _loading == operation && controller == widget.controller) {
              _error.value = "Could not refresh predictions.";
            }
          }
        }(),
        () async {
          try {
            final data = await client.fetchPoll(controller.channel);
            if (mounted && _loading == operation && controller == widget.controller) {
              _pollError = null;
              _pollSnapshot.value = data;
            }
          } on Object {
            if (mounted && _loading == operation && controller == widget.controller) {
              setState(() => _pollError = "Could not refresh poll.");
            }
          }
        }(),
      ]);
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

  void _dismissPrediction(String id) {
    _expiryTimers.remove(id)?.cancel();
    setState(() => _predictionHighlights.remove(id));
  }

  void _reconcilePredictions(List<TwitchPrediction> events) {
    final now = DateTime.now();
    for (final event in events) {
      final phase = switch (event.status) {
        "RESOLVED" || "RESOLVE_PENDING" => "result",
        "CANCELED" || "CANCEL_PENDING" => "canceled",
        _ => "open",
      };
      final previous = _predictionPhases[event.id];
      _predictionPhases[event.id] = phase;
      if (phase == "canceled") {
        _predictionHighlights.remove(event.id);
        _expiryTimers.remove(event.id)?.cancel();
        continue;
      }
      // Refreshes update the data, but never resurrect a dismissed or expired phase.
      if (previous == phase) {
        continue;
      }
      final eligible = phase == "result"
          ? event.endedAt != null && now.difference(event.endedAt!) < const Duration(minutes: 5)
          : event.status == "ACTIVE" &&
                event.closesAt.difference(now) >= const Duration(seconds: 2);
      if (!eligible) {
        continue;
      }
      _collapsedPredictions.remove(event.id);
      final expiresAt = phase == "result" ? now.add(const Duration(seconds: 120)) : event.closesAt;
      _predictionHighlights[event.id] = (
        shownAt: phase == "result" ? event.endedAt! : event.createdAt,
        expiresAt: expiresAt,
      );
      _expiryTimers.remove(event.id)?.cancel();
      _expiryTimers[event.id] = Timer(expiresAt.difference(now), () {
        if (mounted) {
          _dismissPrediction(event.id);
        }
      });
    }
    for (final id in _predictionHighlights.keys.toList()) {
      if (!events.any((event) => event.id == id)) {
        _predictionHighlights.remove(id);
        _expiryTimers.remove(id)?.cancel();
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
    _presentationTimer?.cancel();
    for (final timer in _expiryTimers.values) {
      timer.cancel();
    }
    _snapshot.dispose();
    _pollSnapshot.dispose();
    _error.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_snapshot, _pollSnapshot, _error]),
    builder: (context, _) {
      final snapshot = _snapshot.value;
      final events = (snapshot?.events ?? const <TwitchPrediction>[])
          .where((event) => _predictionHighlights.containsKey(event.id))
          .toList();
      final pollData = _pollSnapshot.value;
      final poll = pollData?.poll;
      final error = (events.isEmpty ? _error.value : null) ?? (poll == null ? _pollError : null);
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
              (
                id: "prediction-${event.id}",
                createdAt: _predictionHighlights[event.id]!.shownAt,
                event: event,
              ),
            if (poll != null && poll.id != _dismissedPoll)
              (id: "poll-${poll.id}", createdAt: poll.startedAt, event: null),
          ]..sort((a, b) {
            final order = b.createdAt.compareTo(a.createdAt);
            return order == 0 ? a.id.compareTo(b.id) : order;
          });
      if (entries.isEmpty) {
        _selected = null;
        _newest = null;
        if (error != null) {
          return _retry(context, error);
        }
        return const SizedBox.shrink();
      }
      final newest = "${entries.first.id}:${entries.first.createdAt.microsecondsSinceEpoch}";
      if (_newest != newest || !entries.any((entry) => entry.id == _selected)) {
        _newest = newest;
        _selected = entries.first.id;
      }
      final index = entries.indexWhere((entry) => entry.id == _selected);
      Widget card(int index) => switch (entries[index].event) {
        final event? => _prediction(context, event),
        null =>
          entries[index].id.startsWith("poll-")
              ? TwitchPollCard(
                  key: ValueKey("poll-${poll!.id}"),
                  data: pollData!,
                  controller: widget.controller,
                  refresh: _refresh,
                  pendingTransactions: _pendingTransactions,
                  dismiss: () => setState(() => _dismissedPoll = poll.id),
                )
              : pin!.child,
      };
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_showAll && entries.length > 1)
              for (var position = 0; position < entries.length; position++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: GestureDetector(
                    key: ValueKey("highlight-select-${entries[position].id}"),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() {
                      _selected = entries[position].id;
                      _showAll = false;
                    }),
                    child: IgnorePointer(child: card(position)),
                  ),
                )
            else if (entries.length > 1)
              Stack(
                children: [
                  Positioned.fill(
                    bottom: 8,
                    child: Material(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: const ValueKey("highlight-stack-peek"),
                        onTap: () => setState(() => _showAll = true),
                        child: Semantics(
                          label: "Show all highlights",
                          button: true,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 12, 6, 0),
                    child: card(index),
                  ),
                ],
              )
            else
              card(index),
            if (error != null) _retry(context, error),
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
        tooltip: "Retry",
        onPressed: () => unawaited(_refresh()),
        icon: const Icon(Icons.refresh),
      ),
    ),
  );

  Widget _prediction(BuildContext context, TwitchPrediction event) {
    final colors = Theme.of(context).colorScheme;
    final expanded = !_showAll && !_collapsedPredictions.contains(event.id);
    final winner = event.outcomes
        .where((outcome) => outcome.id == event.winningOutcomeId)
        .firstOrNull;
    final title =
        winner?.title ??
        (event.outcomes.length == 2 && _showTotals
            ? event.outcomes.map((outcome) => formatCompactCount(outcome.points)).join(" vs ")
            : event.title);
    void toggleExpanded() => setState(() {
      if (expanded) {
        _collapsedPredictions.add(event.id);
      } else {
        _collapsedPredictions.remove(event.id);
      }
    });
    return Card.outlined(
      key: ValueKey("prediction-${event.id}"),
      margin: EdgeInsets.zero,
      color: Theme.of(context).scaffoldBackgroundColor,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: toggleExpanded,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 340;
              final action = FilledButton(
                onPressed: () => unawaited(_open(event)),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(event.isOpen ? "Predict" : "See Details"),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (winner != null) ...[
                              Transform.translate(
                                offset: const Offset(-1.5, 0),
                                child: const Icon(
                                  Icons.emoji_events_outlined,
                                  size: 20,
                                  semanticLabel: "Winner",
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!narrow) ...[const SizedBox(width: 8), action],
                      IconButton(
                        tooltip: expanded ? "Minimize prediction" : "Expand prediction",
                        style: IconButton.styleFrom(
                          minimumSize: const Size(32, 28),
                          fixedSize: const Size(32, 28),
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: toggleExpanded,
                        icon: Icon(
                          expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 20,
                        ),
                      ),
                      IconButton(
                        tooltip: "Close prediction",
                        style: IconButton.styleFrom(
                          minimumSize: const Size(32, 28),
                          fixedSize: const Size(32, 28),
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _dismissPrediction(event.id),
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
                    ],
                  ),
                  if (narrow) action,
                  if (expanded) ...[
                    const SizedBox(height: 6),
                    for (final (index, outcome) in event.outcomes.indexed)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                "${index + 1}. ${outcome.title}",
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
                      ),
                  ],
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value:
                        (_predictionHighlights[event.id]!.expiresAt
                                    .difference(DateTime.now())
                                    .inMilliseconds /
                                (winner != null
                                    ? 120000
                                    : max(
                                        1,
                                        event.closesAt.difference(event.createdAt).inMilliseconds,
                                      )))
                            .clamp(0.0, 1.0),
                    minHeight: 3,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              );
            },
          ),
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
        setState(() {
          _submitted = true;
          _amount.clear();
        });
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
      final selectedOutcome = event.selectedOutcomeId ?? (_submitted ? _outcome : null);
      final remaining = 250000 - event.pointsSpent;
      final maximum = min(snapshot?.balance ?? 0, remaining);
      final points = event.isPointsRestricted ? 0 : int.tryParse(_amount.text);
      final total = event.outcomes.fold(0, (sum, outcome) => sum + outcome.points);
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
          (!event.isPointsRestricted || selectedOutcome == null) &&
          unavailable == null &&
          _outcome != null &&
          (selectedOutcome == null || selectedOutcome == _outcome) &&
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
              Row(
                children: [
                  Expanded(
                    child: Text("Prediction", style: Theme.of(context).textTheme.titleMedium),
                  ),
                  IconButton(
                    tooltip: "Close prediction",
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      event.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    if (_status(event) case final status?)
                      Text(status, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final outcome in event.outcomes)
                      SizedBox(
                        width: (constraints.maxWidth - 12) / 2,
                        child: _outcomeTile(
                          context,
                          outcome,
                          total,
                          selected: (_outcome ?? event.selectedOutcomeId) == outcome.id,
                          winner: outcome.id == event.winningOutcomeId,
                          onTap:
                              !_submitting &&
                                  unavailable == null &&
                                  (selectedOutcome == null || selectedOutcome == outcome.id)
                              ? () => setState(() => _outcome = outcome.id)
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (event.pointsWon case final pointsWon? when pointsWon > 0)
                Text("You won ${_points(pointsWon)} points", textAlign: TextAlign.center),
              if (event.selectedOutcomeId != null)
                Text("Your prediction: ${_points(event.pointsSpent)} points"),
              if (unavailable != null && event.isOpen)
                Text(unavailable)
              else if (unavailable == null &&
                  (!event.isPointsRestricted || selectedOutcome == null)) ...[
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
                    decoration: const InputDecoration(
                      labelText: "Channel Points",
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
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
                        : "${selectedOutcome == null ? 'Predict with' : 'Add'} ${points == null ? '…' : _points(points)} points",
                  ),
                ),
              ],
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

Widget _outcomeTile(
  BuildContext context,
  TwitchPredictionOutcome outcome,
  int total, {
  required bool selected,
  required bool winner,
  required VoidCallback? onTap,
}) {
  final color = outcome.color == "PINK" ? const Color(0xFFE46BD4) : const Color(0xFF55AFFF);
  final fraction = total == 0 ? 0.0 : outcome.points / total;
  return Semantics(
    selected: selected,
    button: onTap != null,
    child: InkWell(
      key: ValueKey("prediction-outcome-${outcome.id}"),
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: selected ? color.withValues(alpha: .12) : null,
          border: Border.all(
            color: selected ? color : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (winner)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events_outlined, size: 16, color: color),
                  const SizedBox(width: 4),
                  const Text("Winner"),
                ],
              ),
            Text(
              outcome.title,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
            Text(
              "${(fraction * 100).round()}%",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: color),
            ),
            LinearProgressIndicator(
              value: fraction,
              color: color,
              minHeight: 6,
              borderRadius: BorderRadius.circular(6),
            ),
            const SizedBox(height: 8),
            for (final (icon, value, label) in [
              (Icons.toll_outlined, formatCompactCount(outcome.points), "Channel Points"),
              (
                Icons.trending_up_rounded,
                outcome.points == 0 ? "-:-" : "1:${(total / outcome.points).toStringAsFixed(2)}",
                "Return ratio",
              ),
              (Icons.people_outline_rounded, formatCompactCount(outcome.users), "Voters"),
              if (outcome.topPoints > 0)
                (
                  Icons.workspace_premium_outlined,
                  formatCompactCount(outcome.topPoints),
                  "Top vote${outcome.topPredictorName == null ? '' : ' · ${outcome.topPredictorName}'}",
                ),
            ])
              Tooltip(
                message: label,
                excludeFromSemantics: true,
                child: Semantics(
                  label: "$label: $value",
                  excludeSemantics: true,
                  child: Row(
                    children: [
                      Icon(icon, size: 16, color: color),
                      const SizedBox(width: 4),
                      Flexible(child: Text(value, style: Theme.of(context).textTheme.bodySmall)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

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
