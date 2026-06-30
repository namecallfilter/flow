import "dart:async";
import "dart:ui";

import "package:flow/app/radius.dart";
import "package:flow/app/routes.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    required this.currentRoute,
    super.key,
    this.onRouteSelected,
  });

  final String currentRoute;
  final ValueChanged<String>? onRouteSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final navSurface = theme.scaffoldBackgroundColor;
    final topAlpha = theme.brightness == Brightness.dark ? 0.30 : 0.42;
    final bottomAlpha = theme.brightness == Brightness.dark ? 0.92 : 0.94;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          key: const ValueKey("app_bottom_nav_bar"),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                navSurface.withValues(alpha: topAlpha),
                navSurface.withValues(alpha: bottomAlpha),
              ],
            ),
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.32),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 60,
              child: Row(
                children: [
                  _BottomNavItem(
                    label: "Following",
                    icon: Icons.favorite_border,
                    activeIcon: Icons.favorite,
                    isActive: currentRoute == FlowRoutes.following,
                    onTap: () => _openRoute(context, FlowRoutes.following),
                  ),
                  _BottomNavItem(
                    label: "Browse",
                    icon: Icons.explore_outlined,
                    activeIcon: Icons.explore,
                    isActive: currentRoute == FlowRoutes.browse,
                    onTap: () => _openRoute(context, FlowRoutes.browse),
                  ),
                  _BottomNavItem(
                    label: "Settings",
                    icon: Icons.settings_outlined,
                    activeIcon: Icons.settings,
                    isActive: currentRoute == FlowRoutes.settings,
                    onTap: () => _openRoute(context, FlowRoutes.settings),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openRoute(BuildContext context, String routeName) {
    if (routeName == currentRoute) {
      return;
    }

    final routeSelected = onRouteSelected;
    if (routeSelected != null) {
      routeSelected(routeName);
      return;
    }

    unawaited(Navigator.of(context).pushReplacementNamed(routeName));
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty("currentRoute", currentRoute));
    properties.add(
      ObjectFlagProperty<ValueChanged<String>?>.has("onRouteSelected", onRouteSelected),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.isActive = false,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54);

    return Expanded(
      child: Semantics(
        selected: isActive,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Column(
            key: ValueKey("bottom_nav_item_$label"),
            children: [
              const SizedBox(height: 12),
              Icon(isActive ? activeIcon : icon, color: color, size: 25),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty("label", label));
    properties.add(DiagnosticsProperty<IconData>("icon", icon));
    properties.add(DiagnosticsProperty<IconData>("activeIcon", activeIcon));
    properties.add(DiagnosticsProperty<bool>("isActive", isActive));
    properties.add(ObjectFlagProperty<VoidCallback?>.has("onTap", onTap));
  }
}
