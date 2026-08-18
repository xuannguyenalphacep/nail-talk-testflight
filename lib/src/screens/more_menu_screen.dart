import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/session_controller.dart';
import '../core/constants/app_constants.dart';
import '../core/localization/app_localizer.dart';
import '../widgets/app_logo.dart';
import 'account_hub_screen.dart';

const Color _menuBgTop = Color(0xFFFFFCFA);
const Color _menuBgBottom = Color(0xFFFFF3ED);
const Color _menuText = Color(0xFF27366E);
const Color _menuMuted = Color(0xFF7C86A9);
const Color _menuBorder = Color(0xFFE7E0E5);
const Color _menuShadow = Color(0x1A1A2341);

class MoreMenuScreen extends StatelessWidget {
  const MoreMenuScreen({
    required this.onNavigate,
    required this.onOpenJobs,
    required this.onOpenHousing,
    required this.onOpenSaved,
    super.key,
  });

  final ValueChanged<int> onNavigate;
  final Future<void> Function(String mode) onOpenJobs;
  final Future<void> Function(String mode) onOpenHousing;
  final VoidCallback onOpenSaved;

  Future<void> _openAccountSection(
    BuildContext context,
    AccountHubSection section,
  ) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AccountHubScreen(initialSection: section),
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(AppLocalizer.current.tr(message)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final rawUsername = session.user?.username.trim() ?? '';
    final userHandle = rawUsername.isEmpty || rawUsername == 'admin'
        ? '@nailstalk.community'
        : '@$rawUsername';

    final exploreEntries = <_MenuEntry>[
      _MenuEntry(
        label: 'Housing',
        icon: Icons.home_rounded,
        tint: const Color(0xFFFF8B77),
        onTap: () => onOpenHousing('rent_out'),
      ),
      _MenuEntry(
        label: 'Need a room',
        icon: Icons.key_rounded,
        tint: const Color(0xFFB07AF7),
        onTap: () => onOpenHousing('looking_room'),
      ),
      _MenuEntry(
        label: 'Jobs',
        icon: Icons.work_rounded,
        tint: const Color(0xFF8AB36F),
        onTap: () => onOpenJobs('looking_for_job'),
      ),
      _MenuEntry(
        label: 'Find a tech',
        icon: Icons.handshake_rounded,
        tint: const Color(0xFFF6BE4E),
        onTap: () => onOpenJobs('hiring'),
      ),
      _MenuEntry(
        label: 'Buy & Sell',
        icon: Icons.shopping_cart_rounded,
        tint: const Color(0xFF6B9DFF),
        onTap: () => onNavigate(2),
      ),
      _MenuEntry(
        label: 'Movie picks',
        icon: Icons.movie_creation_rounded,
        tint: const Color(0xFFF66BA6),
        onTap: () => onNavigate(1),
      ),
      _MenuEntry(
        label: 'Chat rooms',
        icon: Icons.chat_bubble_rounded,
        tint: const Color(0xFF7EDB84),
        onTap: () => onNavigate(3),
      ),
      _MenuEntry(
        label: 'Groups',
        icon: Icons.groups_rounded,
        tint: const Color(0xFFB06AF6),
        onTap: () => onNavigate(3),
      ),
    ];

    final personalEntries = <_MenuEntry>[
      _MenuEntry(
        label: 'Saved',
        icon: Icons.favorite_rounded,
        tint: const Color(0xFFFF728D),
        onTap: onOpenSaved,
      ),
      _MenuEntry(
        label: 'Notifications',
        icon: Icons.notifications_rounded,
        tint: const Color(0xFFF5B42A),
        onTap: () => onNavigate(3),
      ),
      _MenuEntry(
        label: 'Profile',
        icon: Icons.person_rounded,
        tint: const Color(0xFF76A7FF),
        onTap: () => _openAccountSection(context, AccountHubSection.profile),
      ),
      _MenuEntry(
        label: 'Settings',
        icon: Icons.settings_rounded,
        tint: const Color(0xFF9AA4C9),
        onTap: () => _openAccountSection(context, AccountHubSection.terms),
      ),
    ];

    final suggestions = <_SuggestionEntry>[
      _SuggestionEntry(
        label: 'Nails Talk Premium',
        icon: Icons.diamond_rounded,
        color: const Color(0xFF9B7CF7),
        onTap: () => _showMessage(
          context,
          'Premium access can be connected after the next demo pass.',
        ),
      ),
      _SuggestionEntry(
        label: 'Ads',
        icon: Icons.campaign_rounded,
        color: const Color(0xFF6A6C91),
        onTap: () =>
            _showMessage(context, 'Ads can be managed from the admin console.'),
      ),
      _SuggestionEntry(
        label: 'Help center',
        icon: Icons.help_outline_rounded,
        color: const Color(0xFF6A6C91),
        onTap: () => _openAccountSection(context, AccountHubSection.faq),
      ),
      _SuggestionEntry(
        label: 'Share app',
        icon: Icons.share_rounded,
        color: const Color(0xFF6A6C91),
        onTap: () => _showMessage(
          context,
          'App sharing will be connected in the next release.',
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _MenuBackground(
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 132),
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB9BFCD),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('Menu'),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: _menuText,
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    InkWell(
                      onTap: () => onNavigate(0),
                      borderRadius: BorderRadius.circular(14),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.close_rounded,
                          color: _menuText,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                InkWell(
                  onTap: () =>
                      _openAccountSection(context, AccountHubSection.profile),
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _menuBorder),
                      boxShadow: const [
                        BoxShadow(
                          color: _menuShadow,
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const AppLogo(size: 46, showWordmark: false),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppConstants.appName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: _menuText,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                userHandle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: _menuMuted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: _menuMuted,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _MenuSectionTitle(label: 'Explore'),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: exploreEntries.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    mainAxisExtent: 84,
                  ),
                  itemBuilder: (context, index) {
                    return _MenuTile(entry: exploreEntries[index]);
                  },
                ),
                const SizedBox(height: 22),
                _MenuSectionTitle(label: 'Personal'),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: personalEntries.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    mainAxisExtent: 84,
                  ),
                  itemBuilder: (context, index) {
                    return _MenuTile(entry: personalEntries[index]);
                  },
                ),
                const SizedBox(height: 22),
                _MenuSectionTitle(label: 'Other utilities'),
                const SizedBox(height: 12),
                _SuggestionPanel(entries: suggestions),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuEntry {
  const _MenuEntry({
    required this.label,
    required this.icon,
    required this.tint,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;
}

class _SuggestionEntry {
  const _SuggestionEntry({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.entry});

  final _MenuEntry entry;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: entry.onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _menuBorder),
          boxShadow: const [
            BoxShadow(color: _menuShadow, blurRadius: 20, offset: Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: entry.tint.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(entry.icon, color: entry.tint, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.tr(entry.label),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _menuText,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuSectionTitle extends StatelessWidget {
  const _MenuSectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      context.tr(label),
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: _menuText,
        fontSize: 17,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.entry});

  final _SuggestionEntry entry;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: entry.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Icon(entry.icon, color: entry.color, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                context.tr(entry.label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: _menuText,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionPanel extends StatelessWidget {
  const _SuggestionPanel({required this.entries});

  final List<_SuggestionEntry> entries;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _menuBorder),
          boxShadow: const [
            BoxShadow(color: _menuShadow, blurRadius: 20, offset: Offset(0, 8)),
          ],
        ),
        child: Column(
          children: [
            for (var index = 0; index < entries.length; index++) ...[
              _SuggestionTile(entry: entries[index]),
              if (index != entries.length - 1)
                const Divider(height: 1, thickness: 1, color: _menuBorder),
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuBackground extends StatelessWidget {
  const _MenuBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_menuBgTop, _menuBgBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -40,
            right: -20,
            child: _MenuBubble(
              width: 190,
              height: 190,
              colors: [Color(0x14F4A6B0), Color(0x00FFFFFF)],
            ),
          ),
          const Positioned(
            top: 160,
            left: -32,
            child: _MenuBubble(
              width: 130,
              height: 210,
              colors: [Color(0x10F7CFC1), Color(0x00FFFFFF)],
            ),
          ),
          const Positioned(
            bottom: 70,
            right: 10,
            child: _MenuBubble(
              width: 180,
              height: 160,
              colors: [Color(0x10BFD3FF), Color(0x00FFFFFF)],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _MenuBubble extends StatelessWidget {
  const _MenuBubble({
    required this.width,
    required this.height,
    required this.colors,
  });

  final double width;
  final double height;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width / 2),
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }
}
