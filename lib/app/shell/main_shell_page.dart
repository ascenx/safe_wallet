import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/browser/presentation/browser_home_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../i18n/generated/translations.g.dart';
import '../../shared/design/app_brand_colors.dart';
import '../../shared/design/app_colors.dart';
import '../../shared/design/app_radius.dart';
import '../../shared/design/app_text_styles.dart';
import 'main_shell_tab.dart';

final class MainShellPage extends ConsumerStatefulWidget {
  const MainShellPage({super.key});

  @override
  ConsumerState<MainShellPage> createState() => _MainShellPageState();
}

final class _MainShellPageState extends ConsumerState<MainShellPage> {
  final Set<MainShellTab> _visitedTabs = {MainShellTab.home};
  bool _isNavigationVisible = true;

  @override
  Widget build(BuildContext context) {
    final strings = context.t;
    final currentTab = ref.watch(mainShellTabProvider);
    _visitedTabs.add(currentTab);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: NotificationListener<UserScrollNotification>(
        onNotification: _handleUserScroll,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const _LazyTabView(tab: MainShellTab.home, child: HomePage()),
            const _LazyTabView(
              tab: MainShellTab.browser,
              child: BrowserHomePage(),
            ),
            const _LazyTabView(
              tab: MainShellTab.settings,
              child: SettingsPage(),
            ),
            _FloatingMainNavigation(
              currentTab: currentTab,
              isVisible: _isNavigationVisible,
              onSelected: (tab) {
                _setNavigationVisible(true);
                ref.read(mainShellTabProvider.notifier).select(tab);
              },
              destinations: [
                _MainNavigationDestination(
                  tab: MainShellTab.home,
                  key: const Key('mainShellHomeTab'),
                  icon: AppIcons.home,
                  selectedIcon: AppIcons.homeSelected,
                  label: strings.tabs.home,
                ),
                _MainNavigationDestination(
                  tab: MainShellTab.browser,
                  key: const Key('mainShellBrowserTab'),
                  icon: AppIcons.globe,
                  selectedIcon: AppIcons.globeSelected,
                  label: strings.tabs.browser,
                ),
                _MainNavigationDestination(
                  tab: MainShellTab.settings,
                  key: const Key('mainShellSettingsTab'),
                  icon: AppIcons.settings,
                  selectedIcon: AppIcons.settingsSelected,
                  label: strings.tabs.settings,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _handleUserScroll(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }

    switch (notification.direction) {
      case ScrollDirection.reverse:
        _setNavigationVisible(false);
      case ScrollDirection.forward:
        _setNavigationVisible(true);
      case ScrollDirection.idle:
        break;
    }
    return false;
  }

  void _setNavigationVisible(bool isVisible) {
    if (_isNavigationVisible == isVisible) {
      return;
    }
    setState(() {
      _isNavigationVisible = isVisible;
    });
  }
}

final class _FloatingMainNavigation extends StatelessWidget {
  const _FloatingMainNavigation({
    required this.currentTab,
    required this.isVisible,
    required this.onSelected,
    required this.destinations,
  });

  static const _height = 64.0;
  static const _horizontalMargin = 24.0;
  static const _bottomGap = 14.0;
  static const _hiddenShadowBuffer = 48.0;

  final MainShellTab currentTab;
  final bool isVisible;
  final ValueChanged<MainShellTab> onSelected;
  final List<_MainNavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom - 16;
    final colorScheme = Theme.of(context).colorScheme;
    final hiddenOffset =
        _height + _bottomGap + bottomInset + _hiddenShadowBuffer;

    return Positioned(
      left: _horizontalMargin,
      right: _horizontalMargin,
      bottom: _bottomGap + bottomInset,
      child: IgnorePointer(
        ignoring: !isVisible,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: isVisible ? 0 : hiddenOffset),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (context, offset, child) {
            return Transform.translate(offset: Offset(0, offset), child: child);
          },
          child: DecoratedBox(
            key: const Key('mainShellFloatingNavigation'),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.96),
              borderRadius: AppRadius.pillBorder,
              border: Border.all(color: colorScheme.outline),
              boxShadow: [
                BoxShadow(
                  color: context.brandColors.primaryDark.withValues(
                    alpha: 0.08,
                  ),
                  blurRadius: 34,
                  offset: const Offset(0, 16),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SizedBox(
              height: _height,
              child: Row(
                children: [
                  for (final destination in destinations)
                    Expanded(
                      child: _FloatingNavigationItem(
                        destination: destination,
                        isSelected: destination.tab == currentTab,
                        onTap: () => onSelected(destination.tab),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _MainNavigationDestination {
  const _MainNavigationDestination({
    required this.tab,
    required this.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final MainShellTab tab;
  final Key key;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

final class _FloatingNavigationItem extends StatelessWidget {
  const _FloatingNavigationItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final _MainNavigationDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = context.appTextStyles.tabLabel.copyWith(
      color: isSelected ? colorScheme.primary : context.appColors.textMuted,
      fontSize: 14,
      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
    );

    return Semantics(
      button: true,
      selected: isSelected,
      label: destination.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: destination.key,
          onTap: onTap,
          borderRadius: AppRadius.pillBorder,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _NavigationIcon(
                icon: isSelected ? destination.selectedIcon : destination.icon,
                isSelected: isSelected,
              ),
              const SizedBox(height: 4),
              Text(
                destination.label,
                style: labelStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _NavigationIcon extends StatelessWidget {
  const _NavigationIcon({required this.icon, required this.isSelected});

  final IconData icon;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(
      icon,
      size: 24,
      color: isSelected ? Colors.white : context.appColors.textMuted,
    );

    if (!isSelected) {
      return iconWidget;
    }

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        return context.brandColors.primaryGradient.createShader(
          Rect.fromLTWH(0, 0, bounds.width, bounds.height),
        );
      },
      child: iconWidget,
    );
  }
}

final class _LazyTabView extends ConsumerWidget {
  const _LazyTabView({required this.tab, required this.child});

  final MainShellTab tab;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(mainShellTabProvider);
    final parentState = context.findAncestorStateOfType<_MainShellPageState>();
    final isVisited =
        parentState?._visitedTabs.contains(tab) ?? tab == currentTab;
    if (!isVisited) {
      return const SizedBox.shrink();
    }
    return Offstage(
      offstage: currentTab != tab,
      child: TickerMode(enabled: currentTab == tab, child: child),
    );
  }
}
