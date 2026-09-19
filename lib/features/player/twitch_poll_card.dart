import "dart:async";
import "dart:math";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_chat.dart";
import "package:flow/api/twitch_polls.dart";
import "package:flow/shared/twitch/twitch_display_mappers.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

class TwitchPollCard extends StatefulWidget {
  const TwitchPollCard({
    required this.data,
    required this.controller,
    required this.refresh,
    required this.dismiss,
    required this.pendingTransactions,
    super.key,
  });

  final TwitchChannelPoll data;
  final TwitchChatController controller;
  final Future<void> Function() refresh;
  final VoidCallback dismiss;
  final Map<(String, String, String, String, int), String> pendingTransactions;

  @override
  State<TwitchPollCard> createState() => _TwitchPollCardState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TwitchChannelPoll>("data", data));
    properties.add(DiagnosticsProperty<TwitchChatController>("controller", controller));
    properties.add(ObjectFlagProperty<Object>.has("refresh", refresh));
    properties.add(ObjectFlagProperty<VoidCallback>.has("dismiss", dismiss));
    properties.add(ObjectFlagProperty<Object>.has("pendingTransactions", pendingTransactions));
  }
}

class _TwitchPollCardState extends State<TwitchPollCard> {
  bool _expanded = false;
  bool _submitting = false;
  String? _selected;
  String? _error;
  final _confirmedChoices = <String>{};

  @override
  void didUpdateWidget(TwitchPollCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.viewerId != widget.data.viewerId ||
        oldWidget.data.channelId != widget.data.channelId ||
        oldWidget.data.poll?.id != widget.data.poll?.id) {
      _selected = null;
      _confirmedChoices.clear();
      _error = null;
    }
  }

  Future<void> _vote(int points) async {
    final data = widget.data;
    final poll = data.poll!;
    final controller = widget.controller;
    final refresh = widget.refresh;
    final choice = _selected ?? poll.votedChoiceIds.firstOrNull;
    if (_submitting || choice == null || data.viewerId == null) {
      return;
    }
    final key = (data.viewerId!, data.channelId, "poll-${poll.id}", choice, points);
    final voteId = widget.pendingTransactions.putIfAbsent(
      key,
      () => List.generate(
        4,
        (_) => Random.secure().nextInt(1 << 32).toRadixString(16).padLeft(8, "0"),
      ).join(),
    );
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final client = await controller.clientLoader();
      await client.voteInPoll(
        channelLogin: controller.channel,
        pollId: poll.id,
        choiceId: choice,
        voteId: voteId,
        viewerId: data.viewerId!,
        points: points,
      );
      if (widget.pendingTransactions[key] == voteId) {
        widget.pendingTransactions.remove(key);
      }
      if (mounted && widget.data.viewerId == data.viewerId && widget.data.poll?.id == poll.id) {
        _confirmedChoices.add(choice);
      }
      await refresh();
    } on Object catch (error) {
      if (mounted && widget.data.viewerId == data.viewerId && widget.data.poll?.id == poll.id) {
        setState(
          () => _error = error is TwitchApiException
              ? error.message
              : "Could not confirm your vote. Try again.",
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final poll = data.poll!;
    final colors = Theme.of(context).colorScheme;
    final confirmedChoices = {...poll.votedChoiceIds, ..._confirmedChoices};
    final voted = poll.baseVotes > 0 || confirmedChoices.isNotEmpty;
    final cost = voted ? (data.viewerId == data.channelId ? null : poll.pointsVoteCost) : 0;
    final unavailable = data.viewerId == null
        ? "Sign in to vote."
        : data.isBanned
        ? "Voting is unavailable."
        : !poll.viewerStateAvailable
        ? "Voting details are unavailable."
        : voted && cost == null
        ? "Voted"
        : cost != null && cost > (data.balance ?? 0)
        ? "Not enough Channel Points."
        : null;
    final total = poll.votes;
    final maximum = poll.choices.fold(0, (value, choice) => max(value, choice.votes));
    return Card.outlined(
      margin: EdgeInsets.zero,
      color: Theme.of(context).scaffoldBackgroundColor,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          poll.isOpen ? "Current Poll" : "Poll Results",
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Text(
                          poll.title,
                          maxLines: _expanded ? 3 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _expanded ? "Minimize poll" : "Expand poll",
                    style: IconButton.styleFrom(
                      minimumSize: const Size(32, 28),
                      fixedSize: const Size(32, 28),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                    ),
                  ),
                  IconButton(
                    tooltip: "Close poll",
                    style: IconButton.styleFrom(
                      minimumSize: const Size(32, 28),
                      fixedSize: const Size(32, 28),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: widget.dismiss,
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final choice in poll.choices)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Material(
                          color: colors.surfaceContainerHigh,
                          child: InkWell(
                            key: ValueKey("poll-choice-${choice.id}"),
                            onTap:
                                poll.isOpen &&
                                    !_submitting &&
                                    unavailable == null &&
                                    (poll.multichoiceEnabled ||
                                        confirmedChoices.isEmpty ||
                                        confirmedChoices.contains(choice.id))
                                ? () => setState(() => _selected = choice.id)
                                : null,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: total == 0
                                          ? 0
                                          : (choice.votes / total).clamp(0, 1),
                                      child: ColoredBox(
                                        color: colors.primary.withValues(alpha: .18),
                                        child: const SizedBox.expand(),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                  child: Row(
                                    children: [
                                      Icon(
                                        confirmedChoices.contains(choice.id)
                                            ? Icons.check_circle
                                            : !poll.isOpen && choice.votes == maximum && maximum > 0
                                            ? Icons.emoji_events_outlined
                                            : _selected == choice.id
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_off,
                                        size: 18,
                                        color:
                                            confirmedChoices.contains(choice.id) ||
                                                _selected == choice.id
                                            ? colors.primary
                                            : colors.onSurfaceVariant,
                                        semanticLabel: confirmedChoices.contains(choice.id)
                                            ? "Voted"
                                            : null,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          choice.title,
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "${total == 0 ? 0 : (choice.votes * 100 / total).round()}% (${formatCompactCount(choice.votes)})",
                                        style: Theme.of(context).textTheme.labelMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (poll.isOpen)
                    Row(
                      children: [
                        Flexible(
                          child: FilledButton(
                            onPressed:
                                !_submitting &&
                                    (_selected != null || poll.votedChoiceIds.isNotEmpty) &&
                                    unavailable == null &&
                                    cost != null
                                ? () => unawaited(_vote(cost))
                                : null,
                            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                            child: Text(
                              _submitting
                                  ? "Voting…"
                                  : (cost ?? 0) > 0
                                  ? "Extra vote · $cost points"
                                  : voted
                                  ? "Voted"
                                  : "Vote",
                            ),
                          ),
                        ),
                        if (unavailable != null && unavailable != "Voted") ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(unavailable, style: Theme.of(context).textTheme.bodySmall),
                          ),
                        ],
                      ],
                    ),
                  if (_error != null) Text(_error!, style: TextStyle(color: colors.error)),
                ],
              ),
            ),
          if (poll.isOpen)
            LinearProgressIndicator(
              value:
                  (poll.closesAt.difference(DateTime.now()).inMilliseconds /
                          max(1, poll.closesAt.difference(poll.startedAt).inMilliseconds))
                      .clamp(0.0, 1.0),
              minHeight: 3,
            ),
        ],
      ),
    );
  }
}
