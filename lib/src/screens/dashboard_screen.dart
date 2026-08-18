import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/chat_controller.dart';
import '../controllers/session_controller.dart';
import '../controllers/social_hub_controller.dart';
import '../core/constants/app_constants.dart';
import '../core/localization/app_localizer.dart';
import '../models/job_listing_item.dart';
import '../models/marketplace_item.dart';
import '../models/movie_item.dart';
import '../models/property_listing_item.dart';
import '../models/session_user.dart';
import '../widgets/app_logo.dart';
import '../widgets/language_switch_button.dart';
import '../widgets/remote_image.dart';
import 'account_hub_screen.dart';
import 'chat_home_screen.dart';
import 'marketplace_detail_screen.dart';
import 'movie_detail_screen.dart';
import 'work_stay_detail_screen.dart';

const Color _homeBgTop = Color(0xFFFFFCFA);
const Color _homeBgBottom = Color(0xFFFFF3ED);
const Color _homePanel = Colors.white;
const Color _homeText = Color(0xFF27366E);
const Color _homeMuted = Color(0xFF7C86A9);
const Color _homeBorder = Color(0xFFF0E8E4);
const Color _homeShadow = Color(0x160F172A);
const double _homeRadius = 28;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
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

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshFeed(SocialHubController social) {
    return Future.wait([
      social.refreshHome(),
      social.refreshMovies(),
      social.refreshMarketplace(),
      social.refreshJobs(),
      social.refreshProperties(),
    ]);
  }

  Future<void> _openProfile(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const AccountHubScreen(initialSection: AccountHubSection.profile),
      ),
    );
  }

  void _showGameComingSoon() {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(context.tr('Tien len card game is coming soon.')),
      ),
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

  Future<void> _openPrivateChat(int? userId, String unavailableMessage) async {
    if (userId == null || userId <= 0) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(context.tr(unavailableMessage)),
        ),
      );
      return;
    }

    final chat = context.read<ChatController>();
    await chat.connectIfNeeded();
    await chat.openPrivateChatByUserId(userId);
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

  Future<void> _openMarketplaceDetail(MarketplaceItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            MarketplaceDetailScreen(item: item, onContact: _contactSeller),
      ),
    );
  }

  Future<void> _openJobDetail(JobListingItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JobListingDetailScreen(
          item: item,
          onContact: (job) => _openPrivateChat(
            job.userId,
            'This recruiter chat is not available yet.',
          ),
        ),
      ),
    );
  }

  Future<void> _openPropertyDetail(PropertyListingItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PropertyListingDetailScreen(
          item: item,
          onContact: (property) => _openPrivateChat(
            property.userId,
            'This host chat is not available yet.',
          ),
        ),
      ),
    );
  }

  void _handleSearchChanged(String value) {
    setState(() => _searchQuery = value);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  List<_DashboardSearchSuggestion> _buildSearchSuggestions(
    SocialHubController social,
  ) {
    final query = _foldSearch(_searchQuery.trim());
    if (query.isEmpty) {
      return const [];
    }

    final suggestions = <_DashboardSearchSuggestion>[];

    for (final item in social.marketplaceItems) {
      final score = _matchScore(query, [
        item.title,
        item.description,
        item.categoryName,
        item.city,
        item.state,
        item.userName,
      ]);
      if (score == null) continue;
      suggestions.add(
        _DashboardSearchSuggestion(
          type: _DashboardSearchType.marketplace,
          score: score,
          title: item.title,
          subtitle: item.description,
          meta: _compactLocation(item.city, item.state),
          tag: 'Buy & Sell',
          imageUrl: item.imageUrls.isNotEmpty ? item.imageUrls.first : '',
          onTap: () => _openMarketplaceDetail(item),
        ),
      );
    }

    for (final item in social.jobItems) {
      final score = _matchScore(query, [
        item.title,
        item.description,
        item.salonName,
        item.requirements,
        item.city,
        item.state,
        item.userName,
      ]);
      if (score == null) continue;
      suggestions.add(
        _DashboardSearchSuggestion(
          type: _DashboardSearchType.job,
          score: score,
          title: item.title,
          subtitle: item.salonName.isNotEmpty
              ? item.salonName
              : item.description,
          meta: _compactLocation(item.city, item.state),
          tag: item.listingMode == 'hiring'
              ? 'Hiring nail staff'
              : 'Job seekers',
          imageUrl: item.imageUrls.isNotEmpty ? item.imageUrls.first : '',
          onTap: () => _openJobDetail(item),
        ),
      );
    }

    for (final item in social.propertyItems) {
      final score = _matchScore(query, [
        item.title,
        item.description,
        item.addressLine,
        item.city,
        item.state,
        item.userName,
        ...item.amenities,
      ]);
      if (score == null) continue;
      suggestions.add(
        _DashboardSearchSuggestion(
          type: _DashboardSearchType.property,
          score: score,
          title: item.title,
          subtitle: item.addressLine.isNotEmpty
              ? item.addressLine
              : item.description,
          meta: _compactLocation(item.city, item.state),
          tag: item.listingMode == 'looking_room'
              ? 'Looking for a room'
              : 'Homes for rent',
          imageUrl: item.imageUrls.isNotEmpty ? item.imageUrls.first : '',
          onTap: () => _openPropertyDetail(item),
        ),
      );
    }

    for (final item in social.movies) {
      final score = _matchScore(query, [
        item.title,
        item.summary,
        item.category?.name ?? '',
        item.thirdPartyProvider,
      ]);
      if (score == null) continue;
      suggestions.add(
        _DashboardSearchSuggestion(
          type: _DashboardSearchType.movie,
          score: score,
          title: item.title,
          subtitle: item.summary,
          meta: item.category?.name ?? item.thirdPartyProvider,
          tag: 'Movie picks',
          imageUrl: item.posterUrl.isNotEmpty ? item.posterUrl : item.bannerUrl,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: item)),
          ),
        ),
      );
    }

    suggestions.sort((left, right) {
      final scoreCompare = left.score.compareTo(right.score);
      if (scoreCompare != 0) return scoreCompare;
      final typeCompare = left.type.index.compareTo(right.type.index);
      if (typeCompare != 0) return typeCompare;
      return left.title.length.compareTo(right.title.length);
    });

    return suggestions.take(10).toList(growable: false);
  }

  Future<void> _handleSearch(SocialHubController social) async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      return;
    }

    final suggestions = _buildSearchSuggestions(social);
    if (suggestions.isNotEmpty) {
      FocusScope.of(context).unfocus();
      await suggestions.first.onTap();
      return;
    }

    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          context.tr('No matching posts found yet. Try another keyword.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final social = context.watch<SocialHubController>();
    final chat = context.watch<ChatController>();
    final summary = social.profile?.summary;
    final featuredMovie = social.movies.isNotEmpty ? social.movies.first : null;
    final jobs = social.jobItems.take(2).toList(growable: false);
    final marketItems = social.marketplaceItems.take(2).toList(growable: false);
    final properties = social.propertyItems.take(2).toList(growable: false);

    final unreadCount = chat.visibleRooms.fold<int>(
      0,
      (total, room) => total + room.unreadCount,
    );
    final movieCount = summary?.movieCount ?? social.movies.length;
    final jobCount = summary?.jobCount ?? social.jobItems.length;
    final propertyCount = summary?.propertyCount ?? social.propertyItems.length;
    final feedBusy =
        social.loadingHome ||
        social.loadingMovies ||
        social.loadingMarketplace ||
        social.loadingJobs ||
        social.loadingProperties;

    final movieImage = _movieImage(featuredMovie, social);
    final jobImage = _jobImage(jobs, social);
    final marketImage = _marketImage(marketItems, social);
    final housingImage = _housingImage(properties, social);
    final movieShowcaseImage = _pickFirstNonEmptyImage([
      movieImage,
      marketImage,
      housingImage,
      jobImage,
    ]);
    final communityChatImage = _pickFirstNonEmptyImage([
      movieImage,
      housingImage,
      marketImage,
      jobImage,
    ]);

    final heroCard = _HomeCardData(
      title: 'Heart-to-heart chat',
      subtitle: 'Join community rooms and private chats right away.',
      imageUrl: communityChatImage,
      fallbackImageUrl: movieShowcaseImage,
      arrowColor: const Color(0xFFF35F86),
      chips: const [
        _CardChipData(label: 'Groups'),
        _CardChipData(
          label: 'Chat rooms',
          backgroundColor: Color(0xFFF35F86),
          foregroundColor: Colors.white,
        ),
      ],
      onTap: () => widget.onNavigate(3),
    );
    final movieCard = _HomeCardData(
      title: 'Movie picks',
      subtitle: 'Featured movies for a relaxed night in.',
      imageUrl: movieShowcaseImage,
      fallbackImageUrl: communityChatImage,
      arrowColor: const Color(0xFFF35F86),
      chips: const [_CardChipData(label: 'Featured movies')],
      badge: movieCount > 0 ? '$movieCount' : null,
      badgeColor: const Color(0xFFF35F86),
      onTap: () => widget.onNavigate(1),
    );
    final marketCard = _HomeCardData(
      title: 'Buy & Sell',
      subtitle: 'Salon gear, decor, and daily community deals.',
      imageUrl: marketImage,
      fallbackImageUrl: movieShowcaseImage,
      arrowColor: const Color(0xFF3567E7),
      chips: const [],
      onTap: () => widget.onNavigate(2),
    );
    final jobCard = _HomeCardData(
      title: 'Find a job',
      subtitle: 'Latest salon openings and nearby job posts.',
      imageUrl: jobImage,
      fallbackImageUrl: movieShowcaseImage,
      arrowColor: const Color(0xFFF4B539),
      chips: const [_CardChipData(label: 'Latest openings')],
      badge: jobCount > 0 ? '$jobCount' : null,
      badgeColor: const Color(0xFFF4B539),
      onTap: () => widget.onOpenJobs('looking_for_job'),
    );
    final techCard = _HomeCardData(
      title: 'Find a tech',
      subtitle: 'Salon owners hiring and looking for the right tech.',
      imageUrl: jobImage,
      fallbackImageUrl: movieShowcaseImage,
      arrowColor: const Color(0xFFF4B539),
      chips: const [_CardChipData(label: 'Hiring salons')],
      onTap: () => widget.onOpenJobs('hiring'),
    );
    final needRoomCard = _HomeCardData(
      title: 'Need a room',
      subtitle: 'Find a room or roommate close to work.',
      imageUrl: housingImage,
      fallbackImageUrl: movieShowcaseImage,
      arrowColor: const Color(0xFF8F67F6),
      chips: const [],
      badge: propertyCount > 0 ? '$propertyCount' : null,
      badgeColor: const Color(0xFF8F67F6),
      onTap: () => widget.onOpenHousing('looking_room'),
    );
    final rentOutCard = _HomeCardData(
      title: 'Rent out a home',
      subtitle: 'Homes and rooms ready for move-in now.',
      imageUrl: housingImage,
      fallbackImageUrl: movieShowcaseImage,
      arrowColor: const Color(0xFF8F67F6),
      chips: const [],
      badge: propertyCount > 0 ? '$propertyCount' : null,
      badgeColor: const Color(0xFF8F67F6),
      onTap: () => widget.onOpenHousing('rent_out'),
    );
    final exploreCards = <_HomeCardData>[
      movieCard,
      marketCard,
      jobCard,
      techCard,
      needRoomCard,
      rentOutCard,
    ];
    final searchSuggestions = _buildSearchSuggestions(social);
    final showSearchSuggestions = _searchQuery.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _SoftPageBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () => _refreshFeed(social),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
              children: [
                _DashboardHeader(
                  user: session.user,
                  unreadCount: unreadCount,
                  onNotifications: () => widget.onNavigate(3),
                  onProfile: () => _openProfile(context),
                ),
                const SizedBox(height: 18),
                _SearchBar(
                  controller: _searchController,
                  onSubmitted: (_) => _handleSearch(social),
                  onSearchTap: () => _handleSearch(social),
                  onChanged: _handleSearchChanged,
                  onClear: _clearSearch,
                  hasValue: showSearchSuggestions,
                ),
                if (showSearchSuggestions) ...[
                  const SizedBox(height: 12),
                  _DashboardSearchSuggestionPanel(
                    suggestions: searchSuggestions,
                    onSuggestionTap: (suggestion) async {
                      FocusScope.of(context).unfocus();
                      _clearSearch();
                      await suggestion.onTap();
                    },
                  ),
                ],
                if (feedBusy) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: const LinearProgressIndicator(minHeight: 4),
                  ),
                ],
                const SizedBox(height: 22),
                SizedBox(height: 192, child: _HomeFeatureCard(data: heroCard)),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('Explore'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: _homeText,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => widget.onNavigate(4),
                      child: Text(context.tr('See all')),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: exploreCards.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    mainAxisExtent: 174,
                  ),
                  itemBuilder: (context, index) {
                    return _HomeFeatureCard(
                      data: exploreCards[index],
                      compact: true,
                    );
                  },
                ),
                const SizedBox(height: 22),
                _TienLenComingSoonBanner(onTap: _showGameComingSoon),
                if (social.error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _homeBorder),
                    ),
                    child: Text(
                      _friendlyFeedError(social.error!),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFA04F62),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.user,
    required this.unreadCount,
    required this.onNotifications,
    required this.onProfile,
  });

  final SessionUser? user;
  final int unreadCount;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const AppLogo(size: 42, showWordmark: false),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            AppConstants.appName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 28,
              color: _homeText,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const LanguageSwitchButton(compact: true),
        const SizedBox(width: 10),
        _HeaderIconButton(
          icon: Icons.notifications_none_rounded,
          badgeVisible: unreadCount > 0,
          onTap: onNotifications,
        ),
        const SizedBox(width: 10),
        _HeaderAvatarButton(user: user, onTap: onProfile),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onSubmitted,
    required this.onSearchTap,
    required this.onChanged,
    required this.onClear,
    required this.hasValue,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSearchTap;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool hasValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _homePanel.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _homeBorder),
        boxShadow: const [
          BoxShadow(color: _homeShadow, blurRadius: 24, offset: Offset(0, 12)),
        ],
      ),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: _homeText),
        decoration: InputDecoration(
          hintText: context.tr('Search in Nails Talk...'),
          hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: _homeMuted.withValues(alpha: 0.9),
          ),
          filled: false,
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          prefixIcon: Icon(
            Icons.search_rounded,
            color: _homeMuted.withValues(alpha: 0.95),
          ),
          suffixIcon: SizedBox(
            width: hasValue ? 92 : 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasValue)
                  IconButton(
                    onPressed: onClear,
                    icon: Icon(
                      Icons.close_rounded,
                      color: _homeMuted.withValues(alpha: 0.95),
                    ),
                  ),
                IconButton(
                  onPressed: onSearchTap,
                  icon: Icon(
                    Icons.arrow_forward_rounded,
                    color: _homeText.withValues(alpha: 0.96),
                  ),
                ),
              ],
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 18,
          ),
        ),
      ),
    );
  }
}

