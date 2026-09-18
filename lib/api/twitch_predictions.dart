class TwitchPredictionOutcome {
  const TwitchPredictionOutcome({
    required this.id,
    required this.title,
    required this.points,
    required this.users,
    required this.color,
  });

  final String id;
  final String title;
  final int points;
  final int users;
  final String color;
}

class TwitchPrediction {
  const TwitchPrediction({
    required this.id,
    required this.title,
    required this.status,
    required this.outcomes,
    required this.closesAt,
    this.restriction,
    this.viewerStateAvailable = false,
    this.selectedOutcomeId,
    this.pointsSpent = 0,
    this.winningOutcomeId,
  });

  final String id;
  final String title;
  final String status;
  final List<TwitchPredictionOutcome> outcomes;
  final DateTime closesAt;
  final String? restriction;
  final bool viewerStateAvailable;
  final String? selectedOutcomeId;
  final int pointsSpent;
  final String? winningOutcomeId;

  bool get isOpen => status == "ACTIVE" && DateTime.now().isBefore(closesAt);
  bool get isPointsRestricted =>
      restriction == "REGION_LOCKED" || restriction == "CATEGORY_REGION_LOCKED";
}

class TwitchChannelPredictions {
  const TwitchChannelPredictions({
    required this.channelId,
    required this.events,
    this.viewerId,
    this.balance,
    this.hasAcceptedTerms = false,
  });

  final String channelId;
  final List<TwitchPrediction> events;
  final String? viewerId;
  final int? balance;
  final bool hasAcceptedTerms;
}
