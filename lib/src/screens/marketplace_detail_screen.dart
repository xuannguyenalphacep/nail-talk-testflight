import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/social_hub_controller.dart';
import '../core/localization/app_localizer.dart';
import '../models/marketplace_item.dart';
import '../widgets/metro_ui.dart';
import '../widgets/remote_image.dart';

class MarketplaceDetailScreen extends StatefulWidget {
  const MarketplaceDetailScreen({
    required this.item,
    required this.onContact,
    super.key,
  });

  final MarketplaceItem item;
  final Future<void> Function(MarketplaceItem item) onContact;

  @override
  State<MarketplaceDetailScreen> createState() =>
      _MarketplaceDetailScreenState();
}

class _MarketplaceDetailScreenState extends State<MarketplaceDetailScreen> {
  int _imageIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  MarketplaceItem _resolveCurrentItem(SocialHubController controller) {
    for (final item in controller.marketplaceItems) {
      if (item.id == widget.item.id) {
        return item;
      }
    }
    return widget.item;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SocialHubController>();
    final item = _resolveCurrentItem(controller);
    final imageUrls = item.imageUrls.isEmpty ? const [''] : item.imageUrls;
    final safeIndex = _imageIndex.clamp(0, imageUrls.length - 1);
    final location = _location(item.city, item.state);
    final displayTitle = _cleanMarketplaceText(item.title);
    final displayDescription = _cleanMarketplaceText(item.description);
    final safeTitle = displayTitle.isEmpty ? 'Marketplace item' : displayTitle;
    final safeDescription = displayDescription.isEmpty
        ? 'Useful finds, salon gear, and community listings.'
        : displayDescription;
    final contactName = _sellerDisplayName(item);
    final contactPhone = _publicPhone(item);
    final contactEmail = _publicEmail(item);
    final showContactInfo =
        contactName.isNotEmpty ||
        contactPhone.isNotEmpty ||
        contactEmail.isNotEmpty ||
        item.city.trim().isNotEmpty ||
        item.state.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Text(
          context.tr('Buy & Sell'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          MetroActionButton(
            icon: item.saved
                ? Icons.bookmark_rounded
                : Icons.bookmark_add_outlined,
            label: item.saved ? 'Saved' : 'Save item',
            onPressed: () => controller.toggleBookmark(
              type: 'marketplace_listing',
              id: item.id,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBFA).withValues(alpha: 0.98),
          border: const Border(top: BorderSide(color: kMetroLine)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x180F172A),
              blurRadius: 22,
              offset: Offset(0, -10),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: () => widget.onContact(item),
                      style: metroSoftFilledButtonStyle(context, kMetroPrimary),
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: Text(
                        context.tr(
                          _hasVisiblePublicContact(item)
                              ? 'Contact seller'
                              : 'Message seller',
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => controller.toggleBookmark(
                      type: 'marketplace_listing',
                      id: item.id,
                    ),
                    style: metroSoftOutlinedButtonStyle(context),
                    icon: Icon(
                      item.saved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_add_outlined,
                    ),
                    label: Text(context.tr(item.saved ? 'Saved' : 'Save item')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: MetroPageBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          children: [
            MetroInsetPanel(
              borderColor: kMetroCoral,
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 1.22,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(kMetroRadius),
                      child: Stack(
                        children: [
                          PageView.builder(
                            controller: _pageController,
                            itemCount: imageUrls.length,
                            onPageChanged: (index) {
                              setState(() => _imageIndex = index);
                            },
                            itemBuilder: (context, index) {
                              final url = imageUrls[index];
                              if (url.trim().isEmpty) {
                                return const _MarketplaceFallbackArt();
                              }
                              return RemoteImage(
                                url: url,
                                fit: BoxFit.cover,
                                errorFallback: const _MarketplaceFallbackArt(),
                              );
                            },
                          ),
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (item.categoryName.isNotEmpty)
                                  MetroBadge(label: item.categoryName),
                                if (item.condition.isNotEmpty)
                                  MetroBadge(
                                    label: _humanize(item.condition),
                                    backgroundColor: const Color(0xFFFFF2DE),
                                  ),
                              ],
                            ),
                          ),
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: MetroBadge(
                              label:
                                  '${safeIndex + 1}/${imageUrls.length.toString()}',
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.9,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (imageUrls.length > 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                      child: SizedBox(
                        height: 58,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: imageUrls.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final selected = safeIndex == index;
                            return GestureDetector(
                              onTap: () {
                                setState(() => _imageIndex = index);
                                _pageController.animateToPage(
                                  index,
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutCubic,
                                );
                              },
                              child: Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: selected ? kMetroCoral : kMetroLine,
                                    width: selected ? 1.6 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    kMetroRadius,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: imageUrls[index].trim().isEmpty
                                    ? const _MarketplaceFallbackArt()
                                    : RemoteImage(
                                        url: imageUrls[index],
                                        fit: BoxFit.cover,
                                        errorFallback:
                                            const _MarketplaceFallbackArt(),
                                      ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (item.categoryName.isNotEmpty)
                              MetroBadge(
                                label: item.categoryName,
                                backgroundColor: kMetroCoralSoft,
                              ),
                            if (item.status.isNotEmpty)
                              MetroBadge(
                                label: _marketplaceStatusLabel(item.status),
                                backgroundColor: const Color(0xFFEFF8F2),
                              ),
                            if (location.isNotEmpty)
                              MetroBadge(
                                label: location,
                                backgroundColor: const Color(0xFFF0F3FA),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.tr(safeTitle),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: kMetroInk,
                                fontSize: 25,
                                height: 1.08,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr(_money(item.price, item.currency)),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: kMetroCoral,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 16),
                        _MarketplaceSummaryGrid(
                          location: location,
                          contactName: contactName,
                          phone: contactPhone,
                          category: item.categoryName,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            MetroInsetPanel(
              borderColor: kMetroPrimary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('About this item'),
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: kMetroInk),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.tr(safeDescription),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: kMetroMuted,
                      height: 1.5,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (showContactInfo) ...[
              const SizedBox(height: 12),
              MetroInsetPanel(
                borderColor: kMetroCoral,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Contact information'),
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: kMetroInk),
                    ),
                    const SizedBox(height: 12),
                    if (contactName.isNotEmpty)
                      _DetailRow(label: 'Name', value: contactName),
                    if (contactPhone.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _DetailRow(label: 'Phone', value: contactPhone),
                    ],
                    if (contactEmail.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _DetailRow(label: 'Email', value: contactEmail),
                    ],
                    if (item.city.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _DetailRow(label: 'City', value: item.city.trim()),
                    ],
                    if (item.state.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _DetailRow(label: 'State', value: item.state.trim()),
                    ],
                    if (item.categoryName.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _DetailRow(label: 'Category', value: item.categoryName),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MarketplaceSummaryGrid extends StatelessWidget {
  const _MarketplaceSummaryGrid({
    required this.location,
    required this.contactName,
    required this.phone,
    required this.category,
  });

  final String location;
  final String contactName;
  final String phone;
  final String category;

  @override
  Widget build(BuildContext context) {
    final contactValue = contactName.isNotEmpty
        ? contactName
        : (phone.isNotEmpty ? phone : 'Contact seller');

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MarketplaceSummaryTile(
                icon: Icons.place_outlined,
                label: 'Location',
                value: location.isEmpty
                    ? 'Contact to confirm location'
                    : location,
                accent: kMetroPrimary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MarketplaceSummaryTile(
                icon: Icons.person_outline_rounded,
                label: 'Seller contact',
                value: contactValue,
                accent: kMetroCoral,
              ),
            ),
          ],
        ),
        if (category.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          _MarketplaceSummaryTile(
            icon: Icons.category_outlined,
            label: 'Category',
            value: category.trim(),
            accent: kMetroGold,
          ),
        ],
      ],
    );
  }
}

class _MarketplaceSummaryTile extends StatelessWidget {
  const _MarketplaceSummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kMetroLine),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  context.tr(label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: kMetroMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.tr(value),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: kMetroInk,
                    fontWeight: FontWeight.w900,
                    height: 1.12,
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            context.tr(label),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: kMetroMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: kMetroInk),
          ),
        ),
      ],
    );
  }
}

class _MarketplaceFallbackArt extends StatelessWidget {
  const _MarketplaceFallbackArt();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF9E2DB), Color(0xFFFFEADA), Color(0xFFDDE3F2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.storefront_rounded,
          size: 42,
          color: Color(0xFF27366E),
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

String _marketplaceStatusLabel(String status) {
  switch (status.trim().toLowerCase()) {
    case 'published':
      return 'Published';
    case 'draft':
      return 'Draft';
    case 'pending':
      return 'Pending';
    case 'active':
      return 'Active';
    case 'inactive':
      return 'Inactive';
    default:
      return _humanize(status);
  }
}
