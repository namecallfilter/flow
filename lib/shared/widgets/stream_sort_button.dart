import "dart:async";

import "package:flow/app/spacing.dart";
import "package:flow/shared/twitch/stream_sort.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";

class StreamSortButton extends StatelessWidget {
  const StreamSortButton({
    required this.sort,
    required this.onSelected,
    super.key,
    this.options = defaultOptions,
  });

  static const contentVerticalPadding = AppSpacing.md;
  static const defaultOptions = [
    StreamSort.recommendedForYou,
    StreamSort.viewersHighToLow,
    StreamSort.viewersLowToHigh,
  ];

  final StreamSort sort;
  final ValueChanged<StreamSort> onSelected;
  final List<StreamSort> options;

  @override
  Widget build(BuildContext context) => _SortMenu<StreamSort>(
    sort: sort,
    onSelected: onSelected,
    options: options,
    label: (value) => value.label,
    icon: (value) => Transform.flip(
      flipY: value == StreamSort.viewersLowToHigh,
      child: Icon(
        switch (value) {
          StreamSort.recommendedForYou => Icons.auto_awesome,
          StreamSort.viewersHighToLow || StreamSort.viewersLowToHigh => Icons.sort,
          StreamSort.recentlyStarted => Icons.schedule,
        },
        size: 20,
      ),
    ),
    tooltip: "Sort live channels",
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<StreamSort>("sort", sort))
      ..add(IterableProperty<StreamSort>("options", options))
      ..add(ObjectFlagProperty<ValueChanged<StreamSort>>.has("onSelected", onSelected));
  }
}

class CategorySortButton extends StatelessWidget {
  const CategorySortButton({required this.sort, required this.onSelected, super.key});

  final CategorySort sort;
  final ValueChanged<CategorySort> onSelected;

  @override
  Widget build(BuildContext context) => _SortMenu<CategorySort>(
    sort: sort,
    onSelected: onSelected,
    options: CategorySort.values,
    label: (value) => value.label,
    icon: (value) => Icon(
      switch (value) {
        CategorySort.recommendedForYou => Icons.auto_awesome,
        CategorySort.viewersHighToLow => Icons.sort,
      },
      size: 20,
    ),
    tooltip: "Sort categories",
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<CategorySort>("sort", sort))
      ..add(ObjectFlagProperty<ValueChanged<CategorySort>>.has("onSelected", onSelected));
  }
}

class _SortMenu<T> extends StatelessWidget {
  const _SortMenu({
    required this.sort,
    required this.onSelected,
    required this.options,
    required this.label,
    required this.icon,
    required this.tooltip,
  });

  final T sort;
  final ValueChanged<T> onSelected;
  final List<T> options;
  final String Function(T) label;
  final Widget Function(T) icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: PopupMenuButton<T>(
      tooltip: tooltip,
      initialValue: sort,
      onSelected: (value) {
        if (value != sort) {
          unawaited(HapticFeedback.selectionClick());
          onSelected(value);
        }
      },
      itemBuilder: (_) => [
        for (final value in options)
          PopupMenuItem(
            value: value,
            child: Semantics(
              selected: value == sort,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    icon(value),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: Text(label(value))),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: 20,
                      child: value == sort ? const Icon(Icons.check, size: 20) : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: StreamSortButton.contentVerticalPadding),
        child: Row(
          key: const ValueKey("sort_button_content"),
          mainAxisSize: MainAxisSize.min,
          children: [
            icon(sort),
            const SizedBox(width: AppSpacing.sm),
            Flexible(child: Text(label(sort), overflow: TextOverflow.ellipsis)),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<T>("sort", sort))
      ..add(IterableProperty<T>("options", options))
      ..add(ObjectFlagProperty<ValueChanged<T>>.has("onSelected", onSelected))
      ..add(ObjectFlagProperty<String Function(T)>.has("label", label))
      ..add(ObjectFlagProperty<Widget Function(T)>.has("icon", icon))
      ..add(StringProperty("tooltip", tooltip));
  }
}
