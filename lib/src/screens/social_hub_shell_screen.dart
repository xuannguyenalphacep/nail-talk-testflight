import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/social_hub_controller.dart';
import '../core/localization/app_localizer.dart';
import 'chat_home_screen.dart';
import 'dashboard_screen.dart';
import 'marketplace_screen.dart';
import 'more_menu_screen.dart';
import 'movies_screen.dart';
import 'work_stay_screen.dart';

class SocialHubShellScreen extends StatefulWidget {
  const SocialHubShellScreen({super.key});

  @override
  State<SocialHubShellScreen> createState() => _SocialHubShellScreenState();
}

class _SocialHubShellScreenState extends State<SocialHubShellScreen> {
  int _index = 0;

  static const Color _navText = Color(0xFF2C3C74);
  static const Color _navMuted = Color(0xFF7A84A8);
  static const Color _navBorder = Color(0xFFF0E8E4);
  static const Color _navShadow = Color(0x140F172A);

  void _goToTab(int value) {
    setState(() => _index = value.clamp(0, 4));
  }

  Future<void> _openJobs([String initialMode = 'looking_for_job']) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkStayScreen.jobs(initialJobMode: initialMode),
      ),
    );
  }

  Future<void> _openHousing([String initialMode = 'rent_out']) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            WorkStayScreen.housing(initialPropertyMode: initialMode),
      ),
    );
  }

  void _openSavedLanding() {
    final bookmarks = context.read<SocialHubController>().bookmarks;
    if (bookmarks.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(context.tr('No saved items yet')),
        ),
      );
      _goToTab(2);
      return;
    }

    final type = bookmarks.first.savableType.toLowerCase();
    if (type.contains('movie')) {
      _goToTab(1);
      return;
    }
    if (type.contains('job')) {
      _openJobs();
      return;
    }
    if (type.contains('property') ||
        type.contains('housing') ||
        type.contains('room')) {
      _openHousing();
      return;
    }
    _goToTab(2);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SocialHubController>().initializeIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      DashboardScreen(
        onNavigate: _goToTab,
        onOpenJobs: _openJobs,
        onOpenHousing: _openHousing,
        onOpenSaved: _openSavedLanding,
      ),
      const MoviesScreen(),
      const MarketplaceScreen(),
      const ChatHomeScreen(),
      MoreMenuScreen(
        onNavigate: _goToTab,
        onOpenJobs: _openJobs,
        onOpenHousing: _openHousing,
        onOpenSaved: _openSavedLanding,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: Container(
        color: Colors.transparent,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.97),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: _navBorder),
                boxShadow: const [
                  BoxShadow(
                    color: _navShadow,
                    blurRadius: 24,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 7, 4, 8),
                child: Row(
                  children: [
                    _ShellNavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: 'Feed',
                      selected: _index == 0,
                      onTap: () => _goToTab(0),
                    ),
                    _ShellNavItem(
                      icon: Icons.smart_display_outlined,
                      activeIcon: Icons.smart_display_rounded,
                      label: 'Movie picks',
                      selected: _index == 1,
                      onTap: () => _goToTab(1),
                    ),
                    _ShellNavItem(
                      icon: Icons.storefront_outlined,
                      activeIcon: Icons.storefront_rounded,
                      label: 'Buy & Sell',
                      selected: _index == 2,
                      onTap: () => _goToTab(2),
                    ),
                    _ShellNavItem(
                      icon: Icons.chat_bubble_outline_rounded,
                      activeIcon: Icons.chat_bubble_rounded,
                      label: 'Chat tab',
                      selected: _index == 3,
                      onTap: () => _goToTab(3),
                    ),
                    _ShellNavItem(
                      icon: Icons.more_horiz_rounded,
                      activeIcon: Icons.more_horiz_rounded,
                      label: 'More',
                      selected: _index == 4,
                      onTap: () => _goToTab(4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellNavItem extends StatelessWidget {
  const _ShellNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: selected
                    ? _SocialHubShellScreenState._navBorder
                    : Colors.transparent,
              ),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: _SocialHubShellScreenState._navShadow,
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? activeIcon : icon,
                  color: selected
                      ? _SocialHubShellScreenState._navText
                      : _SocialHubShellScreenState._navMuted,
                  size: 21,
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 12,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      context.tr(label),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 9.5,
                        height: 1,
                        color: selected
                            ? _SocialHubShellScreenState._navText
                            : _SocialHubShellScreenState._navMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
