class TwitchRaid {
  const TwitchRaid({
    required this.id,
    required this.sourceChannelId,
    required this.targetChannelId,
    required this.targetLogin,
    required this.targetDisplayName,
    required this.viewerCount,
    required this.type,
    this.targetProfileImageUrl,
    this.remainingDurationSeconds = 0,
    this.transitionJitterSeconds = 0,
  });

  final String id;
  final String sourceChannelId;
  final String targetChannelId;
  final String targetLogin;
  final String targetDisplayName;
  final String? targetProfileImageUrl;
  final int viewerCount;
  final String type;
  final int remainingDurationSeconds;
  final int transitionJitterSeconds;

  bool get isGoing => type == "raid_go_v2";
  bool get isEnded => isGoing || type == "raid_cancel_v2";

  static TwitchRaid? fromPubSub(Map<String, Object?> event) {
    final type = event["type"];
    final raid = event["raid"];
    if (raid is! Map<String, Object?> ||
        type is! String ||
        !const ["raid_update_v2", "raid_cancel_v2", "raid_go_v2"].contains(type)) {
      return null;
    }
    final id = _string(raid["id"]) ?? "";
    final sourceId = _string(raid["source_id"]) ?? "";
    final targetId = _string(raid["target_id"]) ?? "";
    final targetLogin = _string(raid["target_login"]) ?? "";
    if (id.isEmpty || sourceId.isEmpty) {
      return null;
    }
    if (type == "raid_update_v2" &&
        (targetId.isEmpty || !RegExp(r"^[a-zA-Z0-9_]{1,25}$").hasMatch(targetLogin))) {
      return null;
    }
    return TwitchRaid(
      id: id,
      sourceChannelId: sourceId,
      targetChannelId: targetId,
      targetLogin: targetLogin,
      targetDisplayName: _string(raid["target_display_name"]) ?? targetLogin,
      targetProfileImageUrl: _string(raid["target_profile_image"]),
      viewerCount: _count(raid["viewer_count"]),
      type: type,
      remainingDurationSeconds: _count(raid["remaining_duration_seconds"]),
      transitionJitterSeconds: _count(raid["transition_jitter_seconds"]),
    );
  }

  static String? _string(Object? value) => value is String ? value : null;

  static int _count(Object? value) =>
      value is num && value.isFinite && value >= 0 ? value.toInt() : 0;
}
