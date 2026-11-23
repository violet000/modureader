import 'dart:ui';

import 'package:modu_reader/config/shared_preference_provider.dart';
import 'package:modu_reader/l10n/app_language.dart';
import 'package:modu_reader/l10n/generated/L10n.dart';
import 'package:modu_reader/l10n/modu_strings.dart';
import 'package:modu_reader/page/home_page/ai_page.dart';
import 'package:modu_reader/utils/app_motion.dart';
import 'package:modu_reader/utils/env_var.dart';
import 'package:modu_reader/widgets/common/aurora_chrome.dart';
import 'package:modu_reader/widgets/common/container/filled_container.dart';
import 'package:modu_reader/widgets/home_navigation_metrics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart';
import 'package:icons_plus/icons_plus.dart';

/// Builds the page for a home navigation destination.
///
/// The shell owns the destinations, the selected tab and the responsive
/// layout; the home page only decides which widget backs each identifier.
typedef HomeNavigationPageBuilder = Widget Function(
  String identifier,
  ScrollController? controller,
);

/// One home navigation destination.
///
/// [identifier] is stable across rebuilds, so hiding or showing a destination
/// from the settings switches keeps the selected tab deterministic.
@immutable
class HomeNavigationDestination {
  const HomeNavigationDestination(this.identifier, this.icon, this.label);

  final String identifier;
  final IconData icon;
  final String label;

  static const String bookshelf = 'bookshelf';
  static const String remoteLibrary = 'remoteLibrary';
  static const String statistics = 'statistics';
  static const String ai = 'ai';
  static const String notes = 'notes';
  static const String todo = 'todo';
  static const String settings = 'settings';
}

/// Responsive home navigation: a side rail on wide windows and a floating bar
/// on narrow ones.
///
/// The home route is `const`, so it is never rebuilt when [Prefs] notifies.
/// This shell listens to that notifier itself; otherwise turning a destination
/// off (or on) in Settings would keep showing the stale rail/bar until an
/// unrelated rebuild, which is the "separate tab does not refresh" bug.
class HomeNavigationShell extends StatefulWidget {
  const HomeNavigationShell({super.key, required this.pageBuilder});

  final HomeNavigationPageBuilder pageBuilder;

  @override
  State<HomeNavigationShell> createState() => _HomeNavigationShellState();
}

class _HomeNavigationShellState extends State<HomeNavigationShell> {
  String _currentTab = HomeNavigationDestination.bookshelf;
  EdgeInsets? _homeViewPadding;
  Size? _homeViewport;
  bool _holdingSystemInsets = false;

  MediaQueryData _stableHomeInsets(MediaQueryData media, bool isCurrent) {
    final previous = _homeViewport;
    final resized = previous == null ||
        previous.width != media.size.width ||
        (previous.width > previous.height) !=
            (media.size.width > media.size.height);
    final saved = _homeViewPadding;
    final actual = media.viewPadding;
    final barsRestored = saved == null ||
        ((saved.top == 0 || actual.top > 0) &&
            (saved.bottom == 0 || actual.bottom > 0) &&
            (saved.left == 0 || actual.left > 0) &&
            (saved.right == 0 || actual.right > 0));
    // The covered shelf is also the return Hero's destination. Keep its safe
    // area until native bars return, rather than relaying out after the flight.
    if (resized || (isCurrent && (!_holdingSystemInsets || barsRestored))) {
      _homeViewPadding = actual;
      _holdingSystemInsets = false;
    } else if (!isCurrent) {
      _holdingSystemInsets = true;
    }
    _homeViewport = media.size;
    final insets = _holdingSystemInsets ? _homeViewPadding! : actual;
    return media.copyWith(
      viewPadding: insets,
      padding: EdgeInsets.fromLTRB(
        (insets.left - media.viewInsets.left).clamp(0.0, double.infinity),
        (insets.top - media.viewInsets.top).clamp(0.0, double.infinity),
        (insets.right - media.viewInsets.right).clamp(0.0, double.infinity),
        (insets.bottom - media.viewInsets.bottom).clamp(0.0, double.infinity),
      ),
    );
  }

