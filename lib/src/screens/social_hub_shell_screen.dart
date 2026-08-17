import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/chat_controller.dart';
import '../controllers/social_hub_controller.dart';
import '../core/localization/app_localizer.dart';
import '../widgets/language_switch_button.dart';
import '../widgets/metro_ui.dart';
import 'chat_home_screen.dart';
import 'dashboard_screen.dart';
import 'marketplace_screen.dart';
import 'movies_screen.dart';
import 'work_stay_screen.dart';

class SocialHubShellScreen extends StatefulWidget {
  const SocialHubShellScreen({super.key});

  @override
  State<SocialHubShellScreen> createState() => _SocialHubShellScreenState();
}

class _SocialHubShellScreenState extends State<SocialHubShellScreen> {
  int _index = 0;

  void _goToTab(int value) {
    setState(() => _index = value.clamp(0, 4));
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
    final topInset = MediaQuery.paddingOf(context).top;
    final activeRoom = context.watch<ChatController>().activeRoom;
    final showLanguageButton = _index != 4 || activeRoom == null;
    final screens = <Widget>[
      DashboardScreen(onNavigate: _goToTab),
      const MoviesScreen(),
      const MarketplaceScreen(),
      const WorkStayScreen(),
      const ChatHomeScreen(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _index, children: screens),
          if (showLanguageButton)
            Positioned(
              top: topInset + 12,
              right: _index == 0 ? 124 : 74,
              child: const LanguageSwitchButton(compact: true),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: kMetroSurface,
          border: Border(top: BorderSide(color: kMetroLine)),
          boxShadow: [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 10,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
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
                  label: 'Movies',
                  selected: _index == 1,
                  onTap: () => _goToTab(1),
                ),
                _ShellNavItem(
                  icon: Icons.storefront_outlined,
                  activeIcon: Icons.storefront_rounded,
                  label: 'Market',
                  selected: _index == 2,
                  onTap: () => _goToTab(2),
                ),
                _ShellNavItem(
                  icon: Icons.apartment_outlined,
                  activeIcon: Icons.apartment_rounded,
                  label: 'Work',
                  selected: _index == 3,
                  onTap: () => _goToTab(3),
                ),
                _ShellNavItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  activeIcon: Icons.chat_bubble_rounded,
                  label: 'Chat tab',
                  selected: _index == 4,
                  onTap: () => _goToTab(4),
                ),
              ],
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
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(kMetroRadius),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? kMetroCoralSoft : kMetroSurface,
              borderRadius: BorderRadius.circular(kMetroRadius),
              border: Border.all(color: selected ? kMetroCoral : kMetroLine),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? activeIcon : icon,
                  color: selected ? kMetroPrimary : kMetroMuted,
                  size: 22,
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: selected ? kMetroPrimary : kMetroMuted,
                    fontWeight: FontWeight.w800,
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
