import "package:flutter/material.dart";

class StreamChannel {
  const StreamChannel({
    required this.name,
    required this.initials,
    required this.title,
    required this.category,
    required this.viewers,
    required this.avatarColors,
    required this.thumbnailColors,
    this.avatarImageUrl,
    this.thumbnailUrl,
  });

  final String name;
  final String initials;
  final String title;
  final String category;
  final String viewers;
  final List<Color> avatarColors;
  final List<Color> thumbnailColors;
  final String? avatarImageUrl;
  final String? thumbnailUrl;
}

class OfflineChannel {
  const OfflineChannel({
    required this.name,
    required this.initials,
    required this.lastLive,
    required this.category,
    required this.avatarColors,
    this.avatarImageUrl,
  });

  final String name;
  final String initials;
  final String lastLive;
  final String category;
  final List<Color> avatarColors;
  final String? avatarImageUrl;
}

class BrowseCategory {
  const BrowseCategory({
    required this.id,
    required this.name,
    required this.viewerCount,
    required this.viewers,
    required this.imageUrl,
    required this.colors,
  });

  final String id;
  final String name;
  final int viewerCount;
  final String viewers;
  final String? imageUrl;
  final List<Color> colors;
}