  List<HomeNavigationDestination> _destinations(BuildContext context) {
    final prefs = Prefs();
    final l10n = L10n.of(context);
    final localeKey = appLocaleKey(Localizations.localeOf(context));
    return <HomeNavigationDestination>[
      HomeNavigationDestination(
        HomeNavigationDestination.bookshelf,
        EvaIcons.book_open,
        l10n.navBarBookshelf,
      ),
      if (prefs.bottomNavigatorShowRemote)
        HomeNavigationDestination(
          HomeNavigationDestination.remoteLibrary,
          Icons.cloud_download_outlined,
          switch (localeKey) {
            'zh-CN' => '远程',
            'zh-TW' || 'zh-LZH' => '遠程',
            _ => ModuStrings.text(context, '远程书库', 'Remote library'),
          },
        ),
      if (prefs.bottomNavigatorShowStatistics)
        HomeNavigationDestination(
          HomeNavigationDestination.statistics,
          Icons.history,
          switch (localeKey) {
            'zh-CN' => '历史',
            'zh-TW' || 'zh-LZH' => '歷史',
            _ => l10n.navBarStatistics,
          },
        ),
      if (prefs.bottomNavigatorShowAI && EnvVar.enableAIFeature)
        HomeNavigationDestination(
          HomeNavigationDestination.ai,
          Icons.auto_awesome,
          l10n.navBarAI,
        ),
      if (prefs.bottomNavigatorShowNote)
        HomeNavigationDestination(
          HomeNavigationDestination.notes,
          Icons.note,
          l10n.navBarNotes,
        ),
      HomeNavigationDestination(
        HomeNavigationDestination.todo,
        Icons.checklist_rounded,
        switch (localeKey) {
          'zh-CN' => '待办',
          'zh-TW' || 'zh-LZH' => '待辦',
          _ => ModuStrings.text(context, '待办', 'Todo'),
        },
      ),
      HomeNavigationDestination(
        HomeNavigationDestination.settings,
        EvaIcons.settings_2,
        l10n.navBarSettings,
      ),
    ];
  }

