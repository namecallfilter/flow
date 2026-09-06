import "package:flutter/material.dart";

Future<void> openStreamPlayer(
  BuildContext context, {
  required WidgetBuilder builder,
}) => Navigator.of(context, rootNavigator: true).pushAndRemoveUntil<void>(
  MaterialPageRoute<void>(builder: builder),
  (route) => route.isFirst,
);
