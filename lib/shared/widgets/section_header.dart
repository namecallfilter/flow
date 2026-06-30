import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    super.key,
    this.actionLabel,
    this.onAction,
    this.collapsible = false,
    this.expanded = true,
    this.onToggle,
    this.toggleKey,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool collapsible;
  final bool expanded;
  final VoidCallback? onToggle;
  final Key? toggleKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        if (collapsible)
          IconButton(
            key: toggleKey,
            tooltip: expanded ? "Collapse $title" : "Expand $title",
            onPressed: onToggle,
            icon: AnimatedRotation(
              turns: expanded ? 0 : -0.25,
              duration: const Duration(milliseconds: 180),
              child: const Icon(Icons.expand_more),
            ),
            color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
          )
        else if (actionLabel != null)
          TextButton.icon(
            onPressed: onAction,
            iconAlignment: IconAlignment.end,
            label: Text(actionLabel!),
            icon: const Icon(Icons.chevron_right, size: 18),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty("title", title));
    properties.add(StringProperty("actionLabel", actionLabel));
    properties.add(ObjectFlagProperty<VoidCallback?>.has("onAction", onAction));
    properties.add(DiagnosticsProperty<bool>("collapsible", collapsible));
    properties.add(DiagnosticsProperty<bool>("expanded", expanded));
    properties.add(ObjectFlagProperty<VoidCallback?>.has("onToggle", onToggle));
    properties.add(DiagnosticsProperty<Key?>("toggleKey", toggleKey));
  }
}
