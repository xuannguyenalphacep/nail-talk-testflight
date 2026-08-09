import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/session_controller.dart';
import '../controllers/social_hub_controller.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/app_date_utils.dart';
import '../models/job_listing_item.dart';
import '../models/marketplace_item.dart';
import '../models/movie_item.dart';
import '../models/movie_plan_model.dart';
import '../models/property_listing_item.dart';
import '../models/saved_item.dart';
import '../models/session_user.dart';
import '../models/user_profile_model.dart';
import 'movie_detail_screen.dart';
import '../widgets/app_logo.dart';
import '../widgets/remote_image.dart';

const _hubBlue = Color(0xFF1B74E4);
const _hubInk = Color(0xFF16263C);
const _hubMuted = Color(0xFF6F8096);
const _hubLine = Color(0xFFE4EBF5);
const _hubSoftBlue = Color(0xFFEAF2FF);
const _hubSoftTeal = Color(0xFFE7F7F2);
const _hubSoftGold = Color(0xFFFFF3DD);
const _hubSoftSlate = Color(0xFFF5F8FE);

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({required this.onNavigate, super.key});

  final ValueChanged<int> onNavigate;

  Future<void> _refreshFeed(SocialHubController social) {
    return Future.wait([
      social.refreshHome(),
      social.refreshMovies(),
      social.refreshMarketplace(),
      social.refreshJobs(),
      social.refreshProperties(),
    ]);
  }

  Future<void> _openFeaturedMovie(BuildContext context, MovieItem movie) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)));
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final social = context.watch<SocialHubController>();
    final summary = social.profile?.summary;
    final featuredMovie = social.movies.isNotEmpty ? social.movies.first : null;
    final moviePlan = social.moviePlans.isNotEmpty
        ? social.moviePlans.first
        : null;
    final jobs = social.jobItems.take(3).toList(growable: false);
    final marketItems = social.marketplaceItems.take(4).toList(growable: false);
    final properties = social.propertyItems.take(4).toList(growable: false);
    final savedItems = social.bookmarks.take(4).toList(growable: false);
    final feedBusy =
        social.loadingHome ||
        social.loadingMovies ||
        social.loadingMarketplace ||
        social.loadingJobs ||
        social.loadingProperties;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        titleSpacing: 18,
        title: Row(
          children: [
            const AppLogo(size: 24, showWordmark: false),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppConstants.appName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    AppConstants.appTagline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _hubMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          _TopActionButton(
            tooltip: 'Chat',
            icon: Icons.chat_bubble_outline_rounded,
            onPressed: () => onNavigate(4),
          ),
          _TopActionButton(
            tooltip: 'Refresh',
            icon: Icons.refresh_rounded,
            onPressed: feedBusy ? null : () => _refreshFeed(social),
          ),
          _TopActionButton(
            tooltip: 'Logout',
            icon: Icons.logout_rounded,
            onPressed: () => session.logout(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF9FBFF), Color(0xFFF3F6FB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: RefreshIndicator(
          onRefresh: () => _refreshFeed(social),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 34),
            children: [
              if (feedBusy) ...[
                const LinearProgressIndicator(
                  minHeight: 3,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                const SizedBox(height: 14),
              ],
              _WelcomeCard(
                user: session.user,
                summary: summary,
                movieCount: social.movies.length,
                onNavigate: onNavigate,
              ),
              const SizedBox(height: 16),
              _MovieSpotlightCard(
                movie: featuredMovie,
                plan: moviePlan,
                activeSubscription: social.activeSubscription,
                onExplore: () => onNavigate(1),
                onWatch: featuredMovie == null
                    ? null
                    : () => _openFeaturedMovie(context, featuredMovie),
                watchLabel: featuredMovie == null
                    ? null
                    : (featuredMovie.canWatch ? 'Watch now' : 'View movie'),
              ),
              const SizedBox(height: 22),
              _SectionTitle(
                title: 'Hiring feed',
                subtitle: 'Fresh community openings with room to grow.',
                actionLabel: 'Open jobs',
                onTap: () => onNavigate(3),
              ),
              const SizedBox(height: 12),
              if (jobs.isEmpty)
                const _EmptyStateCard(
                  icon: Icons.work_outline_rounded,
                  title: 'No hiring posts yet',
                  message:
                      'New openings will show here as soon as recruiters and salon owners publish them.',
                )
              else
                ...jobs.map(
                  (job) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _JobFeedCard(
                      item: job,
                      onOpenJobs: () => onNavigate(3),
                      onSave: () => social.toggleBookmark(
                        type: 'job_listing',
                        id: job.id,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              _InlineBanner(
                icon: Icons.forum_rounded,
                title: 'Live community chat is one tap away',
                message:
                    'Jump into group rooms or direct messages whenever you want faster answers about work, rooms, or local life.',
                cta: 'Open chat',
                onTap: () => onNavigate(4),
              ),
              const SizedBox(height: 22),
              _SectionTitle(
                title: 'Marketplace picks',
                subtitle: 'Useful finds, salon gear, and community listings.',
                actionLabel: 'Open market',
                onTap: () => onNavigate(2),
              ),
              const SizedBox(height: 12),
              _MarketShelf(
                items: marketItems,
                onOpen: () => onNavigate(2),
                onSave: (item) => social.toggleBookmark(
                  type: 'marketplace_listing',
                  id: item.id,
                ),
              ),
              const SizedBox(height: 22),
              _SectionTitle(
                title: 'Rooms and housing',
                subtitle:
                    'Places to stay, shared rooms, and new move-in leads.',
                actionLabel: 'Browse homes',
                onTap: () => onNavigate(3),
              ),
              const SizedBox(height: 12),
              _PropertyShelf(
                items: properties,
                onOpen: () => onNavigate(3),
                onSave: (item) => social.toggleBookmark(
                  type: 'property_listing',
                  id: item.id,
                ),
              ),
              const SizedBox(height: 22),
              _SectionTitle(
                title: 'Saved for later',
                subtitle: 'Keep the most useful posts within reach.',
                actionLabel: 'Explore',
                onTap: () => onNavigate(2),
              ),
              const SizedBox(height: 12),
              _SavedStrip(items: savedItems, onNavigate: onNavigate),
              if (social.error != null) ...[
                const SizedBox(height: 16),
                _ErrorBanner(message: _friendlyFeedError(social.error!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: _hubInk,
          disabledBackgroundColor: Colors.white,
          disabledForegroundColor: _hubMuted.withValues(alpha: 0.5),
          side: const BorderSide(color: _hubLine),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: Icon(icon),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.user,
    required this.summary,
    required this.movieCount,
    required this.onNavigate,
  });

  final SessionUser? user;
  final UserProfileSummary? summary;
  final int movieCount;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AvatarBadge(
                imageUrl: user?.avatarUrl ?? '',
                label: user?.name ?? 'Guest',
                radius: 28,
                backgroundColor: _hubSoftBlue,
                foregroundColor: _hubBlue,
                emptyIcon: Icons.person_rounded,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, ${_preferredName(user?.name)}',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: _hubInk),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Find jobs, movie nights, homes, and local updates in one place.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: _hubMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _hubSoftSlate,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _hubSoftBlue,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.travel_explore_rounded,
                    color: _hubBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Start with what you need today. This feed is tuned for work leads, marketplace finds, movie access, and places to stay.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _hubInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _ShortcutPill(
                  icon: Icons.work_outline_rounded,
                  label: 'Jobs',
                  tint: _hubSoftTeal,
                  iconColor: const Color(0xFF0F8E7C),
                  onTap: () => onNavigate(3),
                ),
                _ShortcutPill(
                  icon: Icons.smart_display_rounded,
                  label: 'Movies',
                  tint: _hubSoftGold,
                  iconColor: const Color(0xFFC98621),
                  onTap: () => onNavigate(1),
                ),
                _ShortcutPill(
                  icon: Icons.storefront_rounded,
                  label: 'Market',
                  tint: _hubSoftBlue,
                  iconColor: _hubBlue,
                  onTap: () => onNavigate(2),
                ),
                _ShortcutPill(
                  icon: Icons.apartment_rounded,
                  label: 'Housing',
                  tint: const Color(0xFFEDEBFF),
                  iconColor: const Color(0xFF5A51D6),
                  onTap: () => onNavigate(3),
                ),
                _ShortcutPill(
                  icon: Icons.chat_bubble_rounded,
                  label: 'Chat',
                  tint: const Color(0xFFF0F4FA),
                  iconColor: const Color(0xFF516379),
                  onTap: () => onNavigate(4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Jobs',
                  value: '${summary?.jobCount ?? 0}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'Movies',
                  value: '${summary?.movieCount ?? movieCount}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'Housing',
                  value: '${summary?.propertyCount ?? 0}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShortcutPill extends StatelessWidget {
  const _ShortcutPill({
    required this.icon,
    required this.label,
    required this.tint,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _hubLine),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(icon, size: 15, color: iconColor),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _hubInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: _hubSoftSlate,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 20, color: _hubInk),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _hubMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MovieSpotlightCard extends StatelessWidget {
  const _MovieSpotlightCard({
    required this.movie,
    required this.plan,
    required this.activeSubscription,
    required this.onExplore,
    required this.onWatch,
    required this.watchLabel,
  });

  final MovieItem? movie;
  final MoviePlanModel? plan;
  final MovieSubscriptionModel? activeSubscription;
  final VoidCallback onExplore;
  final VoidCallback? onWatch;
  final String? watchLabel;

  @override
  Widget build(BuildContext context) {
    final imageUrl = movie?.bannerUrl.isNotEmpty == true
        ? movie!.bannerUrl
        : (movie?.posterUrl ?? '');
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final stackedButtons = constraints.maxWidth < 420;
        final cardHeight = compact ? 484.0 : (stackedButtons ? 404.0 : 364.0);
        final planLabel = activeSubscription?.isActive == true
            ? compact
                  ? 'Active: ${activeSubscription?.planName ?? 'Subscription'}'
                  : 'Plan active: ${activeSubscription?.planName ?? 'Subscription'}'
            : plan == null
            ? 'Subscription ready'
            : compact
            ? '${plan!.currency} ${plan!.price.toStringAsFixed(0)} / ${plan!.durationDays}d'
            : '${plan!.currency} ${plan!.price.toStringAsFixed(2)} / ${plan!.durationDays} days';

        return Container(
          height: cardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Stack(
              children: [
                Positioned.fill(
                  child: imageUrl.isEmpty
                      ? Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF173A70), Color(0xFF1B74E4)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        )
                      : RemoteImage(url: imageUrl, fit: BoxFit.cover),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF0C1830).withValues(alpha: 0.12),
                          const Color(0xFF0C1830).withValues(alpha: 0.30),
                          const Color(0xFF0C1830).withValues(alpha: 0.88),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(compact ? 18 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'MOVIE SPOTLIGHT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        movie?.title ?? 'Your next movie night starts here',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontSize: compact ? 20 : 28,
                          height: 1.08,
                        ),
                      ),
                      SizedBox(height: compact ? 4 : 6),
                      Text(
                        movie?.summary.isNotEmpty == true
                            ? movie!.summary
                            : 'Use this slot for fresh releases, community promotions, or a paid streaming highlight that deserves attention.',
                        maxLines: compact ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontWeight: FontWeight.w500,
                          fontSize: compact ? 13 : null,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: compact ? 10 : 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _GlassPill(
                            icon: Icons.movie_filter_rounded,
                            label: movie?.category?.name.isNotEmpty == true
                                ? movie!.category!.name
                                : 'Community streaming',
                          ),
                          _GlassPill(
                            icon: Icons.workspace_premium_rounded,
                            label: planLabel,
                          ),
                        ],
                      ),
                      SizedBox(height: compact ? 10 : 12),
                      if (compact) ...[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: onWatch ?? onExplore,
                            icon: Icon(
                              onWatch == null
                                  ? Icons.explore_rounded
                                  : Icons.play_circle_fill_rounded,
                            ),
                            label: Text(
                              onWatch == null
                                  ? 'Browse movies'
                                  : (watchLabel ?? 'Watch movie'),
                            ),
                          ),
                        ),
                      ] else if (stackedButtons) ...[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: onWatch ?? onExplore,
                            icon: Icon(
                              onWatch == null
                                  ? Icons.explore_rounded
                                  : Icons.play_circle_fill_rounded,
                            ),
                            label: Text(
                              onWatch == null
                                  ? 'Browse movies'
                                  : (watchLabel ?? 'Watch movie'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: onExplore,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.08,
                              ),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.22),
                              ),
                            ),
                            icon: const Icon(Icons.grid_view_rounded),
                            label: const Text('See library'),
                          ),
                        ),
                      ] else
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: onWatch ?? onExplore,
                                icon: Icon(
                                  onWatch == null
                                      ? Icons.explore_rounded
                                      : Icons.play_circle_fill_rounded,
                                ),
                                label: Text(
                                  onWatch == null
                                      ? 'Browse movies'
                                      : (watchLabel ?? 'Watch movie'),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: onExplore,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.08,
                                  ),
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.22),
                                  ),
                                ),
                                icon: const Icon(Icons.grid_view_rounded),
                                label: const Text('See library'),
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
      },
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontSize: 20, color: _hubInk),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: _hubMuted),
              ),
            ],
          ),
        ),
        TextButton(onPressed: onTap, child: Text(actionLabel)),
      ],
    );
  }
}

