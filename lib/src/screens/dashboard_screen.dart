import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/session_controller.dart';
import '../controllers/social_hub_controller.dart';
import '../core/constants/app_constants.dart';
import '../core/localization/app_localizer.dart';
import '../models/job_listing_item.dart';
import '../models/marketplace_item.dart';
import '../models/movie_item.dart';
import '../models/property_listing_item.dart';
import '../models/saved_item.dart';
import '../models/session_user.dart';
import '../widgets/app_logo.dart';
import '../widgets/metro_ui.dart';
import '../widgets/remote_image.dart';
import 'account_hub_screen.dart';
import 'movie_detail_screen.dart';

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

  Future<void> _openAccountMenu(
    BuildContext context,
    SessionController session,
  ) async {
    final action = await showModalBottomSheet<_AccountMenuAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: MetroInsetPanel(
              padding: EdgeInsets.zero,
              borderColor: kMetroPrimary,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                    child: Row(
                      children: [
                        _DashboardAvatar(user: session.user, size: 46),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.user?.name.trim().isNotEmpty == true
                                    ? session.user!.name
                                    : context.tr('Guest'),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(color: kMetroInk),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '@${session.user?.username.isNotEmpty == true ? session.user!.username : 'member'}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: kMetroMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: kMetroLine),
                  _AccountMenuTile(
                    icon: Icons.person_outline_rounded,
                    label: 'Edit profile',
                    onTap: () => Navigator.of(
                      sheetContext,
                    ).pop(_AccountMenuAction.profile),
                  ),
                  _AccountMenuTile(
                    icon: Icons.help_outline_rounded,
                    label: 'FAQ',
                    onTap: () =>
                        Navigator.of(sheetContext).pop(_AccountMenuAction.faq),
                  ),
                  _AccountMenuTile(
                    icon: Icons.forum_outlined,
                    label: 'Q&A',
                    onTap: () => Navigator.of(
                      sheetContext,
                    ).pop(_AccountMenuAction.questions),
                  ),
                  _AccountMenuTile(
                    icon: Icons.gavel_rounded,
                    label: 'Terms & Conditions',
                    onTap: () => Navigator.of(
                      sheetContext,
                    ).pop(_AccountMenuAction.terms),
                  ),
                  _AccountMenuTile(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy Policy',
                    onTap: () => Navigator.of(
                      sheetContext,
                    ).pop(_AccountMenuAction.privacy),
                  ),
                  _AccountMenuTile(
                    icon: Icons.logout_rounded,
                    label: 'Logout',
                    destructive: true,
                    onTap: () => Navigator.of(
                      sheetContext,
                    ).pop(_AccountMenuAction.logout),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!context.mounted || action == null) {
      return;
    }

    switch (action) {
      case _AccountMenuAction.profile:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AccountHubScreen(
              initialSection: AccountHubSection.profile,
            ),
          ),
        );
      case _AccountMenuAction.faq:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                const AccountHubScreen(initialSection: AccountHubSection.faq),
          ),
        );
      case _AccountMenuAction.questions:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AccountHubScreen(
              initialSection: AccountHubSection.questions,
            ),
          ),
        );
      case _AccountMenuAction.terms:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                const AccountHubScreen(initialSection: AccountHubSection.terms),
          ),
        );
      case _AccountMenuAction.privacy:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AccountHubScreen(
              initialSection: AccountHubSection.privacy,
            ),
          ),
        );
      case _AccountMenuAction.logout:
        await session.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final social = context.watch<SocialHubController>();
    final summary = social.profile?.summary;
    final featuredMovie = social.movies.isNotEmpty ? social.movies.first : null;
    final movieCount = summary?.movieCount ?? social.movies.length;
    final jobs = social.jobItems.take(2).toList(growable: false);
    final marketItems = social.marketplaceItems.take(2).toList(growable: false);
    final properties = social.propertyItems.take(2).toList(growable: false);
    final savedItems = social.bookmarks.take(3).toList(growable: false);
    final feedBusy =
        social.loadingHome ||
        social.loadingMovies ||
        social.loadingMarketplace ||
        social.loadingJobs ||
        social.loadingProperties;
    final jobImage = _jobImage(jobs, social);
    final marketImage = _marketImage(marketItems, social);
    final housingImage = _housingImage(properties, social);
    final movieImage = _movieImage(featuredMovie, social);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 66,
        titleSpacing: 16,
        title: Row(
          children: [
            const AppLogo(size: 30, showWordmark: false),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppConstants.appName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: kMetroInk,
                  fontSize: 24,
                ),
              ),
            ),
          ],
        ),
        actions: [
          MetroActionButton(
            icon: Icons.refresh_rounded,
            label: 'Refresh',
            onPressed: feedBusy ? null : () => _refreshFeed(social),
          ),
          const SizedBox(width: 8),
          _DashboardProfileButton(
            user: session.user,
            onPressed: () => _openAccountMenu(context, session),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: MetroPageBackground(
        child: RefreshIndicator(
          onRefresh: () => _refreshFeed(social),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              if (feedBusy)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(minHeight: 3),
                ),
              const SizedBox(height: 4),
              _DashboardTileGrid(
                jobCount: '${summary?.jobCount ?? 0}',
                movieCount: '$movieCount',
                propertyCount: '${summary?.propertyCount ?? 0}',
                movieImage: movieImage,
                chatImage: movieImage,
                jobImage: jobImage,
                marketImage: marketImage,
                housingImage: housingImage,
                savedImage: marketImage.isNotEmpty ? marketImage : housingImage,
                onNavigate: onNavigate,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: MetroMetricTile(
                      label: 'Jobs',
                      value: '${summary?.jobCount ?? 0}',
                      borderColor: kMetroGold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MetroMetricTile(
                      label: 'Movies',
                      value: '$movieCount',
                      borderColor: kMetroCoral,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MetroMetricTile(
                      label: 'Housing',
                      value: '${summary?.propertyCount ?? 0}',
                      borderColor: kMetroPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _FeatureMoviePanel(
                movie: featuredMovie,
                onWatch: featuredMovie == null
                    ? null
                    : () => _openFeaturedMovie(context, featuredMovie),
                onBrowse: () => onNavigate(1),
              ),
              const SizedBox(height: 18),
              MetroSectionHeader(
                title: 'Hiring feed',
                subtitle: 'Fresh community openings with room to grow.',
                actionLabel: 'Open jobs',
                onAction: () => onNavigate(3),
              ),
              const SizedBox(height: 10),
              if (jobs.isEmpty)
                const SizedBox(
                  height: 190,
                  child: MetroEmptyState(
                    icon: Icons.work_outline_rounded,
                    title: 'No hiring posts yet',
                    message:
                        'New openings will show here as soon as recruiters and salon owners publish them.',
                    borderColor: kMetroGold,
                  ),
                )
              else
                ...jobs.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _WideInfoTile(
                      borderColor: kMetroGold,
                      imageUrl: item.imageUrls.isNotEmpty
                          ? item.imageUrls.first
                          : jobImage,
                      title: item.title,
                      subtitle: item.description,
                      meta: [
                        _location(item.city, item.state),
                        _humanize(item.listingMode),
                      ].where((value) => value.isNotEmpty).join(' • '),
                      primaryLabel: 'Open jobs',
                      onPrimary: () => onNavigate(3),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              MetroSectionHeader(
                title: 'Saved for later',
                subtitle: 'Keep the most useful posts within reach.',
                actionLabel: 'Explore',
                onAction: () => onNavigate(2),
              ),
              const SizedBox(height: 10),
              _SavedPanel(items: savedItems, onNavigate: onNavigate),
              if (social.error != null) ...[
                const SizedBox(height: 14),
                MetroInsetPanel(
                  borderColor: kMetroRose,
                  child: Text(
                    _friendlyFeedError(social.error!),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF8D3F56),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _AccountMenuAction { profile, faq, questions, terms, privacy, logout }

class _DashboardProfileButton extends StatelessWidget {
  const _DashboardProfileButton({required this.user, required this.onPressed});

  final SessionUser? user;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.tr('Account menu'),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(kMetroRadius),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: kMetroSurface,
            borderRadius: BorderRadius.circular(kMetroRadius),
            border: Border.all(color: kMetroLine),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A2C2143),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Center(child: _DashboardAvatar(user: user, size: 28)),
        ),
      ),
    );
  }
}

class _DashboardAvatar extends StatelessWidget {
  const _DashboardAvatar({required this.user, required this.size});

  final SessionUser? user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user?.avatarUrl.trim() ?? '';
    final source = user?.name.trim().isNotEmpty == true
        ? user!.name.trim()
        : user?.username.trim() ?? '';
    final initial = source.isEmpty ? 'N' : source[0].toUpperCase();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: kMetroPrimarySoft,
        borderRadius: BorderRadius.circular(kMetroRadius),
        border: Border.all(color: kMetroLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl.isEmpty
          ? Center(
              child: Text(
                initial,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: kMetroPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : RemoteImage(
              url: avatarUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorFallback: Center(
                child: Text(
                  initial,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: kMetroPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
    );
  }
}

class _AccountMenuTile extends StatelessWidget {
  const _AccountMenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final foreground = destructive ? const Color(0xFFB85166) : kMetroInk;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: foreground),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.tr(label),
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: foreground),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: foreground),
          ],
        ),
      ),
    );
  }
}

class _DashboardTileGrid extends StatelessWidget {
  const _DashboardTileGrid({
    required this.jobCount,
    required this.movieCount,
    required this.propertyCount,
    required this.movieImage,
    required this.chatImage,
    required this.jobImage,
    required this.marketImage,
    required this.housingImage,
    required this.savedImage,
    required this.onNavigate,
  });

  final String jobCount;
  final String movieCount;
  final String propertyCount;
  final String movieImage;
  final String chatImage;
  final String jobImage;
  final String marketImage;
  final String housingImage;
  final String savedImage;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.86,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _HomeMetroTile(
          borderColor: kMetroRose,
          imageUrl: chatImage,
          title: 'Chat',
          subtitle: 'Open chat',
          eyebrow: 'Groups',
          badge: 'Rooms',
          onTap: () => onNavigate(4),
        ),
        _HomeMetroTile(
          borderColor: kMetroCoral,
          imageUrl: movieImage,
          title: 'Movies',
          subtitle: 'Watch',
          eyebrow: 'Featured movie',
          badge: movieCount,
          onTap: () => onNavigate(1),
        ),
        _HomeMetroTile(
          borderColor: kMetroGold,
          imageUrl: jobImage,
          title: 'Work & Stay',
          subtitle: 'Jobs',
          extraLine: 'Room Share',
          eyebrow: 'Work & Stay',
          badge: jobCount,
          onTap: () => onNavigate(3),
        ),
        _HomeMetroTile(
          borderColor: kMetroPrimary,
          imageUrl: marketImage,
          title: 'Marketplace',
          subtitle: 'Open market',
          eyebrow: 'Marketplace',
          badge: 'Market',
          onTap: () => onNavigate(2),
        ),
        _HomeMetroTile(
          borderColor: const Color(0xFF8D98C9),
          imageUrl: housingImage,
          title: 'Rooms and housing',
          subtitle: 'Browse homes',
          eyebrow: 'Room Share',
          badge: propertyCount,
          onTap: () => onNavigate(3),
        ),
        _HomeMetroTile(
          borderColor: const Color(0xFFC18E68),
          imageUrl: savedImage,
          title: 'Saved for later',
          subtitle: 'Explore',
          eyebrow: 'Saved',
          badge: 'Saved',
          onTap: () => onNavigate(2),
        ),
      ],
    );
  }
}

