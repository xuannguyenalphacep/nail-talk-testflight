import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/social_hub_controller.dart';
import '../models/app_option.dart';
import '../models/movie_item.dart';
import '../models/movie_plan_model.dart';
import '../widgets/remote_image.dart';
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
    final search = _searchController.text.trim();
    return context.read<SocialHubController>().refreshMovies(
      search: search.isEmpty ? null : search,
    );
  }

  Future<void> _openMovie(MovieItem movie) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)));
  }

  List<MovieItem> _filterMovies(
    List<MovieItem> movies,
    bool hasActivePlan,
  ) {
    final query = _searchController.text.trim().toLowerCase();

    return movies.where((movie) {
      if (!movie.isPublished) return false;

      if (_selectedCategoryId != null && movie.category?.id != _selectedCategoryId) {
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
    List<AppOption> categories,
    bool hasActivePlan,
  ) {
    final shelves = <_MovieShelfData>[];
    final readyMovies = movies
        .where((movie) => _isUnlocked(movie, hasActivePlan))
        .toList();
    final freeMovies = movies.where((movie) => movie.accessType == 'free').toList();
    final premiumMovies = movies
        .where((movie) => movie.accessType != 'free')
        .toList();

    if (movies.isNotEmpty) {
      shelves.add(
        _MovieShelfData(
          title: 'Popular on Nail Talk',
          description: 'Top picks laid out like a real streaming browse page.',
          movies: movies.take(12).toList(),
        ),
      );
    }

    if (readyMovies.isNotEmpty) {
      shelves.add(
        _MovieShelfData(
          title: 'Ready to watch',
          description: 'Open these instantly with the current account.',
          movies: readyMovies.take(12).toList(),
        ),
      );
    }

    if (freeMovies.isNotEmpty) {
      shelves.add(
        _MovieShelfData(
          title: 'Free movie arrivals',
          description: 'No monthly pass needed here.',
          movies: freeMovies.take(12).toList(),
        ),
      );
    }

    if (premiumMovies.isNotEmpty) {
      shelves.add(
        _MovieShelfData(
          title: 'Premium shelf',
          description: 'Subscription-only films in the same compact poster layout.',
          movies: premiumMovies.take(12).toList(),
        ),
      );
    }

    for (final category in categories) {
      final categoryMovies = movies
          .where((movie) => movie.category?.id == category.id)
          .toList();
      if (categoryMovies.isEmpty) continue;

      shelves.add(
        _MovieShelfData(
          title: category.name,
          description: 'Browse ${category.name.toLowerCase()} in poster rows.',
          movies: categoryMovies,
        ),
      );
    }

    return shelves;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SocialHubController>();
    final hasActivePlan = controller.activeSubscription?.isActive == true;
    final library = controller.movies.where((movie) => movie.isPublished).toList();
    final visibleMovies = _filterMovies(library, hasActivePlan);
    final featuredMovie = (visibleMovies.isNotEmpty ? visibleMovies : library).isNotEmpty
        ? (visibleMovies.isNotEmpty ? visibleMovies : library).first
        : null;
    final hasFocusedFilter =
        _selectedCategoryId != null ||
        _accessFilter != _MovieAccessFilter.all ||
        _searchController.text.trim().isNotEmpty;
    final shelves = hasFocusedFilter
        ? <_MovieShelfData>[
            _MovieShelfData(
              title: 'Matching results',
              description: 'Filtered posters shown in the same movie-app style.',
              movies: visibleMovies,
            ),
          ]
        : _buildShelves(visibleMovies, controller.movieCategories, hasActivePlan);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFFF4F7FC),
        titleSpacing: 16,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Movies',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 24,
                color: Color(0xFF132642),
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Keep the bright app background, but browse inside a cinema-style layout.',
              style: TextStyle(
                color: Color(0xFF6B7E97),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: controller.loadingMovies ? null : _refreshMovies,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshMovies,
        child: ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0B0F16), Color(0xFF111725)],
                ),
                borderRadius: BorderRadius.circular(32),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F102040),
                    blurRadius: 28,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CinemaTopBar(
                      totalMovies: visibleMovies.length,
                      activeCategory: controller.movieCategories
                          .cast<AppOption?>()
                          .firstWhere(
                            (category) => category?.id == _selectedCategoryId,
                            orElse: () => null,
                          )
                          ?.name,
                    ),
                    const SizedBox(height: 16),
                    _MovieSearchField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _refreshMovies(),
                      onClearPressed: () {
                        _searchController.clear();
                        setState(() {});
                        _refreshMovies();
                      },
                      onSearchPressed: _refreshMovies,
                    ),
                    const SizedBox(height: 16),
                    _CinemaAccessFilters(
                      accessFilter: _accessFilter,
                      onChanged: (value) => setState(() => _accessFilter = value),
                    ),
                    const SizedBox(height: 16),
                    _CinemaCategoryFilters(
                      selectedCategoryId: _selectedCategoryId,
                      categories: controller.movieCategories,
                      onSelected: (value) =>
                          setState(() => _selectedCategoryId = value),
                    ),
                    if (featuredMovie != null) ...[
                      const SizedBox(height: 18),
                      _FeaturedMovieBanner(
                        movie: featuredMovie,
                        unlocked: _isUnlocked(featuredMovie, hasActivePlan),
                        onTap: () => _openMovie(featuredMovie),
                      ),
                    ],
                    if (controller.moviePlans.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _CompactPlanBanner(
                        plans: controller.moviePlans,
                        activeSubscription: controller.activeSubscription,
                        busy: controller.submitting,
                        onSubscribe: (planId) =>
                            controller.subscribeToMoviePlan(planId),
                      ),
                    ],
                    const SizedBox(height: 22),
                    if (controller.loadingMovies && library.isEmpty)
                      const _MovieLoadingState()
                    else if (visibleMovies.isEmpty)
                      _MovieEmptyState(
                        hasFilters: hasFocusedFilter,
                        onReset: () {
                          _searchController.clear();
                          setState(() {
                            _selectedCategoryId = null;
                            _accessFilter = _MovieAccessFilter.all;
                          });
                          _refreshMovies();
                        },
                      )
                    else if (hasFocusedFilter)
                      _FilteredMovieRail(
                        shelf: shelves.first,
                        hasActivePlan: hasActivePlan,
                        onTapMovie: _openMovie,
                      )
                    else
                      ...shelves.map(
                        (shelf) => Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: _MovieShelfSection(
                            shelf: shelf,
                            hasActivePlan: hasActivePlan,
                            onTapMovie: _openMovie,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CinemaTopBar extends StatelessWidget {
  const _CinemaTopBar({required this.totalMovies, required this.activeCategory});

  final int totalMovies;
  final String? activeCategory;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cinema Browse',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                activeCategory == null
                    ? '$totalMovies titles arranged in poster shelves.'
                    : '$totalMovies titles in $activeCategory.',
                style: const TextStyle(
                  color: Color(0xFF8B97AD),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.grid_view_rounded,
                size: 16,
                color: Color(0xFF6AB7FF),
              ),
              const SizedBox(width: 8),
              Text(
                '$totalMovies titles',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MovieSearchField extends StatelessWidget {
  const _MovieSearchField({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClearPressed,
    required this.onSearchPressed,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClearPressed;
  final VoidCallback onSearchPressed;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Search movies, providers, or moods',
        hintStyle: const TextStyle(color: Color(0xFF7E89A1)),
        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF97A7C0)),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.text.trim().isNotEmpty)
              IconButton(
                onPressed: onClearPressed,
                icon: const Icon(Icons.close_rounded, color: Color(0xFF97A7C0)),
              ),
            IconButton(
              onPressed: onSearchPressed,
              icon: const Icon(Icons.tune_rounded, color: Color(0xFF97A7C0)),
            ),
          ],
        ),
        filled: true,
        fillColor: const Color(0xFF161D2C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF1E2738)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF4A97FF), width: 1.5),
        ),
      ),
    );
  }
}