enum _DashboardSearchType { marketplace, job, property, movie }

class _DashboardSearchSuggestion {
  const _DashboardSearchSuggestion({
    required this.type,
    required this.score,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.tag,
    required this.imageUrl,
    required this.onTap,
  });

  final _DashboardSearchType type;
  final int score;
  final String title;
  final String subtitle;
  final String meta;
  final String tag;
  final String imageUrl;
  final Future<void> Function() onTap;
}

class _DashboardSearchSuggestionPanel extends StatelessWidget {
  const _DashboardSearchSuggestionPanel({
    required this.suggestions,
    required this.onSuggestionTap,
  });

  final List<_DashboardSearchSuggestion> suggestions;
  final Future<void> Function(_DashboardSearchSuggestion suggestion)
  onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: suggestions.isEmpty
          ? Container(
              key: const ValueKey('search-empty'),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _homePanel.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _homeBorder),
                boxShadow: const [
                  BoxShadow(
                    color: _homeShadow,
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Search suggestions'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _homeText,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr(
                      'No matching posts found yet. Try another keyword.',
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _homeMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            )
          : Container(
              key: const ValueKey('search-list'),
              decoration: BoxDecoration(
                color: _homePanel.withValues(alpha: 0.97),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: _homeBorder),
                boxShadow: const [
                  BoxShadow(
                    color: _homeShadow,
                    blurRadius: 26,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Search suggestions'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _homeText,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr(
                        'Quick matches from movies, market, jobs, and housing.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _homeMuted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (
                      var index = 0;
                      index < suggestions.length;
                      index++
                    ) ...[
                      _DashboardSearchSuggestionTile(
                        suggestion: suggestions[index],
                        onTap: () => onSuggestionTap(suggestions[index]),
                      ),
                      if (index != suggestions.length - 1)
                        Divider(
                          height: 18,
                          thickness: 1,
                          color: _homeBorder.withValues(alpha: 0.85),
                        ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class _DashboardSearchSuggestionTile extends StatelessWidget {
  const _DashboardSearchSuggestionTile({
    required this.suggestion,
    required this.onTap,
  });

  final _DashboardSearchSuggestion suggestion;
  final Future<void> Function() onTap;

  Color get _accentColor {
    switch (suggestion.type) {
      case _DashboardSearchType.marketplace:
        return const Color(0xFF3567E7);
      case _DashboardSearchType.job:
        return const Color(0xFFF4B539);
      case _DashboardSearchType.property:
        return const Color(0xFF8F67F6);
      case _DashboardSearchType.movie:
        return const Color(0xFFF35F86);
    }
  }

  IconData get _fallbackIcon {
    switch (suggestion.type) {
      case _DashboardSearchType.marketplace:
        return Icons.storefront_rounded;
      case _DashboardSearchType.job:
        return Icons.work_rounded;
      case _DashboardSearchType.property:
        return Icons.home_work_rounded;
      case _DashboardSearchType.movie:
        return Icons.smart_display_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(),
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              clipBehavior: Clip.antiAlias,
              child: suggestion.imageUrl.trim().isEmpty
                  ? Icon(_fallbackIcon, color: _accentColor, size: 28)
                  : RemoteImage(
                      url: suggestion.imageUrl,
                      fit: BoxFit.cover,
                      errorFallback: Icon(
                        _fallbackIcon,
                        color: _accentColor,
                        size: 28,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          context.tr(suggestion.tag),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: _accentColor,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                      if (suggestion.meta.trim().isNotEmpty)
                        Text(
                          context.tr(suggestion.meta),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: _homeMuted,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr(suggestion.title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _homeText,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.tr(
                      suggestion.subtitle.trim().isEmpty
                          ? suggestion.meta
                          : suggestion.subtitle,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _homeMuted,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _accentColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    this.badgeVisible = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool badgeVisible;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _homePanel.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _homeBorder),
          boxShadow: const [
            BoxShadow(color: _homeShadow, blurRadius: 18, offset: Offset(0, 8)),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Icon(
                icon,
                size: 24,
                color: _homeText.withValues(alpha: 0.94),
              ),
            ),
            if (badgeVisible)
              const Positioned(
                top: 11,
                right: 11,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFF35F86),
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

class _HeaderAvatarButton extends StatelessWidget {
  const _HeaderAvatarButton({required this.user, required this.onTap});

  final SessionUser? user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user?.avatarUrl.trim() ?? '';
    final source = user?.name.trim().isNotEmpty == true
        ? user!.name.trim()
        : user?.username.trim() ?? '';
    final initial = source.isEmpty ? 'N' : source[0].toUpperCase();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _homePanel.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _homeBorder),
          boxShadow: const [
            BoxShadow(color: _homeShadow, blurRadius: 18, offset: Offset(0, 8)),
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: avatarUrl.isEmpty
              ? DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFF8C7D0), Color(0xFFB7CCFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _homeText,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                )
              : RemoteImage(
                  url: avatarUrl,
                  fit: BoxFit.cover,
                  errorFallback: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFF8C7D0), Color(0xFFB7CCFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: _homeText,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _HomeCardData {
  const _HomeCardData({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.fallbackImageUrl,
    required this.arrowColor,
    required this.chips,
    required this.onTap,
    this.badge,
    this.badgeColor,
  });

  final String title;
  final String subtitle;
  final String imageUrl;
  final String fallbackImageUrl;
  final Color arrowColor;
  final List<_CardChipData> chips;
  final VoidCallback onTap;
  final String? badge;
  final Color? badgeColor;
}

class _CardChipData {
  const _CardChipData({
    required this.label,
    this.backgroundColor = Colors.white,
    this.foregroundColor = _homeText,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
}

class _HomeFeatureCard extends StatelessWidget {
  const _HomeFeatureCard({required this.data, this.compact = false});

  final _HomeCardData data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cardTitle = context.tr(data.title);
    final cardSubtitle = context.tr(data.subtitle);

    return InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(_homeRadius),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_homeRadius),
          boxShadow: const [
            BoxShadow(
              color: _homeShadow,
              blurRadius: 26,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_homeRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (data.imageUrl.isNotEmpty)
                RemoteImage(
                  url: data.imageUrl,
                  fit: BoxFit.cover,
                  errorFallback: data.fallbackImageUrl.isNotEmpty
                      ? RemoteImage(
                          url: data.fallbackImageUrl,
                          fit: BoxFit.cover,
                        )
                      : null,
                )
              else
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFF7D6C8), Color(0xFFB7C3E8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0x12000000), Color(0x99000000)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.18, 1],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 12 : 16,
                  compact ? 12 : 18,
                  compact ? 12 : 16,
                  compact ? 12 : 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: compact
                              ? _CardChip(
                                  label: cardTitle,
                                  backgroundColor: Colors.white,
                                  foregroundColor: _homeText,
                                  maxLines: 2,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                )
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: data.chips
                                      .map(
                                        (chip) => _CardChip(
                                          label: chip.label,
                                          backgroundColor: chip.backgroundColor,
                                          foregroundColor: chip.foregroundColor,
                                        ),
                                      )
                                      .toList(),
                                ),
                        ),
                        if (data.badge != null) ...[
                          const SizedBox(width: 10),
                          _CardBadge(
                            label: data.badge!,
                            backgroundColor:
                                data.badgeColor ?? const Color(0xFFF35F86),
                          ),
                        ],
                      ],
                    ),
                    const Spacer(),
                    Text(
                      compact ? cardSubtitle : cardTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (compact
                                  ? Theme.of(context).textTheme.titleMedium
                                  : Theme.of(context).textTheme.headlineMedium)
                              ?.copyWith(
                                color: Colors.white,
                                fontSize: compact ? 14 : 24,
                                height: compact ? 1.24 : 1.08,
                                fontWeight: compact
                                    ? FontWeight.w800
                                    : FontWeight.w900,
                              ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 8),
                      Text(
                        cardSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.96),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    SizedBox(height: compact ? 8 : 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: data.arrowColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: data.arrowColor.withValues(alpha: 0.28),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(compact ? 8 : 10),
                          child: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: compact ? 12 : 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardChip extends StatelessWidget {
  const _CardChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.maxLines = 1,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final int maxLines;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        context.tr(label),
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CardBadge extends StatelessWidget {
  const _CardBadge({required this.label, required this.backgroundColor});

  final String label;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          context.tr(label),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _TienLenComingSoonBanner extends StatelessWidget {
  const _TienLenComingSoonBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_homeRadius),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_homeRadius),
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF8F6), Color(0xFFFFEEF2), Color(0xFFFFF7EF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: const Color(0xFFFFD7E3)),
          boxShadow: const [
            BoxShadow(
              color: _homeShadow,
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -14,
              right: 16,
              child: _BlurBubble(
                width: 120,
                height: 120,
                colors: [Color(0x22FF8CA5), Color(0x00FFFFFF)],
              ),
            ),
            const Positioned(
              bottom: -22,
              left: -6,
              child: _BlurBubble(
                width: 170,
                height: 130,
                colors: [Color(0x14FFD6A5), Color(0x00FFFFFF)],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.86),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFFFD8E2)),
                          ),
                          child: Text(
                            context.tr('Entertainment preview'),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: const Color(0xFFF35F86),
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.tr('Tien len card game'),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontSize: 24,
                                color: _homeText,
                                fontWeight: FontWeight.w900,
                                height: 1.02,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          context.tr(
                            'An entertainment room for friends and the local nail community is coming soon to Nails Talk.',
                          ),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: _homeText.withValues(alpha: 0.82),
                                height: 1.42,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: const [
                            _CardChipData(
                              label: 'Four-player tables',
                              backgroundColor: Color(0xFFFFF5F8),
                              foregroundColor: Color(0xFFF35F86),
                            ),
                            _CardChipData(
                              label: 'Play with friends',
                              backgroundColor: Color(0xFFFFF7EE),
                              foregroundColor: Color(0xFFF4A22F),
                            ),
                          ].map(_GameFeatureChip.new).toList(),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF35F86), Color(0xFFFF9B55)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x26F35F86),
                                blurRadius: 20,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: FilledButton.icon(
                            onPressed: onTap,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(150, 46),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                            ),
                            icon: const Icon(
                              Icons.visibility_rounded,
                              size: 18,
                            ),
                            label: Text(context.tr('Preview feature')),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  const _TienLenShowcaseArtwork(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameFeatureChip extends StatelessWidget {
  const _GameFeatureChip(this.data);

  final _CardChipData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: data.backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
      ),
      child: Text(
        context.tr(data.label),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: data.foregroundColor,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TienLenShowcaseArtwork extends StatelessWidget {
  const _TienLenShowcaseArtwork();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 136,
      height: 148,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF1F5), Color(0xFFFFF8EF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 8,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFFFB061), Color(0xFFF35F86)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(
                Icons.stars_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: 22,
            child: Transform.rotate(
              angle: -0.2,
              child: const _GameCardFace(
                rank: 'A',
                suit: '♠',
                accent: Color(0xFF27366E),
                background: Colors.white,
              ),
            ),
          ),
          Positioned(
            right: 18,
            top: 30,
            child: Transform.rotate(
              angle: 0.18,
              child: const _GameCardFace(
                rank: 'K',
                suit: '♥',
                accent: Color(0xFFF35F86),
                background: Colors.white,
              ),
            ),
          ),
          Positioned(
            left: 28,
            bottom: 14,
            child: Container(
              width: 86,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Colors.white.withValues(alpha: 0.94),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x180F172A),
                    blurRadius: 14,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  _MiniChip(color: Color(0xFFF35F86)),
                  _MiniChip(color: Color(0xFFF4A22F)),
                  _MiniChip(color: Color(0xFF4E67C8)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameCardFace extends StatelessWidget {
  const _GameCardFace({
    required this.rank,
    required this.suit,
    required this.accent,
    required this.background,
  });

  final String rank;
  final String suit;
  final Color accent;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 82,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180F172A),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rank,
            textScaler: TextScaler.noScaling,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          Text(
            suit,
            textScaler: TextScaler.noScaling,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              suit,
              textScaler: TextScaler.noScaling,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: accent.withValues(alpha: 0.9),
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}

class _SoftPageBackground extends StatelessWidget {
  const _SoftPageBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_homeBgTop, _homeBgBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -40,
            right: -20,
            child: _BlurBubble(
              width: 190,
              height: 190,
              colors: [Color(0x14F4A6B0), Color(0x00FFFFFF)],
            ),
          ),
          const Positioned(
            top: 140,
            left: -28,
            child: _BlurBubble(
              width: 120,
              height: 200,
              colors: [Color(0x10F7CFC1), Color(0x00FFFFFF)],
            ),
          ),
          const Positioned(
            bottom: 70,
            right: 18,
            child: _BlurBubble(
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

class _BlurBubble extends StatelessWidget {
  const _BlurBubble({
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

String _movieImage(MovieItem? movie, SocialHubController social) {
  if (movie?.bannerUrl.isNotEmpty == true) return movie!.bannerUrl;
  if (movie?.posterUrl.isNotEmpty == true) return movie!.posterUrl;
  for (final item in social.movies) {
    if (item.bannerUrl.isNotEmpty) return item.bannerUrl;
    if (item.posterUrl.isNotEmpty) return item.posterUrl;
  }
  return '';
}

String _pickFirstNonEmptyImage(List<String> candidates) {
  for (final candidate in candidates) {
    if (candidate.trim().isNotEmpty) {
      return candidate.trim();
    }
  }
  return '';
}

String _jobImage(List<JobListingItem> jobs, SocialHubController social) {
  for (final item in jobs) {
    if (item.imageUrls.isNotEmpty) return item.imageUrls.first;
  }
  for (final item in social.jobItems) {
    if (item.imageUrls.isNotEmpty) return item.imageUrls.first;
  }
  return '';
}

String _marketImage(List<MarketplaceItem> items, SocialHubController social) {
  for (final item in items) {
    if (item.imageUrls.isNotEmpty) return item.imageUrls.first;
  }
  for (final item in social.marketplaceItems) {
    if (item.imageUrls.isNotEmpty) return item.imageUrls.first;
  }
  return '';
}

String _housingImage(
  List<PropertyListingItem> items,
  SocialHubController social,
) {
  for (final item in items) {
    if (item.imageUrls.isNotEmpty) return item.imageUrls.first;
  }
  for (final item in social.propertyItems) {
    if (item.imageUrls.isNotEmpty) return item.imageUrls.first;
  }
  return '';
}

String _compactLocation(String city, String state) {
  final safeCity = city.trim();
  final safeState = state.trim();
  if (safeCity.isEmpty) return safeState;
  if (safeState.isEmpty) return safeCity;
  return '$safeCity, $safeState';
}

String _foldSearch(String raw) {
  var output = raw.toLowerCase().trim();
  const replacements = <String, String>{
    '[àáạảãâầấậẩẫăằắặẳẵ]': 'a',
    '[èéẹẻẽêềếệểễ]': 'e',
    '[ìíịỉĩ]': 'i',
    '[òóọỏõôồốộổỗơờớợởỡ]': 'o',
    '[ùúụủũưừứựửữ]': 'u',
    '[ỳýỵỷỹ]': 'y',
    '[đ]': 'd',
  };

  replacements.forEach((pattern, value) {
    output = output.replaceAll(RegExp(pattern), value);
  });

  return output;
}

int? _matchScore(String query, Iterable<String> fields) {
  int? bestScore;
  for (final field in fields) {
    final normalized = _foldSearch(field);
    if (normalized.isEmpty) continue;

    final starts = normalized.startsWith(query);
    final contains = normalized.contains(query);
    if (!starts && !contains) continue;

    final score = starts ? 0 : 1;
    if (bestScore == null || score < bestScore) {
      bestScore = score;
    }
  }
  return bestScore;
}

String _friendlyFeedError(String raw) {
  final lower = raw.toLowerCase();

  if (lower.contains('bookmarks')) {
    return AppLocalizer.current.tr(
      'Saved items are still syncing right now. The rest of the feed is ready to use.',
    );
  }

  if (lower.contains('404')) {
    return AppLocalizer.current.tr(
      'One feed section is not available yet. Pull down to refresh in a moment.',
    );
  }

  if (lower.contains('401') || lower.contains('403')) {
    return AppLocalizer.current.tr(
      'Your session needs attention. Please sign in again.',
    );
  }

  if (lower.contains('timeout') || lower.contains('timed out')) {
    return AppLocalizer.current.tr(
      'The feed is taking longer than usual to load. Please try again shortly.',
    );
  }

  return AppLocalizer.current.tr(
    'A few sections could not be loaded right now. Pull down to try again.',
  );
}
