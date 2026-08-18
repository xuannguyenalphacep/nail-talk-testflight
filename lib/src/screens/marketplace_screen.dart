import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/chat_controller.dart';
import '../controllers/social_hub_controller.dart';
import '../core/localization/app_localizer.dart';
import '../models/marketplace_item.dart';
import '../widgets/language_switch_button.dart';
import '../widgets/metro_ui.dart';
import '../widgets/us_state_dropdown_field.dart';
import 'chat_home_screen.dart';
import 'forms/marketplace_form_screen.dart';
import 'marketplace_detail_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _mineOnly = false;
  int? _categoryId;
  String? _stateFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SocialHubController>().ensureUsStatesLoaded();
      context.read<SocialHubController>().refreshMarketplace();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() {
    return context.read<SocialHubController>().refreshMarketplace(
      mine: _mineOnly,
      categoryId: _categoryId,
      state: _stateFilter,
      search: _searchController.text,
    );
  }

  Future<void> _contactSeller(MarketplaceItem item) async {
    if (item.userId <= 0) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(context.tr('This seller chat is not available yet.')),
        ),
      );
      return;
    }

    final chat = context.read<ChatController>();
    await chat.connectIfNeeded();
    await chat.openPrivateChatByUserId(item.userId);
    if (!mounted) {
      return;
    }
    if (chat.activeRoom == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(chat.error ?? context.tr('Failed to start the chat.')),
        ),
      );
      return;
    }

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ChatHomeScreen()));
  }

  Future<void> _openDetail(MarketplaceItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            MarketplaceDetailScreen(item: item, onContact: _contactSeller),
      ),
    );
  }

  Future<void> _openComposer() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const MarketplaceFormScreen()),
    );
    if (created == true && mounted) {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SocialHubController>();
    final unreadCount = context.watch<ChatController>().visibleRooms.fold<int>(
      0,
      (total, room) => total + room.unreadCount,
    );
    final items = controller.marketplaceItems;
    final featured = items.isNotEmpty ? items.first : null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MetroPageBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
              children: [
                _MarketplaceTopBar(
                  unreadCount: unreadCount,
                  onNotifications: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChatHomeScreen()),
                  ),
                  onRefresh: controller.loadingMarketplace ? null : _refresh,
                ),
                const SizedBox(height: 18),
                if (featured != null) ...[
                  _MarketplaceHero(
                    item: featured,
                    itemCount: items.length,
                    borderColor: kMetroPrimary,
                    onTap: () => _openDetail(featured),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  context.tr('Buy & Sell'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: kMetroInk,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr(
                    'Salon marketplace finds, tools, and local deals in one scroll.',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: kMetroMuted,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                MetroInsetPanel(
                  borderColor: kMetroPrimary,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: metroSoftInputDecoration(
                          context,
                          hintText: 'Search products',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: IconButton(
                            onPressed: _refresh,
                            icon: const Icon(Icons.search_rounded),
                          ),
                        ),
                        onSubmitted: (_) => _refresh(),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.tr('Browse by category'),
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: kMetroInk),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MarketplaceFilterChipButton(
                            label: 'All categories',
                            selected: _categoryId == null,
                            onTap: () {
                              setState(() => _categoryId = null);
                              _refresh();
                            },
                          ),
                          for (final category
                              in controller.marketplaceCategories)
                            _MarketplaceFilterChipButton(
                              label: category.name,
                              selected: _categoryId == category.id,
                              onTap: () {
                                setState(() => _categoryId = category.id);
                                _refresh();
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: UsStateDropdownField(
                              states: controller.usStates,
                              value: _stateFilter,
                              required: false,
                              loading: controller.loadingUsStates,
                              onChanged: (value) {
                                setState(() => _stateFilter = value);
                                _refresh();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: FilledButton(
                                onPressed: _openComposer,
                                style: metroSoftFilledButtonStyle(
                                  context,
                                  kMetroCoral,
                                ),
                                child: Text(context.tr('Post Item')),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _MarketplaceFilterChipButton(
                        label: 'My posts',
                        selected: _mineOnly,
                        onTap: () {
                          setState(() => _mineOnly = !_mineOnly);
                          _refresh();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (controller.loadingMarketplace && items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (items.isEmpty)
                  const SizedBox(
                    height: 210,
                    child: MetroEmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'Marketplace is still quiet',
                      message:
                          'Fresh listings will show up here as soon as the marketplace starts moving.',
                      borderColor: kMetroPrimary,
                    ),
                  )
                else
                  ...List<Widget>.generate(items.length, (index) {
                    final item = items[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MarketplaceEditorialTile(
                        item: item,
                        borderColor: _tileColor(index),
                        onSave: () => controller.toggleBookmark(
                          type: 'marketplace_listing',
                          id: item.id,
                        ),
                        onContact: () => _contactSeller(item),
                        onOpen: () => _openDetail(item),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MarketplaceTopBar extends StatelessWidget {
  const _MarketplaceTopBar({
    required this.unreadCount,
    required this.onNotifications,
    required this.onRefresh,
  });

  final int unreadCount;
  final VoidCallback onNotifications;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            context.tr('Buy & Sell'),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: kMetroInk,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const LanguageSwitchButton(compact: true),
        const SizedBox(width: 10),
        _MarketplaceTopButton(
          icon: Icons.notifications_none_rounded,
          badgeVisible: unreadCount > 0,
          onTap: onNotifications,
        ),
        const SizedBox(width: 10),
        _MarketplaceTopButton(
          icon: Icons.refresh_rounded,
          onTap: onRefresh == null ? null : () => onRefresh!(),
        ),
      ],
    );
  }
}

class _MarketplaceTopButton extends StatelessWidget {
  const _MarketplaceTopButton({
    required this.icon,
    this.badgeVisible = false,
    this.onTap,
  });

  final IconData icon;
  final bool badgeVisible;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kMetroLine),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(child: Icon(icon, color: kMetroInk, size: 22)),
            if (badgeVisible)
              const Positioned(
                top: 10,
                right: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: kMetroCoral,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(width: 8, height: 8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MarketplaceHero extends StatelessWidget {
  const _MarketplaceHero({
    required this.item,
    required this.itemCount,
    required this.borderColor,
    required this.onTap,
  });

  final MarketplaceItem item;
  final int itemCount;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 226,
      child: MetroImageFrame(
        borderColor: borderColor,
        imageUrl: item.imageUrls.isNotEmpty ? item.imageUrls.first : '',
        onTap: onTap,
        overlayTop: const Color(0x08000000),
        overlayBottom: const Color(0xD2151720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const MetroBadge(label: 'Marketplace'),
                const Spacer(),
                MetroBadge(
                  label: '$itemCount',
                  backgroundColor: borderColor.withValues(alpha: 0.94),
                  foregroundColor: Colors.white,
                  outlined: false,
                ),
              ],
            ),
            const Spacer(),
            Text(
              context.tr(item.title),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontSize: 30,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                item.description.isEmpty
                    ? 'Useful finds, salon gear, and community listings.'
                    : item.description,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketplaceEditorialTile extends StatelessWidget {
  const _MarketplaceEditorialTile({
    required this.item,
    required this.borderColor,
    required this.onSave,
    required this.onContact,
    required this.onOpen,
  });

  final MarketplaceItem item;
  final Color borderColor;
  final Future<void> Function() onSave;
  final Future<void> Function() onContact;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final location = _location(item.city, item.state);

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(kMetroRadius),
      child: MetroInsetPanel(
        borderColor: borderColor,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 154,
              child: MetroImageFrame(
                borderColor: borderColor,
                imageUrl: item.imageUrls.isNotEmpty ? item.imageUrls.first : '',
                padding: const EdgeInsets.all(12),
                overlayTop: const Color(0x07000000),
                overlayBottom: const Color(0x42000000),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.categoryName.isNotEmpty)
                      MetroBadge(label: item.categoryName),
                    const Spacer(),
                    InkWell(
                      onTap: onSave,
                      borderRadius: BorderRadius.circular(kMetroRadius),
                      child: Ink(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          border: Border.all(color: kMetroLine),
                        ),
                        child: Icon(
                          item.saved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_add_outlined,
                          color: kMetroInk,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(item.title),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: kMetroInk,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _money(item.price, item.currency),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: borderColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      location.isEmpty ? 'Marketplace item' : location,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: kMetroMuted),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(item.description),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: kMetroMuted),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (item.condition.isNotEmpty)
                        MetroBadge(
                          label: _humanize(item.condition),
                          backgroundColor: const Color(0xFFFFF2DE),
                        ),
                      if (item.userName.isNotEmpty)
                        MetroBadge(
                          label: item.userName,
                          backgroundColor: const Color(0xFFF0F3FA),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton(
                            onPressed: onOpen,
                            style: metroSoftOutlinedButtonStyle(context),
                            child: Text(context.tr('View details')),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: FilledButton(
                            onPressed: onContact,
                            style: metroSoftFilledButtonStyle(
                              context,
                              borderColor,
                            ),
                            child: Text(context.tr('Message seller')),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketplaceFilterChipButton extends StatelessWidget {
  const _MarketplaceFilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kMetroRadius),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? kMetroCoralSoft : kMetroSurface,
          borderRadius: BorderRadius.circular(kMetroRadius),
          border: Border.all(color: selected ? kMetroCoral : kMetroLine),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x10F36C84),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          context.tr(label),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: selected ? kMetroPrimary : kMetroInk,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

String _location(String city, String state) {
  final parts = <String>[
    if (city.trim().isNotEmpty) city.trim(),
    if (state.trim().isNotEmpty) state.trim(),
  ];
  return parts.join(', ');
}

String _humanize(String raw) {
  final cleaned = raw.replaceAll('_', ' ').replaceAll('-', ' ').trim();
  if (cleaned.isEmpty) return '';

  return cleaned
      .split(RegExp(r'\s+'))
      .map((word) {
        final lower = word.toLowerCase();
        return '${lower[0].toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
}

String _money(double value, String currency) {
  final prefix = currency.toUpperCase() == 'USD'
      ? '\$'
      : '${currency.toUpperCase()} ';
  final isWhole = value == value.roundToDouble();
  return '$prefix${value.toStringAsFixed(isWhole ? 0 : 2)}';
}

Color _tileColor(int index) {
  const palette = <Color>[
    kMetroCoral,
    kMetroPrimary,
    kMetroGold,
    kMetroSuccess,
    Color(0xFFC18E68),
  ];
  return palette[index % palette.length];
}
