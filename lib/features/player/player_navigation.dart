import "dart:async";

import "package:flutter/material.dart";

final _playerRoutes = Expando<_PlayerRoutes>();

Future<void> openStreamPlayer(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final routes = _playerRoutes[navigator] ??= _PlayerRoutes();
  final source = ModalRoute.of(context);
  final destination =
      source != null &&
          source.navigator == navigator &&
          source.isCurrent &&
          !source.isFirst &&
          source != routes.player
      ? source
      : null;
  final anchor = routes.destination?.isActive == true ? routes.destination : routes.player;

  // Keep the current destination's state while removing the older root chain.
  // Tab-local routes belong to a different navigator and remain untouched.
  if (destination != null && anchor != null && anchor != destination && !anchor.isFirst) {
    while (anchor.isActive) {
      navigator.removeRouteBelow(destination);
    }
  }

  final player = MaterialPageRoute<void>(builder: builder);
  routes.player = player;
  unawaited(
    player.popped.then((_) {
      if (routes.player == player) {
        routes.player = null;
      }
    }),
  );
  if (routes.destination != destination) {
    routes.destination = destination;
    if (destination != null) {
      unawaited(
        destination.popped.then((_) {
          if (routes.destination == destination) {
            routes.destination = null;
          }
        }),
      );
    }
  }
  return destination == null
      ? navigator.pushAndRemoveUntil<void>(player, (route) => route.isFirst)
      : navigator.push<void>(player);
}

class _PlayerRoutes {
  Route<void>? player;
  ModalRoute<dynamic>? destination;
}
