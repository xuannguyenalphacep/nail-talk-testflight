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
    final listBottomPadding = MediaQuery.viewPaddingOf(context).bottom + 36;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Text(
          context.tr(item.title.isEmpty ? 'Marketplace item' : item.title),
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
      body: MetroPageBackground(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 10, 16, listBottomPadding),
          children: [
            MetroInsetPanel(
              borderColor: kMetroPrimary,
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
                        Text(
                          context.tr(item.title),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(color: kMetroInk, fontSize: 30),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _money(item.price, item.currency),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: kMetroCoral,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (location.isNotEmpty)
                              MetroBadge(
                                label: location,
                                backgroundColor: const Color(0xFFF0F3FA),
                              ),
                            if (item.status.isNotEmpty)
                              MetroBadge(
                                label: _marketplaceStatusLabel(item.status),
                                backgroundColor: const Color(0xFFEFF8F2),
                              ),
                            if (item.userName.isNotEmpty)
                              MetroBadge(
                                label: item.userName,
                                backgroundColor: const Color(0xFFFFEEF2),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: () => widget.onContact(item),
                                child: Text(context.tr('Message seller')),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => controller.toggleBookmark(
                                  type: 'marketplace_listing',
                                  id: item.id,
                                ),
                                child: Text(
                                  context.tr(
                                    item.saved ? 'Saved' : 'Save item',
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
                    context.tr(
                      item.description.isEmpty
                          ? 'Useful finds, salon gear, and community listings.'
                          : item.description,
                    ),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: kMetroMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            MetroInsetPanel(
              borderColor: kMetroCoral,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Seller info'),
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: kMetroInk),
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    label: 'Name',
                    value: item.userName.isEmpty ? '...' : item.userName,
                  ),
                  if (item.contactPhone.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _DetailRow(label: 'Phone', value: item.contactPhone),
                  ],
                  if (item.contactEmail.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _DetailRow(label: 'Email', value: item.contactEmail),
                  ],
                  if (item.categoryName.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _DetailRow(label: 'Category', value: item.categoryName),
                  ],
                ],
              ),
            ),
          ],
        ),
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
