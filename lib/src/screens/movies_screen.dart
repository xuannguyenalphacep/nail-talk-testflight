import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/chat_controller.dart';
import '../controllers/social_hub_controller.dart';
import '../core/localization/app_localizer.dart';
import '../core/utils/app_date_utils.dart';
import '../core/utils/movie_showcase_utils.dart';
import '../models/app_option.dart';
import '../models/movie_item.dart';
import '../models/movie_plan_model.dart';
import '../widgets/language_switch_button.dart';
import '../widgets/metro_ui.dart';
import 'chat_home_screen.dart';
import 'movie_detail_screen.dart';

enum _MovieAccessFilter { all, ready, free, subscription }

enum _MovieBrowseSort { all, newest, topRated, popular }

class MoviesScreen extends StatefulWidget {
  const MoviesScreen({super.key});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final PageController _heroController = PageController();

  int _heroIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SocialHubController>().refreshMovies();
    });
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    _heroController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool _isUnlocked(MovieItem movie, bool hasActivePlan) {
    return movie.accessType == 'free' || movie.canWatch || hasActivePlan;
  }

  List<MovieItem> _filterMovies(List<MovieItem> movies) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return movies;

    return movies
        .where((movie) {
          final haystack = [
            movie.title,
            movie.summary,
            movie.thirdPartyProvider,
            movie.category?.name ?? '',
          ].join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  List<MovieItem> _sortMovies(List<MovieItem> movies, _MovieBrowseSort sort) {
    final next = List<MovieItem>.from(movies);
    next.sort((a, b) {
      final metaA = movieShowcaseMeta(a);
      final metaB = movieShowcaseMeta(b);

      return switch (sort) {
        _MovieBrowseSort.newest => metaB.year.compareTo(metaA.year),
        _MovieBrowseSort.topRated => metaB.rating.compareTo(metaA.rating),
        _MovieBrowseSort.popular => metaB.popularityScore.compareTo(
          metaA.popularityScore,
        ),
        _MovieBrowseSort.all => metaB.popularityScore.compareTo(
          metaA.popularityScore,
        ),
      };
    });
    return next;
  }

  Future<void> _refreshMovies() {
    return context.read<SocialHubController>().refreshMovies();
  }

  Future<void> _openMovie(MovieItem movie) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)));
  }

  Future<void> _openChatCenter() {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ChatHomeScreen()));
  }

  Future<void> _openBrowseScreen({
    required String title,
    required String subtitle,
    required List<MovieItem> library,
    _MovieAccessFilter accessFilter = _MovieAccessFilter.all,
    int? categoryId,
    _MovieBrowseSort initialSort = _MovieBrowseSort.all,
    String initialQuery = '',
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _MovieBrowseScreen(
          title: title,
          subtitle: subtitle,
          library: library,
          initialAccessFilter: accessFilter,
          initialCategoryId: categoryId,
          initialSort: initialSort,
          initialQuery: initialQuery,
        ),
      ),
    );
  }

  Future<void> _openCategoryHub(
    List<MovieItem> library,
    List<_MovieCategorySummary> categories,
  ) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _MovieCategoryHubScreen(
          library: library,
          categories: categories,
          onOpenBrowse: _openBrowseScreen,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SocialHubController>();
    final unreadCount = context.watch<ChatController>().visibleRooms.fold<int>(
      0,
      (total, room) => total + room.unreadCount,
    );
    final hasActivePlan = controller.activeSubscription?.isActive == true;
    final library = controller.movies
        .where((movie) => movie.isPublished)
        .toList(growable: false);
    final visibleMovies = _filterMovies(library);
    final readyMovies = visibleMovies
        .where((movie) => _isUnlocked(movie, hasActivePlan))
        .toList(growable: false);
    final freeMovies = visibleMovies
        .where((movie) => movie.accessType == 'free')
        .toList(growable: false);
    final trendingMovies = _sortMovies(visibleMovies, _MovieBrowseSort.popular);
    final newestMovies = _sortMovies(visibleMovies, _MovieBrowseSort.newest);
    final heroMovies = (visibleMovies.isNotEmpty ? visibleMovies : library)
        .take(4)
        .toList(growable: false);
    final highlightedPlan = controller.moviePlans.isNotEmpty
        ? controller.moviePlans.first
        : null;
    final categorySummaries = _buildMovieCategorySummaries(
      controller.movieCategories,
      visibleMovies.isNotEmpty ? visibleMovies : library,
      hasActivePlan,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MetroPageBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _refreshMovies,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
              children: [
                _TopScreenBar(
                  title: 'Movies',
                  unreadCount: unreadCount,
                  onNotifications: _openChatCenter,
                  onRefresh: controller.loadingMovies ? null : _refreshMovies,
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr('Quality movie picks, refreshed daily.'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: kMetroMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                _MovieSearchField(
                  controller: _searchController,
                  onSubmit: () {
                    final query = _searchController.text.trim();
                    if (query.isEmpty) return;
                    _openBrowseScreen(
                      title: 'Movie vault',
                      subtitle:
                          'Search across the movie vault and open a title right away.',
                      library: library,
                      initialQuery: query,
                    );
                  },
                ),
                const SizedBox(height: 18),
                if (controller.loadingMovies && library.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (heroMovies.isEmpty)
                  const SizedBox(
                    height: 220,
                    child: MetroEmptyState(
                      icon: Icons.movie_filter_outlined,
                      title: 'No titles match this setup',
                      message:
                          'Clear the category or access filters to reopen the full movie shelves.',
                      borderColor: Color(0xFF6D7A94),
                    ),
                  )
                else ...[
                  _MovieHeroCarousel(
                    controller: _heroController,
                    currentIndex: _heroIndex,
                    movies: heroMovies,
                    isUnlocked: (movie) => _isUnlocked(movie, hasActivePlan),
                    onPageChanged: (value) {
                      if (mounted) {
                        setState(() => _heroIndex = value);
                      }
                    },
                    onOpen: _openMovie,
                  ),
                  const SizedBox(height: 20),
                  _MovieCategoryGrid(
                    categories: categorySummaries,
                    onViewAll: () =>
                        _openCategoryHub(library, categorySummaries),
                    onOpenCategory: (summary) => _openBrowseScreen(
                      title: summary.title,
                      subtitle: summary.subtitle,
                      library: library,
                      accessFilter: summary.accessFilter,
                      categoryId: summary.categoryId,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (highlightedPlan != null ||
                      controller.activeSubscription != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: _MoviePlanPanel(
                        plan: highlightedPlan,
                        activeSubscription: controller.activeSubscription,
                      ),
                    ),
                  if (readyMovies.isNotEmpty)
                    _MoviePosterStripSection(
                      title: 'Ready to watch',
                      subtitle: 'Open now for this account.',
                      movies: readyMovies,
                      onOpen: _openMovie,
                      actionLabel: 'See all',
                      onAction: () => _openBrowseScreen(
                        title: 'Ready to watch',
                        subtitle: 'Open now for this account.',
                        library: library,
                        accessFilter: _MovieAccessFilter.ready,
                      ),
                    ),
                  if (readyMovies.isNotEmpty) const SizedBox(height: 18),
                  if (trendingMovies.isNotEmpty)
                    _MoviePosterStripSection(
                      title: 'Trending now',
                      subtitle:
                          'The most opened titles inside Nails Talk this week.',
                      movies: trendingMovies.take(8).toList(growable: false),
                      onOpen: _openMovie,
                      actionLabel: 'See all',
                      onAction: () => _openBrowseScreen(
                        title: 'Trending now',
                        subtitle:
                            'The most opened titles inside Nails Talk this week.',
                        library: library,
                        initialSort: _MovieBrowseSort.popular,
                      ),
                    ),
                  if (trendingMovies.isNotEmpty) const SizedBox(height: 18),
                  if (freeMovies.isNotEmpty)
                    _MoviePosterStripSection(
                      title: 'Free tonight',
                      subtitle: 'No plan needed for these picks.',
                      movies: freeMovies,
                      onOpen: _openMovie,
                      actionLabel: 'See all',
                      onAction: () => _openBrowseScreen(
                        title: 'Free tonight',
                        subtitle: 'No plan needed for these picks.',
                        library: library,
                        accessFilter: _MovieAccessFilter.free,
                      ),
                    ),
                  if (freeMovies.isNotEmpty) const SizedBox(height: 18),
                  if (newestMovies.isNotEmpty)
                    _MoviePosterStripSection(
                      title: 'Fresh releases',
                      subtitle: 'New posters and fresh streams for the week.',
                      movies: newestMovies.take(8).toList(growable: false),
                      onOpen: _openMovie,
                      actionLabel: 'See all',
                      onAction: () => _openBrowseScreen(
                        title: 'Fresh releases',
                        subtitle: 'New posters and fresh streams for the week.',
                        library: library,
                        initialSort: _MovieBrowseSort.newest,
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

class _TopScreenBar extends StatelessWidget {
  const _TopScreenBar({
    required this.title,
    required this.unreadCount,
    required this.onNotifications,
    required this.onRefresh,
  });

  final String title;
  final int unreadCount;
  final VoidCallback onNotifications;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            context.tr(title),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: kMetroInk,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const LanguageSwitchButton(compact: true),
        const SizedBox(width: 10),
        _TopBarButton(
          icon: Icons.notifications_none_rounded,
          badgeVisible: unreadCount > 0,
          onTap: onNotifications,
        ),
        const SizedBox(width: 10),
        _TopBarButton(
          icon: Icons.refresh_rounded,
          onTap: onRefresh == null ? null : () => onRefresh!(),
        ),
      ],
    );
  }
}

class _TopBarButton extends StatelessWidget {
  const _TopBarButton({
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

class _MovieSearchField extends StatelessWidget {
  const _MovieSearchField({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kMetroLine),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onSubmitted: (_) => onSubmit(),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: context.tr('Search movies, providers, or categories'),
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: IconButton(
            onPressed: onSubmit,
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 18,
          ),
        ),
      ),
    );
  }
}

class _MovieHeroCarousel extends StatelessWidget {
  const _MovieHeroCarousel({
    required this.controller,
    required this.currentIndex,
    required this.movies,
    required this.isUnlocked,
    required this.onPageChanged,
    required this.onOpen,
  });

  final PageController controller;
  final int currentIndex;
  final List<MovieItem> movies;
  final bool Function(MovieItem movie) isUnlocked;
  final ValueChanged<int> onPageChanged;
  final Future<void> Function(MovieItem movie) onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 344,
          child: PageView.builder(
            controller: controller,
            itemCount: movies.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final movie = movies[index];
              return _MovieHeroSlide(
                movie: movie,
                unlocked: isUnlocked(movie),
                onOpen: () => onOpen(movie),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(
            movies.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: index == currentIndex ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: index == currentIndex ? kMetroCoral : kMetroLine,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MovieHeroSlide extends StatelessWidget {
  const _MovieHeroSlide({
    required this.movie,
    required this.unlocked,
    required this.onOpen,
  });

  final MovieItem movie;
  final bool unlocked;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final meta = movieShowcaseMeta(movie);

    return MetroImageFrame(
      borderColor: kMetroCoral,
      imageUrl: movie.bannerUrl.isNotEmpty ? movie.bannerUrl : movie.posterUrl,
      onTap: onOpen,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      overlayTop: const Color(0x12000000),
      overlayBottom: const Color(0xE6111724),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MetroBadge(
            label: 'Featured movie',
            backgroundColor: kMetroCoral,
            foregroundColor: Colors.white,
            outlined: false,
          ),
          const Spacer(),
          Text(
            context.tr(movie.title),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontSize: 32,
              height: 1.05,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(movie.summary),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              FilledButton(
                onPressed: onOpen,
                style: FilledButton.styleFrom(
                  backgroundColor: kMetroCoral,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(context.tr('Watch now')),
              ),
              const SizedBox(width: 12),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const Spacer(),
              Text(
                '${meta.year} • ${movieDurationLabel(meta.durationMinutes)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                color: Color(0xFFFFD34D),
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                meta.rating.toStringAsFixed(1),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                context.tr(unlocked ? 'Ready to watch' : 'Subscription'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.84),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MovieCategoryGrid extends StatelessWidget {
  const _MovieCategoryGrid({
    required this.categories,
    required this.onViewAll,
    required this.onOpenCategory,
  });

  final List<_MovieCategorySummary> categories;
  final VoidCallback onViewAll;
  final ValueChanged<_MovieCategorySummary> onOpenCategory;

  @override
  Widget build(BuildContext context) {
    final visible = categories.take(8).toList(growable: false);
    const spacing = 12.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.tr('Popular categories'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: kMetroInk,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(
              onPressed: onViewAll,
              child: Text(context.tr('See all')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final tileWidth = (constraints.maxWidth - spacing) / 2;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final summary in visible)
                  SizedBox(
                    width: tileWidth,
                    child: _MovieCategoryTile(
                      summary: summary,
                      onTap: summary.opensHub
                          ? onViewAll
                          : () => onOpenCategory(summary),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MovieCategoryTile extends StatelessWidget {
  const _MovieCategoryTile({required this.summary, required this.onTap});

  final _MovieCategorySummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: kMetroLine),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: summary.tint.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(summary.icon, color: summary.tint, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.tr(summary.title),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: kMetroInk,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoviePosterStripSection extends StatelessWidget {
  const _MoviePosterStripSection({
    required this.title,
    required this.subtitle,
    required this.movies,
    required this.onOpen,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final List<MovieItem> movies;
  final Future<void> Function(MovieItem movie) onOpen;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(title),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: kMetroInk,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr(subtitle),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: kMetroMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(
                onPressed: onAction,
                child: Text(context.tr(actionLabel!)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: movies.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final movie = movies[index];
              return _MoviePosterCard(movie: movie, onTap: () => onOpen(movie));
            },
          ),
        ),
      ],
    );
  }
}

class _MoviePosterCard extends StatelessWidget {
  const _MoviePosterCard({required this.movie, required this.onTap});

  final MovieItem movie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = movieShowcaseMeta(movie);

    return SizedBox(
      width: 172,
      child: MetroImageFrame(
        borderColor: movieCategoryTint(movie.category?.name ?? ''),
        imageUrl: movie.posterUrl.isNotEmpty
            ? movie.posterUrl
            : movie.bannerUrl,
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        overlayTop: const Color(0x08000000),
        overlayBottom: const Color(0xE6101621),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (meta.isNew)
                  MetroBadge(
                    label: 'New',
                    backgroundColor: kMetroCoral,
                    foregroundColor: Colors.white,
                    outlined: false,
                  )
                else if (meta.isHd)
                  const MetroBadge(
                    label: 'HD',
                    backgroundColor: Color(0x19000000),
                    foregroundColor: Colors.white,
                    outlined: false,
                  ),
                const Spacer(),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: kMetroInk,
                    size: 22,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              context.tr(movie.title),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontSize: 18,
                height: 1.15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${meta.year} • ${movieDurationLabel(meta.durationMinutes)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.82),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFFFD34D),
                  size: 15,
                ),
                const SizedBox(width: 4),
                Text(
                  meta.rating.toStringAsFixed(1),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MoviePlanPanel extends StatelessWidget {
  const _MoviePlanPanel({required this.plan, required this.activeSubscription});

  final MoviePlanModel? plan;
  final MovieSubscriptionModel? activeSubscription;

  @override
  Widget build(BuildContext context) {
    final active = activeSubscription?.isActive == true;
    final label = active
        ? context.tr('Movie pass active until {date}', {
            'date': activeSubscription?.endsAt == null
                ? context.tr('soon')
                : AppDateUtils.formatDate(activeSubscription?.endsAt),
          })
        : plan == null
        ? context.tr('Subscription ready')
        : context.tr('{currency} {price} / {days} days', {
            'currency': plan!.currency,
            'price': plan!.price.toStringAsFixed(2),
            'days': '${plan!.durationDays}',
          });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF5F7), Color(0xFFFFFBFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFFFE1E8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: active ? kMetroCoralSoft : kMetroPrimarySoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              active
                  ? Icons.workspace_premium_rounded
                  : Icons.local_activity_rounded,
              color: active ? kMetroCoral : kMetroPrimary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: kMetroInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(
                    active
                        ? 'Premium shelves are unlocked for this account.'
                        : 'Unlock more titles and keep the movie rows open.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: kMetroMuted,
                    fontWeight: FontWeight.w700,
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

class _MovieBrowseScreen extends StatefulWidget {
  const _MovieBrowseScreen({
    required this.title,
    required this.subtitle,
    required this.library,
    required this.initialAccessFilter,
    required this.initialCategoryId,
    required this.initialSort,
    required this.initialQuery,
  });

  final String title;
  final String subtitle;
  final List<MovieItem> library;
  final _MovieAccessFilter initialAccessFilter;
  final int? initialCategoryId;
  final _MovieBrowseSort initialSort;
  final String initialQuery;

  @override
  State<_MovieBrowseScreen> createState() => _MovieBrowseScreenState();
}

class _MovieBrowseScreenState extends State<_MovieBrowseScreen> {
  late final TextEditingController _searchController;
  late _MovieBrowseSort _sort;
  late _MovieAccessFilter _accessFilter;
  int? _categoryId;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _sort = widget.initialSort;
    _accessFilter = widget.initialAccessFilter;
    _categoryId = widget.initialCategoryId;
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool _matchesAccess(MovieItem movie, bool hasActivePlan) {
    return switch (_accessFilter) {
      _MovieAccessFilter.all => true,
      _MovieAccessFilter.ready =>
        movie.accessType == 'free' || movie.canWatch || hasActivePlan,
      _MovieAccessFilter.free => movie.accessType == 'free',
      _MovieAccessFilter.subscription => movie.accessType != 'free',
    };
  }

  List<MovieItem> _visibleMovies(bool hasActivePlan) {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = widget.library.where((movie) {
      if (_categoryId != null && movie.category?.id != _categoryId) {
        return false;
      }
      if (!_matchesAccess(movie, hasActivePlan)) return false;
      if (query.isEmpty) return true;

      final haystack = [
        movie.title,
        movie.summary,
        movie.thirdPartyProvider,
        movie.category?.name ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();

    filtered.sort((a, b) {
      final metaA = movieShowcaseMeta(a);
      final metaB = movieShowcaseMeta(b);

      return switch (_sort) {
        _MovieBrowseSort.newest => metaB.year.compareTo(metaA.year),
        _MovieBrowseSort.topRated => metaB.rating.compareTo(metaA.rating),
        _MovieBrowseSort.popular => metaB.popularityScore.compareTo(
          metaA.popularityScore,
        ),
        _MovieBrowseSort.all => metaB.popularityScore.compareTo(
          metaA.popularityScore,
        ),
      };
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SocialHubController>();
    final hasActivePlan = controller.activeSubscription?.isActive == true;
    final movies = _visibleMovies(hasActivePlan);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MetroPageBackground(
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
            children: [
              Row(
                children: [
                  MetroActionButton(
                    icon: Icons.arrow_back_rounded,
                    label: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr(widget.title),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: kMetroInk,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.tr(widget.subtitle),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: kMetroMuted,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFECF2), Color(0xFFFFFAFC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x140F172A),
                          blurRadius: 18,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_circle_fill_rounded,
                      color: kMetroCoral,
                      size: 30,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _MovieSearchField(controller: _searchController, onSubmit: () {}),
              const SizedBox(height: 14),
              Wrap(
                children: [
                  _MovieBrowseChip(
                    label: 'All',
                    selected: _sort == _MovieBrowseSort.all,
                    onTap: () => setState(() => _sort = _MovieBrowseSort.all),
                  ),
                  _MovieBrowseChip(
                    label: 'Newest',
                    selected: _sort == _MovieBrowseSort.newest,
                    onTap: () =>
                        setState(() => _sort = _MovieBrowseSort.newest),
                  ),
                  _MovieBrowseChip(
                    label: 'Top rated',
                    selected: _sort == _MovieBrowseSort.topRated,
                    onTap: () =>
                        setState(() => _sort = _MovieBrowseSort.topRated),
                  ),
                  _MovieBrowseChip(
                    label: 'Most watched',
                    selected: _sort == _MovieBrowseSort.popular,
                    onTap: () =>
                        setState(() => _sort = _MovieBrowseSort.popular),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                children: [
                  _MovieBrowseChip(
                    label: 'All genres',
                    selected: _categoryId == null,
                    onTap: () => setState(() => _categoryId = null),
                    accentColor: const Color(0xFFF3F5FC),
                    activeTextColor: kMetroPrimary,
                  ),
                  for (final category in controller.movieCategories)
                    _MovieBrowseChip(
                      label: category.name,
                      selected: _categoryId == category.id,
                      onTap: () => setState(() => _categoryId = category.id),
                      accentColor: const Color(0xFFF3F5FC),
                      activeTextColor: kMetroPrimary,
                    ),
                ],
              ),
              const SizedBox(height: 18),
              if (movies.isEmpty)
                const SizedBox(
                  height: 240,
                  child: MetroEmptyState(
                    icon: Icons.movie_filter_outlined,
                    title: 'No titles match this setup',
                    message:
                        'Clear the category or access filters to reopen the full movie shelves.',
                    borderColor: Color(0xFF6D7A94),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: movies.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    mainAxisExtent: 288,
                  ),
                  itemBuilder: (context, index) {
                    final movie = movies[index];
                    return _MoviePosterCard(
                      movie: movie,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MovieDetailScreen(movie: movie),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovieBrowseChip extends StatelessWidget {
  const _MovieBrowseChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accentColor = kMetroCoral,
    this.activeTextColor = Colors.white,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accentColor;
  final Color activeTextColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? accentColor : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? accentColor : kMetroLine),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x10F36C84),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Text(
            context.tr(label),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: selected ? activeTextColor : kMetroInk,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _MovieCategoryHubScreen extends StatelessWidget {
  const _MovieCategoryHubScreen({
    required this.library,
    required this.categories,
    required this.onOpenBrowse,
  });

  final List<MovieItem> library;
  final List<_MovieCategorySummary> categories;
  final Future<void> Function({
    required String title,
    required String subtitle,
    required List<MovieItem> library,
    _MovieAccessFilter accessFilter,
    int? categoryId,
    _MovieBrowseSort initialSort,
    String initialQuery,
  })
  onOpenBrowse;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MetroPageBackground(
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
            children: [
              Row(
                children: [
                  MetroActionButton(
                    icon: Icons.arrow_back_rounded,
                    label: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr('Movie categories'),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: kMetroInk,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('Every shelf available for browsing in one place.'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: kMetroMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              ...categories
                  .where((summary) => !summary.opensHub)
                  .map(
                    (summary) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () => onOpenBrowse(
                          title: summary.title,
                          subtitle: summary.subtitle,
                          library: library,
                          accessFilter: summary.accessFilter,
                          categoryId: summary.categoryId,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: kMetroLine),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x120F172A),
                                blurRadius: 18,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: summary.tint.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Icon(
                                  summary.icon,
                                  color: summary.tint,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.tr(summary.title),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: kMetroInk,
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${summary.count} ${context.tr('Titles').toLowerCase()}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: kMetroMuted,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: kMetroMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovieCategorySummary {
  const _MovieCategorySummary({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.count,
    this.categoryId,
    this.accessFilter = _MovieAccessFilter.all,
    this.opensHub = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final int count;
  final int? categoryId;
  final _MovieAccessFilter accessFilter;
  final bool opensHub;
}

List<_MovieCategorySummary> _buildMovieCategorySummaries(
  List<AppOption> categories,
  List<MovieItem> library,
  bool hasActivePlan,
) {
  final summaries = <_MovieCategorySummary>[
    _MovieCategorySummary(
      title: 'Ready to watch',
      subtitle: 'Open now for this account.',
      icon: movieCategoryIcon('ready'),
      tint: movieCategoryTint('ready'),
      count: library
          .where(
            (movie) =>
                movie.accessType == 'free' || movie.canWatch || hasActivePlan,
          )
          .length,
      accessFilter: _MovieAccessFilter.ready,
    ),
  ];

  for (final category in categories) {
    final count = library
        .where((movie) => movie.category?.id == category.id)
        .length;
    if (count == 0) continue;
    summaries.add(
      _MovieCategorySummary(
        title: category.name,
        subtitle:
            'Swipe through posters by category and open a title in one tap.',
        icon: movieCategoryIcon(category.name),
        tint: movieCategoryTint(category.name),
        count: count,
        categoryId: category.id,
      ),
    );
  }

  summaries.add(
    _MovieCategorySummary(
      title: 'More',
      subtitle: 'View all categories',
      icon: Icons.more_horiz_rounded,
      tint: const Color(0xFF9EA5BC),
      count: library.length,
      opensHub: true,
    ),
  );

  return summaries;
}