class _JobFeedCard extends StatelessWidget {
  const _JobFeedCard({
    required this.item,
    required this.onOpenJobs,
    required this.onSave,
  });

  final JobListingItem item;
  final VoidCallback onOpenJobs;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final location = _locationLabel(item.city, item.state);
    final salary = _salaryLabel(item);
    final owner = item.salonName.isNotEmpty ? item.salonName : item.userName;

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AvatarBadge(
                imageUrl: '',
                label: owner,
                radius: 24,
                backgroundColor: _hubSoftTeal,
                foregroundColor: const Color(0xFF0F8E7C),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      owner.isEmpty ? 'Community hiring post' : owner,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (location.isNotEmpty) location,
                        if (item.listingMode.isNotEmpty)
                          _humanize(item.listingMode),
                      ].join('  •  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: _hubMuted),
                    ),
                  ],
                ),
              ),
              _BookmarkButton(saved: item.saved, onTap: onSave),
            ],
          ),
          if (item.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: RemoteImage(
                  url: item.imageUrls.first,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            item.title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 20, color: _hubInk),
          ),
          if (item.description.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.description.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: _hubMuted),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TagPill(
                icon: Icons.work_history_rounded,
                label: _humanize(item.listingMode),
              ),
              if (salary.isNotEmpty)
                _TagPill(icon: Icons.attach_money_rounded, label: salary),
              if (location.isNotEmpty)
                _TagPill(icon: Icons.location_on_outlined, label: location),
              if (item.contactPhone.isNotEmpty)
                _TagPill(icon: Icons.phone_rounded, label: item.contactPhone),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onOpenJobs,
            icon: const Icon(Icons.arrow_outward_rounded),
            label: const Text('Open job board'),
          ),
        ],
      ),
    );
  }
}

