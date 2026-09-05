import "dart:async";

import "package:flow/shared/twitch/stream_sort.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";

class StreamSortButton extends StatelessWidget {
  const StreamSortButton({required this.sort, required this.onSelected, super.key});

  final StreamSort sort;
  final ValueChanged<StreamSort> onSelected;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: PopupMenuButton<StreamSort>(
      tooltip: "Sort live channels",
      initialValue: sort,
      onSelected: (value) {
        if (value != sort) {
          unawaited(HapticFeedback.selectionClick());
          onSelected(value);
        }
      },
      itemBuilder: (_) => [
        for (final value in StreamSort.values)
          CheckedPopupMenuItem(value: value, checked: value == sort, child: Text(value.label)),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort, size: 20),
            const SizedBox(width: 8),
            Flexible(child: Text(sort.label, overflow: TextOverflow.ellipsis)),
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
      ..add(EnumProperty<StreamSort>("sort", sort))
      ..add(ObjectFlagProperty<ValueChanged<StreamSort>>.has("onSelected", onSelected));
  }
}
