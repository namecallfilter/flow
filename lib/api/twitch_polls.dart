class TwitchPollChoice {
  const TwitchPollChoice({required this.id, required this.title, required this.votes});

  final String id;
  final String title;
  final int votes;
}

class TwitchPoll {
  const TwitchPoll({
    required this.id,
    required this.title,
    required this.status,
    required this.choices,
    required this.startedAt,
    required this.closesAt,
    required this.votes,
    this.viewerStateAvailable = false,
    this.baseVotes = 0,
    this.votedChoiceIds = const {},
    this.pointsVoteCost,
    this.multichoiceEnabled = false,
  });

  final String id;
  final String title;
  final String status;
  final List<TwitchPollChoice> choices;
  final DateTime startedAt;
  final DateTime closesAt;
  final int votes;
  final bool viewerStateAvailable;
  final int baseVotes;
  final Set<String> votedChoiceIds;
  final int? pointsVoteCost;
  final bool multichoiceEnabled;

  bool get isOpen => status == "ACTIVE" && DateTime.now().isBefore(closesAt);
}

class TwitchChannelPoll {
  const TwitchChannelPoll({
    required this.channelId,
    this.poll,
    this.viewerId,
    this.balance,
    this.isBanned = false,
  });

  final String channelId;
  final TwitchPoll? poll;
  final String? viewerId;
  final int? balance;
  final bool isBanned;
}