class _InlineBanner extends StatelessWidget {
  const _InlineBanner({
    required this.icon,
    required this.title,
    required this.message,
    required this.cta,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final String cta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      gradient: const LinearGradient(
        colors: [Color(0xFFF6FAFF), Color(0xFFF0FBF7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _hubSoftBlue,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: _hubBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: _hubMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.forum_rounded),
            label: Text(cta),
          ),
        ],
      ),
    );
  }
}

class _MarketShelf extends StatelessWidget {
  const _MarketShelf({
    required this.items,
    required this.onOpen,
    required this.onSave,
  });

  final List<MarketplaceItem> items;
  final VoidCallback onOpen;
  final Future<void> Function(MarketplaceItem item) onSave;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyStateCard(
        icon: Icons.storefront_outlined,
        title: 'Marketplace is still quiet',
        message:
            'Fresh listings will show up here as soon as the marketplace starts moving.',
      );
    }

    return SizedBox(
      height: 396,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final item = items[index];
          return _MarketItemCard(
            item: item,
            onOpen: onOpen,
            onSave: () => onSave(item),
          );
        },
      ),
    );
  }
}

class _MarketItemCard extends StatelessWidget {
  const _MarketItemCard({
    required this.item,
    required this.onOpen,
    required this.onSave,
  });

