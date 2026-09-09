class TwitchChatEmote {
  const TwitchChatEmote({required this.id, required this.start, required this.end});

  final String id;
  final int start;
  final int end;

  String get imageUrl => "https://static-cdn.jtvnw.net/emoticons/v2/$id/default/dark/2.0";
}

enum TwitchChatModeration { deleted, timeout, ban, cleared }

class TwitchChatGif {
  const TwitchChatGif({
    required this.id,
    required this.url,
    required this.start,
    required this.end,
  });

  final String id;
  final String url;
  final int start;
  final int end;
}

class TwitchPinnedChat {
  const TwitchPinnedChat({
    required this.id,
    required this.message,
    this.startsAt,
    this.endsAt,
    this.pinnedBy,
  });

  final String id;
  final TwitchChatMessage message;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final ({String id, String login, String displayName})? pinnedBy;
}

class TwitchChatMessage {
  const TwitchChatMessage({
    required this.id,
    required this.login,
    required this.displayName,
    required this.text,
    this.color,
    this.emotes = const [],
    this.gifs = const [],
    this.badges = const [],
    this.isAction = false,
    this.isOwn = false,
    this.isHistorical = false,
    this.offsetSeconds,
    this.timestamp,
    this.userId,
    this.isDeleted = false,
    this.isFirstMessage = false,
    this.isHighlighted = false,
    this.isPrimeSubscription = false,
    this.isPrivate = false,
    this.noticeType,
    this.noticeText,
    this.parentMessageId,
    this.parentUserId,
    this.parentLogin,
    this.parentDisplayName,
    this.parentText,
    this.parentEmotes = const [],
    this.parentGifs = const [],
    this.threadRootId,
    this.threadRootLogin,
    this.moderation,
    this.timeoutSeconds,
    this.moderatedAt,
  });

  final String id;
  final String login;
  final String displayName;
  final String text;
  final String? color;
  final List<TwitchChatEmote> emotes;
  final List<TwitchChatGif> gifs;
  final List<String> badges;
  final bool isAction;
  final bool isOwn;
  final bool isHistorical;
  final double? offsetSeconds;
  final DateTime? timestamp;
  final String? userId;
  final bool isDeleted;
  final bool isFirstMessage;
  final bool isHighlighted;
  final bool isPrimeSubscription;
  final bool isPrivate;
  final String? noticeType;
  final String? noticeText;
  final String? parentMessageId;
  final String? parentUserId;
  final String? parentLogin;
  final String? parentDisplayName;
  final String? parentText;
  final List<TwitchChatEmote> parentEmotes;
  final List<TwitchChatGif> parentGifs;
  final String? threadRootId;
  final String? threadRootLogin;
  final TwitchChatModeration? moderation;
  final int? timeoutSeconds;
  final DateTime? moderatedAt;

  TwitchChatMessage copyWith({
    bool? isOwn,
    bool? isHistorical,
    String? noticeText,
    bool? isDeleted,
    TwitchChatModeration? moderation,
    int? timeoutSeconds,
    DateTime? moderatedAt,
  }) => TwitchChatMessage(
    id: id,
    login: login,
    displayName: displayName,
    text: text,
    color: color,
    emotes: emotes,
    gifs: gifs,
    badges: badges,
    isAction: isAction,
    isOwn: isOwn ?? this.isOwn,
    isHistorical: isHistorical ?? this.isHistorical,
    offsetSeconds: offsetSeconds,
    timestamp: timestamp,
    userId: userId,
    isDeleted: isDeleted ?? this.isDeleted,
    isFirstMessage: isFirstMessage,
    isHighlighted: isHighlighted,
    isPrimeSubscription: isPrimeSubscription,
    isPrivate: isPrivate,
    noticeType: noticeType,
    noticeText: noticeText ?? this.noticeText,
    parentMessageId: parentMessageId,
    parentUserId: parentUserId,
    parentLogin: parentLogin,
    parentDisplayName: parentDisplayName,
    parentText: parentText,
    parentEmotes: parentEmotes,
    parentGifs: parentGifs,
    threadRootId: threadRootId,
    threadRootLogin: threadRootLogin,
    moderation: moderation ?? this.moderation,
    timeoutSeconds: moderation != null ? timeoutSeconds : this.timeoutSeconds,
    moderatedAt: moderatedAt ?? this.moderatedAt,
  );
}
