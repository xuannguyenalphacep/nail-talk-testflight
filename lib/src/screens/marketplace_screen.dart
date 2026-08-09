import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/chat_controller.dart';
import '../controllers/social_hub_controller.dart';
import '../models/marketplace_item.dart';
import '../widgets/remote_image.dart';
import '../widgets/us_state_dropdown_field.dart';
import 'chat_home_screen.dart';
import 'forms/marketplace_form_screen.dart';

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
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('This seller chat is not available yet.'),
        ),
      );
      return;
    }

    final chat = context.read<ChatController>();
    await chat.connectIfNeeded();
    await chat.openPrivateChatByUserId(item.userId);
    if (!mounted || chat.activeRoom == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChatHomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SocialHubController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace'),
        actions: [
          IconButton(
            onPressed: controller.loadingMarketplace ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const MarketplaceFormScreen()),
          );
          if (created == true && mounted) {
            await _refresh();
          }
        },
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('Post Item'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products',
                suffixIcon: IconButton(
                  onPressed: _refresh,
                  icon: const Icon(Icons.search_rounded),
                ),
              ),
              onSubmitted: (_) => _refresh(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('All categories'),
                ),
                ...controller.marketplaceCategories.map(
                  (category) => DropdownMenuItem<int?>(
                    value: category.id,
                    child: Text(category.name),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() => _categoryId = value);
                _refresh();
              },
            ),
            const SizedBox(height: 12),
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
                FilterChip(
                  label: const Text('My posts'),
                  selected: _mineOnly,
                  onSelected: (value) {
                    setState(() => _mineOnly = value);
                    _refresh();
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (controller.loadingMarketplace &&
                controller.marketplaceItems.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              ...controller.marketplaceItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _MarketplaceCard(
                    item: item,
                    onSave: () => controller.toggleBookmark(
                      type: 'marketplace_listing',
                      id: item.id,
                    ),
                    onContact: () => _contactSeller(item),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MarketplaceCard extends StatelessWidget {
  const _MarketplaceCard({
    required this.item,
    required this.onSave,
    required this.onContact,
  });

  final MarketplaceItem item;
  final Future<void> Function() onSave;
  final Future<void> Function() onContact;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ListingImageHeader(
            imageUrl: item.imageUrls.isEmpty ? '' : item.imageUrls.first,
            saved: item.saved,
            fallbackIcon: Icons.storefront_rounded,
            onSave: onSave,
            leadingBadge: item.categoryName.isEmpty ? null : item.categoryName,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${item.currency} ${item.price.toStringAsFixed(0)} • ${item.city}, ${item.state}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF52627A),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  item.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (item.condition.isNotEmpty)
                      _MarketplaceBadge(label: item.condition),
                    if (item.userName.isNotEmpty)
                      _MarketplaceBadge(label: item.userName),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onContact,
                    icon: const Icon(Icons.chat_bubble_rounded),
                    label: const Text('Message seller'),
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

class _ListingImageHeader extends StatelessWidget {
  const _ListingImageHeader({
    required this.imageUrl,
    required this.saved,
    required this.fallbackIcon,
    required this.onSave,
    this.leadingBadge,
  });

  final String imageUrl;
  final bool saved;
  final IconData fallbackIcon;
  final Future<void> Function() onSave;
  final String? leadingBadge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: imageUrl.isEmpty
              ? _ListingImagePlaceholder(icon: fallbackIcon)
              : RemoteImage(
                  url: imageUrl,
                  fit: BoxFit.cover,
                  errorFallback: _ListingImagePlaceholder(icon: fallbackIcon),
                ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.04),
                  Colors.black.withValues(alpha: 0.34),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        if (leadingBadge != null && leadingBadge!.isNotEmpty)
          Positioned(
            left: 14,
            bottom: 14,
            child: _MarketplaceBadge(label: leadingBadge!, light: true),
          ),
        Positioned(
          top: 12,
          right: 12,
          child: Material(
            color: Colors.white.withValues(alpha: 0.92),
            shape: const CircleBorder(),
            child: IconButton(
              onPressed: onSave,
              icon: Icon(
                saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ListingImagePlaceholder extends StatelessWidget {
  const _ListingImagePlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE7EEF9), Color(0xFFD7E9FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(icon, size: 34, color: const Color(0xFF4A6FA5)),
      ),
    );
  }
}

class _MarketplaceBadge extends StatelessWidget {
  const _MarketplaceBadge({required this.label, this.light = false});

  final String label;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: light
            ? Colors.white.withValues(alpha: 0.88)
            : const Color(0xFFF2F6FC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: light ? const Color(0xFF26415F) : const Color(0xFF52627A),
        ),
      ),
    );
  }
}