  final MarketplaceItem item;
  final VoidCallback onOpen;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final location = _locationLabel(item.city, item.state);
    final tags = <Widget>[
      if (item.categoryName.isNotEmpty)
        _TagPill(icon: Icons.sell_outlined, label: item.categoryName),
      if (location.isNotEmpty)
        _TagPill(icon: Icons.location_on_outlined, label: location),
      if (item.condition.isNotEmpty)
        _TagPill(
          icon: Icons.verified_outlined,
          label: _humanize(item.condition),
        ),
    ].take(1).toList(growable: false);

    return SizedBox(
      width: 252,
      child: _SurfaceCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    child: SizedBox(
                      height: 132,
                      width: double.infinity,
                      child: item.imageUrls.isEmpty
                          ? const _MediaPlaceholder(
                              icon: Icons.inventory_2_rounded,
                              label: 'Marketplace item',
                              tint: _hubSoftBlue,
                            )
                          : RemoteImage(
                              url: item.imageUrls.first,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _BookmarkButton(saved: item.saved, onTap: onSave),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _money(item.price, item.currency),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        color: _hubBlue,
                      ),
                    ),
                    if (item.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        item.description.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: _hubMuted),
                      ),
                    ],
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: tags),
                    ],
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

class _PropertyShelf extends StatelessWidget {
  const _PropertyShelf({
    required this.items,
    required this.onOpen,
    required this.onSave,
  });