class _HomeMetroTile extends StatelessWidget {
  const _HomeMetroTile({
    required this.borderColor,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.eyebrow,
    this.badge,
    this.extraLine,
  });

  final Color borderColor;
  final String imageUrl;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? eyebrow;
  final String? badge;
  final String? extraLine;

  @override
  Widget build(BuildContext context) {
    return MetroImageFrame(
      borderColor: borderColor,
      imageUrl: imageUrl,
      onTap: onTap,
      overlayTop: const Color(0x16000000),
      overlayBottom: const Color(0xC8161616),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((eyebrow != null && eyebrow!.trim().isNotEmpty) || badge != null)
            Row(
              children: [
                if (eyebrow != null && eyebrow!.trim().isNotEmpty)
                  MetroBadge(
                    label: eyebrow!,
                    backgroundColor: Colors.white.withValues(alpha: 0.86),
                  ),
                const Spacer(),
                if (badge != null)
                  MetroBadge(
                    label: badge!,
                    backgroundColor: borderColor.withValues(alpha: 0.92),
                    foregroundColor: Colors.white,
                    outlined: false,
                  ),
              ],
            ),
          const Spacer(),
          Text(
            context.tr(title),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.white, fontSize: 20),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr(subtitle),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (extraLine != null) ...[
            const SizedBox(height: 2),
            Text(
              context.tr(extraLine!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.86),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureMoviePanel extends StatelessWidget {
  const _FeatureMoviePanel({
    required this.movie,
    required this.onWatch,
    required this.onBrowse,
  });

  final MovieItem? movie;
  final VoidCallback? onWatch;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final imageUrl = movie?.bannerUrl.isNotEmpty == true
        ? movie!.bannerUrl
        : (movie?.posterUrl ?? '');

    return SizedBox(
      height: 238,
      child: MetroImageFrame(
        borderColor: kMetroCoral,
        imageUrl: imageUrl,
        overlayTop: const Color(0x12000000),
        overlayBottom: const Color(0xD1131823),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MetroBadge(
              label: 'MOVIE SPOTLIGHT',
              backgroundColor: Color(0xFFFDF2E8),
            ),
            const Spacer(),
            Text(
              context.tr(movie?.title ?? 'Your next movie night starts here'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              movie?.summary.isNotEmpty == true
                  ? context.tr(movie!.summary)
                  : context.tr(
                      'Use this slot for fresh releases, community promotions, or a paid streaming highlight that deserves attention.',
                    ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onWatch ?? onBrowse,
                    child: Text(
                      context.tr(
                        onWatch == null ? 'Browse movies' : 'Watch now',
                      ),
                    ),
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

class _WideInfoTile extends StatelessWidget {
  const _WideInfoTile({
    required this.borderColor,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final Color borderColor;
  final String imageUrl;
  final String title;
  final String subtitle;
  final String meta;
  final String primaryLabel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 202,
      child: MetroImageFrame(
        borderColor: borderColor,
        imageUrl: imageUrl,
        overlayTop: const Color(0x0A000000),
        overlayBottom: const Color(0xDA151515),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (meta.isNotEmpty)
              MetroBadge(
                label: meta,
                backgroundColor: Colors.white.withValues(alpha: 0.9),
              ),
            const Spacer(),
            Text(
              context.tr(title),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr(subtitle),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 46,
              child: FilledButton(
                onPressed: onPrimary,
                style: FilledButton.styleFrom(
                  backgroundColor: borderColor.withValues(alpha: 0.96),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                child: Text(context.tr(primaryLabel)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedPanel extends StatelessWidget {
  const _SavedPanel({required this.items, required this.onNavigate});

  final List<SavedItemModel> items;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox(
        height: 178,
        child: MetroEmptyState(
          icon: Icons.bookmark_border_rounded,
          title: 'No saved items yet',
          message:
              'Saved jobs, housing posts, and marketplace listings will surface here for quick access.',
          borderColor: Color(0xFFC18E68),
        ),
      );
    }

    return MetroInsetPanel(
      borderColor: const Color(0xFFC18E68),
      padding: const EdgeInsets.all(12),
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
                child: Divider(),
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
      onTap: onTap,
      borderRadius: BorderRadius.circular(kMetroRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF0E8D8),
                borderRadius: BorderRadius.circular(kMetroRadius),
                border: Border.all(color: kMetroLine),
              ),
              child: Icon(
                _iconForSavedType(item.savableType),
                color: kMetroInk,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(item.title.isEmpty ? 'Saved item' : item.title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: kMetroInk),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr(_savedSubtitleLabel(item)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: kMetroMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            MetroBadge(
              label: item.status.isEmpty
                  ? 'Saved'
                  : _savedStatusLabel(item.status),
            ),
          ],
        ),
      ),
    );
  }
}

int _tabForSavedType(String type) {
  switch (type) {
    case 'movie':
      return 1;
    case 'marketplace_listing':
      return 2;
    case 'property_listing':
    case 'job_listing':
      return 3;
    default:
      return 0;
  }
}

IconData _iconForSavedType(String type) {
  switch (type) {
    case 'movie':
      return Icons.smart_display_rounded;
    case 'marketplace_listing':
      return Icons.storefront_rounded;
    case 'property_listing':
      return Icons.home_work_rounded;
    case 'job_listing':
      return Icons.work_outline_rounded;
    default:
      return Icons.bookmark_rounded;
  }
}

String _savedSubtitleLabel(SavedItemModel item) {
  final subtitle = item.subtitle.trim().toLowerCase();
  switch (subtitle) {
    case 'hiring':
      return 'Hiring';
    case 'looking_for_job':
      return 'Looking for job';
    case 'room_share':
      return 'Room share';
    case 'rent_out':
      return 'Homes for rent';
    case 'looking_room':
      return 'Looking for a room';
    default:
      return _savedTypeLabel(item.savableType);
  }
}

String _savedTypeLabel(String type) {
  switch (type) {
    case 'movie':
      return 'Movie';
    case 'marketplace_listing':
      return 'Marketplace listing';
    case 'job_listing':
      return 'Job listing';
    case 'property_listing':
      return 'Property listing';
    default:
      return _humanize(type);
  }
}

String _savedStatusLabel(String status) {
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

String _location(String city, String state) {
  final parts = <String>[
    if (city.trim().isNotEmpty) city.trim(),
    if (state.trim().isNotEmpty) state.trim(),
  ];
  return parts.join(', ');
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
