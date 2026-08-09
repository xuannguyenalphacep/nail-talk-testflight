import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/social_hub_controller.dart';
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
    final screens = <Widget>[
      DashboardScreen(onNavigate: _goToTab),
      const MoviesScreen(),
      const MarketplaceScreen(),
      const WorkStayScreen(),
      const ChatHomeScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF3F6FB),
          boxShadow: [
            BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 26,
              offset: Offset(0, -10),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: NavigationBar(
                selectedIndex: _index,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                onDestinationSelected: _goToTab,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'Feed',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.smart_display_outlined),
                    selectedIcon: Icon(Icons.smart_display_rounded),
                    label: 'Movies',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.storefront_outlined),
                    selectedIcon: Icon(Icons.storefront_rounded),
                    label: 'Market',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.apartment_outlined),
                    selectedIcon: Icon(Icons.apartment_rounded),
                    label: 'Work & Stay',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.chat_bubble_outline_rounded),
                    selectedIcon: Icon(Icons.chat_bubble_rounded),
                    label: 'Chat',
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
