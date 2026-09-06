import "dart:async";

import "package:flutter/material.dart";

final _playerRoutes = Expando<_PlayerRoutes>();
final _destinationRoutes = Expando<Map<ModalRoute<dynamic>, String>>();

void registerPlayerDestination(BuildContext context, String identity) {
  final route = ModalRoute.of(context);
  final navigator = route?.navigator;
  if (route == null || navigator == null) {
    return;
  }

  final destinations = _destinationRoutes[navigator] ??= {};
  final registered = destinations.containsKey(route);
  destinations[route] = identity;
  if (!registered) {
    unawaited(route.popped.then((_) => destinations.remove(route)));
  }
}

Future<void> openStreamPlayer(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final routes = _playerRoutes[navigator] ??= _PlayerRoutes();
  final source = ModalRoute.of(context);
  if (source?.navigator != null && source!.navigator != navigator) {
    routes.originNavigator = source.navigator;
  }
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
  if (destination != null && anchor != null && anchor != destination && !anchor.isFirst) {
    while (anchor.isActive) {
      navigator.removeRouteBelow(destination);
    }
  }

  // The retained root page replaces matching pages only in the initiating tab.
  final identity = _destinationRoutes[navigator]?[destination];
  final originNavigator = routes.originNavigator;
  if (identity != null && originNavigator != null && originNavigator.mounted) {
    final originals = _destinationRoutes[originNavigator]?.entries.toList() ?? [];
    for (final original in originals) {
      if (original.value == identity && original.key.isActive && !original.key.isFirst) {
        originNavigator.removeRoute(original.key);
      }
    }
  }

  final player = MaterialPageRoute<void>(builder: builder);
  routes.player = player;
  unawaited(
    player.popped.then((_) {
      if (routes.player == player) {
        routes.player = null;
        if (routes.destination?.isActive != true) {
          routes.originNavigator = null;
        }
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
            if (routes.player?.isActive != true) {
              routes.originNavigator = null;
            }
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
  NavigatorState? originNavigator;
}
