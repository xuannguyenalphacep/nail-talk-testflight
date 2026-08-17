import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/social_hub_controller.dart';
import '../core/localization/app_localizer.dart';
import '../core/utils/app_date_utils.dart';
import '../models/app_option.dart';
import '../models/movie_item.dart';
import '../models/movie_plan_model.dart';
import '../widgets/metro_ui.dart';
import 'movie_detail_screen.dart';

enum _MovieAccessFilter { all, ready, free, subscription }

class MoviesScreen extends StatefulWidget {
  const MoviesScreen({super.key});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  final TextEditingController _searchController = TextEditingController();

  int? _selectedCategoryId;
  _MovieAccessFilter _accessFilter = _MovieAccessFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SocialHubController>().refreshMovies();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isUnlocked(MovieItem movie, bool hasActivePlan) {
    return movie.accessType == 'free' || movie.canWatch || hasActivePlan;
  }

  Future<void> _refreshMovies() {
    final query = _searchController.text.trim();
    return context.read<SocialHubController>().refreshMovies(
      categoryId: _selectedCategoryId,
      search: query.isEmpty ? null : query,
    );
  }

  Future<void> _openMovie(MovieItem movie) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)));
  }

  List<MovieItem> _filterMovies(List<MovieItem> movies, bool hasActivePlan) {
    final query = _searchController.text.trim().toLowerCase();

    return movies.where((movie) {
      if (!movie.isPublished) return false;

      if (_selectedCategoryId != null &&
          movie.category?.id != _selectedCategoryId) {
        return false;
      }

      switch (_accessFilter) {
        case _MovieAccessFilter.all:
          break;
        case _MovieAccessFilter.ready:
          if (!_isUnlocked(movie, hasActivePlan)) return false;
          break;
        case _MovieAccessFilter.free:
          if (movie.accessType != 'free') return false;
          break;
        case _MovieAccessFilter.subscription:
          if (movie.accessType == 'free') return false;
          break;
      }

      if (query.isEmpty) return true;

      final haystack = [
        movie.title,
        movie.summary,
        movie.thirdPartyProvider,
        movie.category?.name ?? '',
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList();
  }

  List<_MovieShelfData> _buildShelves(
    List<MovieItem> movies,
    bool hasActivePlan,
  ) {
    final shelves = <_MovieShelfData>[];
    final readyMovies = movies
        .where((movie) => _isUnlocked(movie, hasActivePlan))
        .toList(growable: false);
    final lockedMovies = movies
        .where((movie) => !_isUnlocked(movie, hasActivePlan))
        .toList(growable: false);

    if (readyMovies.isNotEmpty) {
      shelves.add(
        _MovieShelfData(
          title: 'Ready to watch',
          subtitle: 'Open now for this account.',
          accentColor: kMetroSuccess,
          movies: readyMovies,
        ),
      );
    }

    if (lockedMovies.isNotEmpty) {
      shelves.add(
        _MovieShelfData(
          title: 'Subscription picks',
          subtitle: 'Unlock these with the monthly movie pass.',
          accentColor: kMetroGold,
          movies: lockedMovies,
        ),
      );
    }

    final grouped = <String, List<MovieItem>>{};
    for (final movie in movies) {
      final rawName = movie.category?.name.trim() ?? '';
      final key = rawName.isEmpty ? 'All titles' : rawName;
      grouped.putIfAbsent(key, () => <MovieItem>[]).add(movie);
    }

    final colors = <Color>[
      kMetroCoral,
      kMetroPrimary,
      kMetroRose,
      kMetroSuccess,
      const Color(0xFFC18E68),
      const Color(0xFF9099C8),
    ];

    var colorIndex = 0;
    for (final entry in grouped.entries) {
      shelves.add(
        _MovieShelfData(
          title: entry.key,
          subtitle:
              'Swipe through posters by category and open a title in one tap.',
          accentColor: colors[colorIndex % colors.length],
          movies: entry.value,
        ),
      );
      colorIndex++;
    }

    return shelves;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SocialHubController>();
    final hasActivePlan = controller.activeSubscription?.isActive == true;
    final library = controller.movies
        .where((movie) => movie.isPublished)
        .toList(growable: false);
    final visibleMovies = _filterMovies(library, hasActivePlan);
    final featuredMovie =
        (visibleMovies.isNotEmpty ? visibleMovies : library).isNotEmpty
        ? (visibleMovies.isNotEmpty ? visibleMovies : library).first
        : null;
    final highlightedPlan = controller.moviePlans.isNotEmpty
        ? controller.moviePlans.first
        : null;
    final shelves = _buildShelves(visibleMovies, hasActivePlan);
    final hasManualFilters =
        _selectedCategoryId != null ||
        _accessFilter != _MovieAccessFilter.all ||
        _searchController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Text(context.tr('Movies')),
        actions: [
          MetroActionButton(
            icon: Icons.refresh_rounded,
            label: 'Refresh',
            onPressed: controller.loadingMovies ? null : _refreshMovies,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: MetroPageBackground(
        child: RefreshIndicator(
          onRefresh: _refreshMovies,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              MetroSectionHeader(
                title: 'Popular on Nails Talk',
                subtitle:
                    'Top picks laid out like a real streaming browse page.',
                actionLabel: hasManualFilters ? 'Reset filters' : null,
                onAction: !hasManualFilters
                    ? null
                    : () {
                        _searchController.clear();
                        setState(() {
                          _selectedCategoryId = null;
                          _accessFilter = _MovieAccessFilter.all;
                        });
                        _refreshMovies();
                      },
              ),
              const SizedBox(height: 12),
              _MovieFiltersPanel(
                searchController: _searchController,
                accessFilter: _accessFilter,
                selectedCategoryId: _selectedCategoryId,
                categories: controller.movieCategories,
                loading: controller.loadingMovies,
                onRefresh: _refreshMovies,
                onAccessChanged: (value) {
                  setState(() => _accessFilter = value);
                },
                onCategoryChanged: (value) {
                  setState(() => _selectedCategoryId = value);
                  _refreshMovies();
                },
              ),
              const SizedBox(height: 14),
              if (highlightedPlan != null ||
                  controller.activeSubscription != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _MoviePlanPanel(
                    plan: highlightedPlan,
                    activeSubscription: controller.activeSubscription,
                  ),
                ),
              if (featuredMovie != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: _MovieHeroBanner(
                    movie: featuredMovie,
                    unlocked: _isUnlocked(featuredMovie, hasActivePlan),
                    onOpen: () => _openMovie(featuredMovie),
                    onBrowse: _refreshMovies,
                  ),
                ),
              if (controller.loadingMovies && library.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (visibleMovies.isEmpty)
                const SizedBox(
                  height: 210,
                  child: MetroEmptyState(
                    icon: Icons.movie_filter_outlined,
                    title: 'No titles match this setup',
                    message:
                        'Clear the category or access filters to reopen the full movie shelves.',
                    borderColor: Color(0xFF6D7A94),
                  ),
                )
              else ...[
                MetroSectionHeader(
                  title: 'Movie rows',
                  subtitle:
                      'Swipe through posters by category and open a title in one tap.',
                ),
                const SizedBox(height: 12),
                for (final shelf in shelves) ...[
                  _MovieShelfSection(
                    shelf: shelf,
                    isUnlocked: (movie) => _isUnlocked(movie, hasActivePlan),
                    onOpen: _openMovie,
                  ),
                  const SizedBox(height: 18),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MovieFiltersPanel extends StatelessWidget {
  const _MovieFiltersPanel({
    required this.searchController,
    required this.accessFilter,
    required this.selectedCategoryId,
    required this.categories,
    required this.loading,
    required this.onRefresh,
    required this.onAccessChanged,
    required this.onCategoryChanged,
  });

  final TextEditingController searchController;
  final _MovieAccessFilter accessFilter;
  final int? selectedCategoryId;
  final List<AppOption> categories;
  final bool loading;
  final Future<void> Function() onRefresh;
  final ValueChanged<_MovieAccessFilter> onAccessChanged;
  final ValueChanged<int?> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return MetroInsetPanel(
      borderColor: const Color(0xFF6C7B97),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: context.tr('Search movies, providers, or categories'),
              suffixIcon: IconButton(
                onPressed: loading ? null : onRefresh,
                icon: const Icon(Icons.search_rounded),
              ),
            ),
            onSubmitted: (_) => onRefresh(),
          ),
          const SizedBox(height: 14),
          _MovieFilterRail(
            label: 'Quick filters',
            children: [
              _MovieFilterChipButton(
                label: 'All',
                selected: accessFilter == _MovieAccessFilter.all,
                onTap: () => onAccessChanged(_MovieAccessFilter.all),
              ),
              _MovieFilterChipButton(
                label: 'Ready to watch',
                selected: accessFilter == _MovieAccessFilter.ready,
                onTap: () => onAccessChanged(_MovieAccessFilter.ready),
              ),
              _MovieFilterChipButton(
                label: 'Free',
                selected: accessFilter == _MovieAccessFilter.free,
                onTap: () => onAccessChanged(_MovieAccessFilter.free),
              ),
              _MovieFilterChipButton(
                label: 'Subscription',
                selected: accessFilter == _MovieAccessFilter.subscription,
                onTap: () => onAccessChanged(_MovieAccessFilter.subscription),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _MovieFilterRail(
            label: 'Categories',
            children: [
              _MovieFilterChipButton(
                label: 'All genres',
                selected: selectedCategoryId == null,
                onTap: () => onCategoryChanged(null),
              ),
              for (final category in categories)
                _MovieFilterChipButton(
                  label: category.name,
                  selected: selectedCategoryId == category.id,
                  onTap: () => onCategoryChanged(category.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MovieFilterRail extends StatelessWidget {
  const _MovieFilterRail({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(label),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: kMetroInk),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }
}

class _MovieFilterChipButton extends StatelessWidget {
  const _MovieFilterChipButton({
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

class _MovieHeroBanner extends StatelessWidget {
  const _MovieHeroBanner({
    required this.movie,
    required this.unlocked,
    required this.onOpen,
    required this.onBrowse,
  });

  final MovieItem movie;
  final bool unlocked;
  final VoidCallback onOpen;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 256,
      child: MetroImageFrame(
        borderColor: kMetroCoral,
        imageUrl: movie.bannerUrl.isNotEmpty
            ? movie.bannerUrl
            : movie.posterUrl,
        overlayTop: const Color(0x12000000),
        overlayBottom: const Color(0xDB111724),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const MetroBadge(label: 'Featured movie'),
                const Spacer(),
                MetroBadge(
                  label: unlocked ? 'Ready to watch' : 'Subscription',
                  backgroundColor: unlocked
                      ? const Color(0xFFE8F5EE)
                      : const Color(0xFFFFF3E3),
                ),
              ],
            ),
            const Spacer(),
            Text(
              context.tr(movie.title),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontSize: 30,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(movie.summary),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.94),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onOpen,
                    child: Text(context.tr(unlocked ? 'Watch' : 'Details')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onBrowse,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                    ),
                    child: Text(context.tr('See library')),
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

class _MovieShelfSection extends StatelessWidget {
  const _MovieShelfSection({
    required this.shelf,
    required this.isUnlocked,
    required this.onOpen,
  });

  final _MovieShelfData shelf;
  final bool Function(MovieItem movie) isUnlocked;
  final Future<void> Function(MovieItem movie) onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MetroSectionHeader(title: shelf.title, subtitle: shelf.subtitle),
        const SizedBox(height: 10),
        SizedBox(
          height: 226,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: shelf.movies.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final movie = shelf.movies[index];
              return _MovieRailCard(
                movie: movie,
                accentColor: shelf.accentColor,
                unlocked: isUnlocked(movie),
                onTap: () => onOpen(movie),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MovieRailCard extends StatelessWidget {
  const _MovieRailCard({
    required this.movie,
    required this.accentColor,
    required this.unlocked,
    required this.onTap,
  });

  final MovieItem movie;
  final Color accentColor;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 164,
      child: MetroImageFrame(
        borderColor: accentColor,
        imageUrl: movie.posterUrl.isNotEmpty
            ? movie.posterUrl
            : movie.bannerUrl,
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        overlayTop: const Color(0x0A000000),
        overlayBottom: const Color(0xE1121822),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MetroBadge(
              label: unlocked ? 'Ready to watch' : 'Subscription',
              backgroundColor: unlocked
                  ? const Color(0xFFE8F5EE)
                  : const Color(0xFFFFF3E3),
            ),
            const Spacer(),
            if (movie.category?.name.trim().isNotEmpty == true) ...[
              MetroBadge(
                label: movie.category!.name,
                backgroundColor: Colors.white.withValues(alpha: 0.88),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              context.tr(movie.title),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              movie.thirdPartyProvider.trim().isEmpty
                  ? context.tr('Community stream')
                  : context.tr(movie.thirdPartyProvider),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: unlocked
                    ? accentColor.withValues(alpha: 0.94)
                    : Colors.white.withValues(alpha: 0.12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    unlocked
                        ? Icons.play_circle_fill_rounded
                        : Icons.info_outline_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.tr(unlocked ? 'Watch' : 'Details'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
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

    return MetroInsetPanel(
      borderColor: active ? kMetroCoral : const Color(0xFF8C93A8),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: active ? kMetroCoralSoft : kMetroPrimarySoft,
              borderRadius: BorderRadius.circular(kMetroRadius),
              border: Border.all(color: kMetroLine),
            ),
            child: Icon(
              active
                  ? Icons.workspace_premium_rounded
                  : Icons.subscriptions_outlined,
              color: kMetroInk,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: kMetroInk),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(
                    active
                        ? 'Premium shelves are unlocked for this account.'
                        : 'Unlock more titles and keep the movie rows open.',
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: kMetroMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MovieShelfData {
  const _MovieShelfData({
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.movies,
  });

  final String title;
  final String subtitle;
  final Color accentColor;
  final List<MovieItem> movies;
}
