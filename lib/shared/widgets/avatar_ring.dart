import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

class AvatarRing extends StatelessWidget {
  const AvatarRing({
    required this.initials,
    required this.size,
    required this.avatarColors,
    super.key,
    this.isLive = false,
    this.statusColor,
    this.ringWidth = 3,
    this.imageUrl,
  });

  final String initials;
  final double size;
  final List<Color> avatarColors;
  final bool isLive;
  final Color? statusColor;
  final double ringWidth;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceColor = theme.scaffoldBackgroundColor;
    final ringPadding = isLive ? ringWidth : 0.0;
    final avatar = ClipOval(
      child: SizedBox.expand(
        child: _AvatarContent(
          avatarColors: avatarColors,
          initials: initials,
          imageUrl: imageUrl,
          size: size,
        ),
      ),
    );

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: isLive
                ? Container(
                    padding: EdgeInsets.all(ringPadding),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.tertiary,
                          theme.colorScheme.primary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: avatar,
                  )
                : avatar,
          ),
          if (statusColor != null)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: size * 0.24,
                height: size * 0.24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                  border: Border.all(color: surfaceColor, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty("initials", initials));
    properties.add(DoubleProperty("size", size));
    properties.add(IterableProperty<Color>("avatarColors", avatarColors));
    properties.add(DiagnosticsProperty<bool>("isLive", isLive));
    properties.add(ColorProperty("statusColor", statusColor));
    properties.add(DoubleProperty("ringWidth", ringWidth));
    properties.add(StringProperty("imageUrl", imageUrl));
  }
}

class _AvatarContent extends StatelessWidget {
  const _AvatarContent({
    required this.avatarColors,
    required this.initials,
    required this.imageUrl,
    required this.size,
  });

  final List<Color> avatarColors;
  final String initials;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _InitialsBackground(
          avatarColors: avatarColors,
          initials: initials,
          size: size,
        ),
      );
    }

    return _InitialsBackground(
      avatarColors: avatarColors,
      initials: initials,
      size: size,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IterableProperty<Color>("avatarColors", avatarColors));
    properties.add(StringProperty("initials", initials));
    properties.add(StringProperty("imageUrl", imageUrl));
    properties.add(DoubleProperty("size", size));
  }
}

class _InitialsBackground extends StatelessWidget {
  const _InitialsBackground({
    required this.avatarColors,
    required this.initials,
    required this.size,
  });

  final List<Color> avatarColors;
  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: avatarColors,
      ),
    ),
    child: Center(
      child: _Initials(initials: initials, size: size),
    ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IterableProperty<Color>("avatarColors", avatarColors));
    properties.add(StringProperty("initials", initials));
    properties.add(DoubleProperty("size", size));
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
    initials,
    style: TextStyle(
      color: Colors.white,
      fontSize: size * 0.28,
      fontWeight: FontWeight.w900,
    ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty("initials", initials));
    properties.add(DoubleProperty("size", size));
  }
}