  final List<PropertyListingItem> items;
  final VoidCallback onOpen;
  final Future<void> Function(PropertyListingItem item) onSave;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyStateCard(
        icon: Icons.apartment_outlined,
        title: 'No housing posts yet',
        message:
            'New room shares and housing posts will surface here when they are published.',
      );
    }

    return SizedBox(
      height: 420,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final item = items[index];
          return _PropertyItemCard(
            item: item,
            onOpen: onOpen,
            onSave: () => onSave(item),
          );
        },
      ),
    );
  }
}

class _PropertyItemCard extends StatelessWidget {
  const _PropertyItemCard({
    required this.item,
    required this.onOpen,
    required this.onSave,
  });

  final PropertyListingItem item;
  final VoidCallback onOpen;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final location = _locationLabel(item.city, item.state);
    final tags = <Widget>[
      if (item.listingMode.isNotEmpty)
        _TagPill(icon: Icons.key_rounded, label: _humanize(item.listingMode)),
      if (item.amenities.isNotEmpty)
        _TagPill(icon: Icons.star_outline_rounded, label: item.amenities.first)
      else if (item.availableFrom != null)
        _TagPill(
          icon: Icons.calendar_today_rounded,
          label: 'From ${AppDateUtils.formatDate(item.availableFrom)}',
        ),
    ];

    return SizedBox(
      width: 266,
      child: _SurfaceCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    child: SizedBox(
                      height: 144,
                      width: double.infinity,
                      child: item.imageUrls.isEmpty
                          ? const _MediaPlaceholder(
                              icon: Icons.home_work_rounded,
                              label: 'Housing post',
                              tint: _hubSoftTeal,
                            )
                          : RemoteImage(
                              url: item.imageUrls.first,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _BookmarkButton(saved: item.saved, onTap: onSave),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _money(item.price, item.currency),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        color: _hubInk,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      location.isEmpty ? 'U.S. listing' : location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: _hubMuted),
                    ),
                    const SizedBox(height: 12),
                    if (tags.isNotEmpty)
                      Wrap(spacing: 8, runSpacing: 8, children: tags),
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

class _SavedStrip extends StatelessWidget {
  const _SavedStrip({required this.items, required this.onNavigate});

  final List<SavedItemModel> items;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyStateCard(
        icon: Icons.bookmark_border_rounded,
        title: 'No saved items yet',
        message:
            'Saved jobs, housing posts, and marketplace listings will surface here for quick access.',
      );
    }

    return _SurfaceCard(
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _SavedRow(
              item: items[index],
              onTap: () =>
                  onNavigate(_tabForSavedType(items[index].savableType)),
            ),
            if (index < items.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: _hubLine),
              ),
          ],
        ],
      ),
    );
  }
}

class _SavedRow extends StatelessWidget {
  const _SavedRow({required this.item, required this.onTap});