class _CinemaAccessFilters extends StatelessWidget {
  const _CinemaAccessFilters({
    required this.accessFilter,
    required this.onChanged,
  });

  final _MovieAccessFilter accessFilter;
  final ValueChanged<_MovieAccessFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Browse mode',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _CinemaPillChip(
                label: 'All',
                selected: accessFilter == _MovieAccessFilter.all,
                onTap: () => onChanged(_MovieAccessFilter.all),
              ),
              const SizedBox(width: 10),
              _CinemaPillChip(
                label: 'Ready',
                selected: accessFilter == _MovieAccessFilter.ready,
                onTap: () => onChanged(_MovieAccessFilter.ready),
              ),
              const SizedBox(width: 10),
              _CinemaPillChip(
                label: 'Free',
                selected: accessFilter == _MovieAccessFilter.free,
                onTap: () => onChanged(_MovieAccessFilter.free),
              ),
              const SizedBox(width: 10),
              _CinemaPillChip(
                label: 'Subscription',
                selected: accessFilter == _MovieAccessFilter.subscription,
                onTap: () => onChanged(_MovieAccessFilter.subscription),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CinemaCategoryFilters extends StatelessWidget {
  const _CinemaCategoryFilters({
    required this.selectedCategoryId,
    required this.categories,
    required this.onSelected,
  });

  final int? selectedCategoryId;
  final List<AppOption> categories;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Categories',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _CinemaPillChip(
                label: 'All genres',
                selected: selectedCategoryId == null,
                onTap: () => onSelected(null),
              ),
              for (final category in categories) ...[
                const SizedBox(width: 10),
                _CinemaPillChip(
                  label: category.name,
                  selected: selectedCategoryId == category.id,
                  onTap: () => onSelected(category.id),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CinemaPillChip extends StatelessWidget {
  const _CinemaPillChip({
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
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2F7DF4) : const Color(0xFF171E2D),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF63AEFF) : const Color(0xFF262E40),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFFB8C4D9),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _FeaturedMovieBanner extends StatelessWidget {
  const _FeaturedMovieBanner({
    required this.movie,
    required this.unlocked,
    required this.onTap,
  });

  final MovieItem movie;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = movie.bannerUrl.isNotEmpty ? movie.bannerUrl : movie.posterUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Featured movie',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: const Color(0xFF151C2B),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: Stack(
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: imageUrl.isNotEmpty
                              ? RemoteImage(url: imageUrl, fit: BoxFit.cover)
                              : Container(
                                  color: const Color(0xFF23314D),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.movie_creation_rounded,
                                    color: Colors.white,
                                    size: 42,
                                  ),
                                ),
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.10),
                                  Colors.black.withValues(alpha: 0.78),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 14,
                          top: 14,
                          child: _OverlayMovieBadge(
                            label: movie.category?.name.isNotEmpty == true
                                ? movie.category!.name
                                : 'Movie',
                          ),
                        ),
                        Positioned(
                          right: 14,
                          top: 14,
                          child: _OverlayMovieBadge(
                            label: unlocked ? 'Ready' : 'Plan',
                          ),
                        ),
                        Positioned(
                          left: 14,
                          right: 14,
                          bottom: 14,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                movie.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 24,
                                  height: 1.02,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                movie.summary,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFD5DAE6),
                                  height: 1.35,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            movie.thirdPartyProvider.isEmpty
                                ? 'Community stream'
                                : movie.thirdPartyProvider,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF8EA1BF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: onTap,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2F7DF4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: Icon(
                            unlocked
                                ? Icons.play_arrow_rounded
                                : Icons.info_outline_rounded,
                          ),
                          label: Text(unlocked ? 'Watch' : 'Details'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactPlanBanner extends StatelessWidget {
  const _CompactPlanBanner({
    required this.plans,
    required this.activeSubscription,
    required this.busy,
    required this.onSubscribe,
  });

  final List<MoviePlanModel> plans;
  final MovieSubscriptionModel? activeSubscription;
  final bool busy;
  final ValueChanged<int> onSubscribe;

  @override
  Widget build(BuildContext context) {
    final active = activeSubscription?.isActive == true;
    final plan = plans.first;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2240), Color(0xFF273A62)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active
                      ? 'Movie pass active until ${_formatDate(activeSubscription?.endsAt)}'
                      : '${plan.name} • ${plan.currency} ${plan.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  active
                      ? 'Premium shelves are unlocked for this account.'
                      : plan.description.isNotEmpty
                          ? plan.description
                          : 'Unlock more titles and keep the movie rows open.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFC6D0E2),
                    height: 1.35,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: busy || active ? null : () => onSubscribe(plan.id),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1D3661),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(active ? 'Active' : 'Unlock'),
          ),
        ],
      ),
    );
  }
}