  void _selectDestination(
      HomeNavigationDestination destination, bool fromRail) {
    if (destination.identifier == HomeNavigationDestination.ai && !fromRail) {
      showCupertinoSheet(
        context: context,
        builder: (BuildContext context) => const AiPage(),
      );
      return;
    }
    setState(() {
      _currentTab = destination.identifier;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: _stableHomeInsets(MediaQuery.of(context),
          ModalRoute.isCurrentOf(context) ?? true),
      child: _buildNavigation(),
    );
  }

  Widget _buildNavigation() {
    return AnimatedBuilder(
      animation: Prefs(),
      builder: (context, _) {
        final destinations = _destinations(context);
        var selectedIndex = destinations
            .indexWhere((destination) => destination.identifier == _currentTab);
        if (selectedIndex == -1) {
          // The selected destination was just hidden by a settings switch (or
          // an imported configuration). Fall back to the stable first entry.
          selectedIndex = 0;
          _currentTab = destinations.first.identifier;
        }

        Widget pageFor(int index, ScrollController? controller) =>
            widget.pageBuilder(destinations[index].identifier, controller);

        return LayoutBuilder(
          builder: (context, constraints) {
            if (Prefs().appLayoutMode.usesWideLayout(constraints.maxWidth)) {
              final eink = Prefs().eInkMode;
              final scheme = Theme.of(context).colorScheme;
              return Scaffold(
                extendBody: true,
                body: Row(
                  children: [
                    SafeArea(
                      bottom: false,
                      child: _RailFrame(
                        child: NavigationRail(
                          groupAlignment: -1,
                          extended: false,
                          selectedIndex: selectedIndex,
                          onDestinationSelected: (int index) =>
                              _selectDestination(destinations[index], true),
                          leading: const Padding(
                            padding: EdgeInsets.only(top: 4, bottom: 8),
                            child: GlowMark(icon: Icons.auto_stories_rounded, size: 32),
                          ),
                          useIndicator: !eink,
                          indicatorColor: eink
                              ? scheme.primaryContainer
                              : Colors.white.withValues(alpha: 0.10),
                          indicatorShape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          selectedIconTheme: IconThemeData(
                            color: eink ? scheme.primary : const Color(0xFF5EEAD4),
                            size: 22,
                          ),
                          unselectedIconTheme: IconThemeData(
                            color: eink
                                ? scheme.onSurfaceVariant
                                : const Color(0xFF8E99AE),
                            size: 22,
                          ),
                          selectedLabelTextStyle: TextStyle(
                            color: eink ? scheme.primary : const Color(0xFFF4F7FB),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                          unselectedLabelTextStyle: TextStyle(
                            color: eink
                                ? scheme.onSurfaceVariant
                                : const Color(0xFF8E99AE),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            height: 1.1,
                          ),
                          destinations: [
                            for (final destination in destinations)
                              NavigationRailDestination(
                                icon: Icon(destination.icon),
                                label: Text(destination.label),
                              ),
                          ],
                          labelType: NavigationRailLabelType.all,
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    ),
                    Expanded(
                      child: AuroraCanvas(
                        child: pageFor(selectedIndex, null),
                      ),
                    ),
                  ],
                ),
              );
            }

            final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
            final barRoom = MediaQuery.sizeOf(context).width - 24;
            final barWidth = barRoom > 420 ? 420.0 : barRoom;
            // A compact bar never keeps a sheet-only AI destination selected.
            final displayIndex = destinations[selectedIndex].identifier ==
                    HomeNavigationDestination.ai
                ? 0
                : selectedIndex;
            return Scaffold(
              extendBody: true,
              body: BottomBar(
                duration: AppMotion.duration(const Duration(milliseconds: 120)),
                width: barWidth,
                offset: HomeNavigationMetrics.barOffset,
                body: (_, controller) => HomeNavigationBody(
                  hasBottomBar: !keyboardOpen,
                  // Keep the page above the bar so lists and buttons stay tappable.
                  scrollBehindBar: false,
                  child: AuroraCanvas(
                    child: pageFor(displayIndex, controller),
                  ),
                ),
                showIcon: !keyboardOpen,
                hideOnScroll: Prefs().autoHideBottomBar,
                scrollOpposite: false,
                curve: Curves.easeIn,
                barColor: Colors.transparent,
                iconDecoration: BoxDecoration(
                  color: Prefs().autoHideBottomBar
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(500),
                ),
                child: Visibility(
                  visible: !keyboardOpen,
                  maintainState: true,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: Prefs().eInkMode
                          ? const []
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.14),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: Prefs().eInkMode ? 0 : 18,
                          sigmaY: Prefs().eInkMode ? 0 : 18,
                        ),
                        child: Container(
                        height: HomeNavigationMetrics.barHeightFor(context),
                        decoration: BoxDecoration(
                          color: Prefs().eInkMode
                              ? Theme.of(context).colorScheme.surface
                              : const Color(0xFF12161C).withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Prefs().eInkMode
                                ? Theme.of(context).colorScheme.outline
                                : const Color(0xFF5EEAD4).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            canvasColor: Colors.transparent,
                            bottomNavigationBarTheme:
                                const BottomNavigationBarThemeData(
                              backgroundColor: Colors.transparent,
                              elevation: 0,
                            ),
                          ),
                          child: BottomNavigationBar(
                          selectedFontSize: 11,
                          unselectedFontSize: 11,
                          enableFeedback: false,
                          type: BottomNavigationBarType.fixed,
                          landscapeLayout:
                              BottomNavigationBarLandscapeLayout.linear,
                          currentIndex: displayIndex,
                          onTap: (int index) =>
                              _selectDestination(destinations[index], false),
                          selectedItemColor: Prefs().eInkMode
                              ? Theme.of(context).colorScheme.primary
                              : const Color(0xFF5EEAD4),
                          unselectedItemColor: Prefs().eInkMode
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : const Color(0xFF9AA6B8),
                          items: [
                            for (final destination in destinations)
                              BottomNavigationBarItem(
                                icon: Icon(destination.icon, size: 22),
                                label: destination.label,
                              ),
                          ],
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                        ),
                        ),
                      ),
                    ),
                  ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _RailFrame extends StatelessWidget {
  const _RailFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Prefs().eInkMode) {
      return FilledContainer(
        margin: const EdgeInsets.all(16),
        color: ElevationOverlay.applySurfaceTint(
          Theme.of(context).colorScheme.surface,
          Theme.of(context).colorScheme.primary,
          3,
        ),
        radius: 20,
        child: SafeArea(child: child),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF14171E),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: SafeArea(child: child),
    );
  }
}