  final SavedItemModel item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _hubSoftSlate,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(_iconForSavedType(item.savableType), color: _hubBlue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title.isEmpty ? 'Saved item' : item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle.isEmpty
                        ? _humanize(item.savableType)
                        : _humanize(item.subtitle),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: _hubMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _hubSoftBlue,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                item.status.isEmpty ? 'Saved' : _humanize(item.status),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _hubBlue,
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

class _BookmarkButton extends StatelessWidget {
  const _BookmarkButton({required this.saved, required this.onTap});

  final bool saved;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: saved ? _hubSoftBlue : _hubSoftSlate,
        foregroundColor: saved ? _hubBlue : _hubMuted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_add_outlined),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: _hubSoftSlate,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _hubMuted),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _hubInk,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.gradient,
  });

  final Widget child;
  final EdgeInsets padding;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? Colors.white : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _hubLine),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({
    required this.imageUrl,
    required this.label,
    required this.radius,
    required this.backgroundColor,
    required this.foregroundColor,
    this.emptyIcon,
  });

  final String imageUrl;
  final String label;
  final double radius;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData? emptyIcon;

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(radius * 0.9),
      ),
      child: imageUrl.trim().isEmpty
          ? Center(
              child: emptyIcon == null
                  ? Text(
                      _initials(label),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: foregroundColor,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : Icon(emptyIcon, color: foregroundColor, size: radius),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(radius * 0.9),
              child: RemoteImage(
                url: imageUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
              ),
            ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({
    required this.icon,
    required this.label,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tint, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: _hubInk.withValues(alpha: 0.7)),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _hubMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: _hubSoftSlate,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, size: 30, color: _hubMuted),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: _hubMuted),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF4C7CF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFFDDE2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFC83B50),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF9E2D40),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _friendlyFeedError(String raw) {
  final lower = raw.toLowerCase();

  if (lower.contains('bookmarks')) {
    return 'Saved items are still syncing right now. The rest of the feed is ready to use.';
  }

  if (lower.contains('404')) {
    return 'One feed section is not available yet. Pull down to refresh in a moment.';
  }

  if (lower.contains('401') || lower.contains('403')) {
    return 'Your session needs attention. Please sign in again.';
  }

  if (lower.contains('timeout') || lower.contains('timed out')) {
    return 'The feed is taking longer than usual to load. Please try again shortly.';
  }

  return 'A few sections could not be loaded right now. Pull down to try again.';
}

String _preferredName(String? fullName) {
  final trimmed = fullName?.trim() ?? '';
  if (trimmed.isEmpty) return 'friend';

  final words = trimmed
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return 'friend';

  final lower = words.last.toLowerCase();
  return '${lower[0].toUpperCase()}${lower.substring(1)}';
}

String _initials(String text) {
  final parts = text
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .toList();

  if (parts.isEmpty) return 'U';
  return parts.map((part) => part[0].toUpperCase()).join();
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

String _locationLabel(String city, String state) {
  final parts = <String>[
    if (city.trim().isNotEmpty) city.trim(),
    if (state.trim().isNotEmpty) state.trim(),
  ];
  return parts.join(', ');
}

String _money(double value, String currency) {
  final prefix = currency.toUpperCase() == 'USD'
      ? '\$'
      : '${currency.toUpperCase()} ';
  final isWhole = value == value.roundToDouble();
  return '$prefix${value.toStringAsFixed(isWhole ? 0 : 2)}';
}

String _salaryLabel(JobListingItem item) {
  if (item.salaryMin != null && item.salaryMax != null) {
    return '${_money(item.salaryMin!, item.salaryCurrency)} - ${_money(item.salaryMax!, item.salaryCurrency)}';
  }
  if (item.salaryMin != null) {
    return 'From ${_money(item.salaryMin!, item.salaryCurrency)}';
  }
  if (item.salaryMax != null) {
    return 'Up to ${_money(item.salaryMax!, item.salaryCurrency)}';
  }
  return '';
}

int _tabForSavedType(String type) {
  switch (type) {
    case 'movie':
      return 1;
    case 'marketplace_listing':
      return 2;
    case 'job_listing':
    case 'property_listing':
      return 3;
    default:
      return 0;
  }
}

IconData _iconForSavedType(String type) {
  switch (type) {
    case 'marketplace_listing':
      return Icons.storefront_rounded;
    case 'job_listing':
      return Icons.work_rounded;
    case 'property_listing':
      return Icons.home_work_rounded;
    case 'movie':
      return Icons.movie_creation_rounded;
    default:
      return Icons.bookmark_rounded;
  }
}