class _MovieShelfSection extends StatelessWidget {
  const _MovieShelfSection({
    required this.shelf,
    required this.hasActivePlan,
    required this.onTapMovie,
  });

  final _MovieShelfData shelf;
  final bool hasActivePlan;
  final ValueChanged<MovieItem> onTapMovie;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          shelf.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          shelf.description,
          style: const TextStyle(
            color: Color(0xFF8B97AD),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 214,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: shelf.movies.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final movie = shelf.movies[index];
              return _MoviePosterCard(
                movie: movie,
                unlocked:
                    movie.accessType == 'free' || movie.canWatch || hasActivePlan,
                onTap: () => onTapMovie(movie),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilteredMovieRail extends StatelessWidget {
  const _FilteredMovieRail({
    required this.shelf,
    required this.hasActivePlan,
    required this.onTapMovie,
  });

  final _MovieShelfData shelf;
  final bool hasActivePlan;
  final ValueChanged<MovieItem> onTapMovie;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          shelf.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          shelf.description,
          style: const TextStyle(
            color: Color(0xFF8B97AD),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 214,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: shelf.movies.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final movie = shelf.movies[index];
              return _MoviePosterCard(
                movie: movie,
                unlocked:
                    movie.accessType == 'free' || movie.canWatch || hasActivePlan,
                onTap: () => onTapMovie(movie),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MoviePosterCard extends StatelessWidget {
  const _MoviePosterCard({
    required this.movie,
    required this.unlocked,
    required this.onTap,
  });

  final MovieItem movie;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final posterUrl = movie.posterUrl.isNotEmpty ? movie.posterUrl : movie.bannerUrl;

    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 142,
        height: 204,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              decoration: BoxDecoration(
                color: const Color(0xFF101724),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        AspectRatio(
                          aspectRatio: 1,
                          child: posterUrl.isNotEmpty
                              ? RemoteImage(url: posterUrl, fit: BoxFit.cover)
                              : Container(
                                  color: const Color(0xFF24304A),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.movie_creation_outlined,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.12),
                                  Colors.black.withValues(alpha: 0.48),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: _TinyPosterBadge(
                            label: movie.category?.name.isNotEmpty == true
                                ? movie.category!.name
                                : 'Movie',
                          ),
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Icon(
                            unlocked
                                ? Icons.play_circle_fill_rounded
                                : Icons.workspace_premium_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      movie.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      movie.thirdPartyProvider.isEmpty
                          ? (unlocked ? 'Ready to watch' : 'Plan required')
                          : movie.thirdPartyProvider,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8B97AD),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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

class _OverlayMovieBadge extends StatelessWidget {
  const _OverlayMovieBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _TinyPosterBadge extends StatelessWidget {
  const _TinyPosterBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 70),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _MovieLoadingState extends StatelessWidget {
  const _MovieLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        3,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 160,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2435),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: List.generate(
                  3,
                  (posterIndex) => Padding(
                    padding: EdgeInsets.only(right: posterIndex == 2 ? 0 : 12),
                    child: Container(
                      width: 142,
                      height: 182,
                      decoration: BoxDecoration(
                        color: const Color(0xFF151D2C),
                        borderRadius: BorderRadius.circular(16),
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

class _MovieEmptyState extends StatelessWidget {
  const _MovieEmptyState({required this.hasFilters, required this.onReset});

  final bool hasFilters;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF121826),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF232C3F)),
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: const Color(0xFF1A2234),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.movie_filter_outlined,
              size: 30,
              color: Color(0xFF78B1FF),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No titles match this setup',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilters
                ? 'Clear the category or access filters to reopen the full movie shelves.'
                : 'Pull to refresh and sync the latest movie list from the live API.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF8B97AD),
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Reset filters'),
            ),
          ],
        ],
      ),
    );
  }
}

class _MovieShelfData {
  const _MovieShelfData({
    required this.title,
    required this.description,
    required this.movies,
  });

  final String title;
  final String description;
  final List<MovieItem> movies;
}

String _formatDate(DateTime? value) {
  if (value == null) return 'soon';
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}/$month/$day';
}
