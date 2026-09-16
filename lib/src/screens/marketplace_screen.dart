import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/chat_controller.dart';
import '../controllers/social_hub_controller.dart';
import '../core/localization/app_localizer.dart';
import '../models/app_option.dart';
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
    if (item.isImportedSource && _hasVisiblePublicContact(item)) {
      await _showPublicContactSheet(item);
      return;
    }

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

  Future<void> _showPublicContactSheet(MarketplaceItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFFBFA),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => _MarketplaceContactSheet(item: item),
    );
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

  String _selectedCategoryLabel(List<AppOption> categories) {
    if (_categoryId == null) return 'All categories';
    for (final category in categories) {
      if (category.id == _categoryId) return category.name;
    }
    return 'All categories';
  }

  Future<void> _openCategoryPicker(List<AppOption> categories) async {
    final selectedId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _MarketplaceCategoryPicker(
          categories: categories,
          selectedCategoryId: _categoryId,
        );
      },
    );

    if (!mounted || selectedId == null) return;

    final nextCategoryId = selectedId <= 0 ? null : selectedId;
    if (nextCategoryId == _categoryId) return;

    setState(() => _categoryId = nextCategoryId);
    await _refresh();
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
                      _MarketplaceCategorySelector(
                        label: _selectedCategoryLabel(
                          controller.marketplaceCategories,
                        ),
                        onTap: () => _openCategoryPicker(
                          controller.marketplaceCategories,
                        ),
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
    final title = _cleanMarketplaceText(item.title);
    final description = _cleanMarketplaceText(item.description);

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
              context.tr(title.isEmpty ? 'Marketplace item' : title),
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
                description.isEmpty
                    ? 'Useful finds, salon gear, and community listings.'
                    : description,
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
    final sellerBadge = _sellerDisplayName(item);
    final title = _cleanMarketplaceText(item.title);
    final description = _cleanMarketplaceText(item.description);

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
                    context.tr(title.isEmpty ? 'Marketplace item' : title),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: kMetroInk,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(_money(item.price, item.currency)),
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
                    context.tr(
                      description.isEmpty
                          ? 'Useful finds, salon gear, and community listings.'
                          : description,
                    ),
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
                      if (sellerBadge.isNotEmpty)
                        MetroBadge(
                          label: sellerBadge,
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
                            child: Text(
                              context.tr(
                                _hasVisiblePublicContact(item)
                                    ? 'Contact seller'
                                    : 'Message seller',
                              ),
                            ),
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

class _MarketplaceCategorySelector extends StatelessWidget {
  const _MarketplaceCategorySelector({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kMetroLine),
          boxShadow: const [
            BoxShadow(
              color: Color(0x100F172A),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: kMetroCoralSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.category_rounded,
                color: kMetroCoral,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Category'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: kMetroMuted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.tr(label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: kMetroInk,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: kMetroPrimary,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketplaceCategoryPicker extends StatelessWidget {
  const _MarketplaceCategoryPicker({
    required this.categories,
    required this.selectedCategoryId,
  });

  final List<AppOption> categories;
  final int? selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final choices = [
      AppOption(id: 0, uuid: '', name: 'All categories', slug: 'all'),
      ...categories,
    ];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
      ),
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(18, 12, 18, 18 + bottomPadding),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFA),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x260F172A),
            blurRadius: 30,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 52,
              height: 5,
              decoration: BoxDecoration(
                color: kMetroLine,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            context.tr('Choose category'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: kMetroInk,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: choices.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final category = choices[index];
                final isAll = category.id == 0;
                final selected = isAll
                    ? selectedCategoryId == null
                    : selectedCategoryId == category.id;

                return InkWell(
                  onTap: () => Navigator.of(context).pop(category.id),
                  borderRadius: BorderRadius.circular(18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? kMetroCoralSoft : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected ? kMetroCoral : kMetroLine,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: selected ? kMetroCoral : kMetroMuted,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            context.tr(category.name),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: selected ? kMetroPrimary : kMetroInk,
                                  fontWeight: FontWeight.w900,
                                  height: 1.2,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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

class _MarketplaceContactSheet extends StatelessWidget {
  const _MarketplaceContactSheet({required this.item});

  final MarketplaceItem item;

  Future<void> _launch(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final errorMessage = context.tr('Unable to open this contact link.');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      messenger?.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(errorMessage),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final contactName = _sellerDisplayName(item);
    final phone = _publicPhone(item);
    final email = _publicEmail(item);
    final sourceUrl = item.sourceUrl.trim();

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Contact seller'),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: kMetroInk),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('Use the public contact shown on this listing.'),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: kMetroMuted),
          ),
          const SizedBox(height: 18),
          if (contactName.isNotEmpty)
            _MarketplaceContactRow(
              icon: Icons.person_outline_rounded,
              label: 'Name',
              value: contactName,
            ),
          if (phone.isNotEmpty)
            _MarketplaceContactAction(
              icon: Icons.call_outlined,
              label: 'Call seller',
              value: phone,
              onTap: () => _launch(context, Uri(scheme: 'tel', path: phone)),
            ),
          if (email.isNotEmpty)
            _MarketplaceContactAction(
              icon: Icons.email_outlined,
              label: 'Email seller',
              value: email,
              onTap: () => _launch(context, Uri(scheme: 'mailto', path: email)),
            ),
          if (sourceUrl.isNotEmpty)
            _MarketplaceContactAction(
              icon: Icons.open_in_new_rounded,
              label: 'Open original listing',
              value: item.sourceName.trim().isEmpty
                  ? sourceUrl
                  : item.sourceName.trim(),
              onTap: () => _launch(context, Uri.parse(sourceUrl)),
            ),
        ],
      ),
    );
  }
}

class _MarketplaceContactRow extends StatelessWidget {
  const _MarketplaceContactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kMetroLine),
      ),
      child: Row(
        children: [
          Icon(icon, color: kMetroCoral, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(label),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: kMetroMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: kMetroInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketplaceContactAction extends StatelessWidget {
  const _MarketplaceContactAction({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: _MarketplaceContactRow(icon: icon, label: label, value: value),
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

String _sellerDisplayName(MarketplaceItem item) {
  final contactName = item.contactName.trim();
  if (contactName.isNotEmpty && !_isSyntheticSeller(contactName)) {
    return contactName;
  }

  final userName = item.userName.trim();
  if (!item.isImportedSource && !_isSyntheticSeller(userName)) {
    return userName;
  }

  return '';
}

String _publicPhone(MarketplaceItem item) {
  final phone = item.contactPhone.trim();
  if (phone.isNotEmpty) return phone;
  return _firstPhone('${item.title} ${item.description}');
}

String _publicEmail(MarketplaceItem item) {
  final email = item.contactEmail.trim();
  if (email.isNotEmpty) return email;
  return _firstEmail('${item.title} ${item.description}');
}

bool _hasVisiblePublicContact(MarketplaceItem item) {
  return _sellerDisplayName(item).isNotEmpty ||
      _publicPhone(item).isNotEmpty ||
      _publicEmail(item).isNotEmpty ||
      item.sourceUrl.trim().isNotEmpty;
}

bool _isSyntheticSeller(String value) {
  final lower = value.trim().toLowerCase();
  return lower.isEmpty ||
      lower == 'nails talk market source' ||
      lower == 'hỗ trợ mua và bán' ||
      lower == 'ho tro mua va ban';
}

String _cleanMarketplaceText(String raw) {
  return raw
      .replaceAll(
        RegExp(r'\s*Nguồn tham khảo:.*$', caseSensitive: false, dotAll: true),
        ' ',
      )
      .replaceAll(
        RegExp(r'\s*Nails Talk Market Source\s*', caseSensitive: false),
        ' ',
      )
      .replaceAll(
        RegExp(r'\s*liên hệ theo tin gốc\.?', caseSensitive: false),
        ' ',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _firstPhone(String text) {
  final match = RegExp(
    r'(?:(?:\+?1[\s\-.]?)?(?:\(?\d{3}\)?[\s\-.]?\d{3}[\s\-.]?\d{4}))',
  ).firstMatch(text);
  return match?.group(0)?.trim() ?? '';
}

String _firstEmail(String text) {
  final match = RegExp(
    r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
    caseSensitive: false,
  ).firstMatch(text);
  return match?.group(0)?.trim() ?? '';
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
  if (value <= 0) {
    return 'Price on request';
  }

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
