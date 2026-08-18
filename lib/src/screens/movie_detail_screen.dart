import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../controllers/social_hub_controller.dart';
import '../core/localization/app_localizer.dart';
import '../core/utils/app_date_utils.dart';
import '../core/utils/movie_showcase_utils.dart';
import '../models/movie_item.dart';
import '../models/movie_plan_model.dart';
import '../widgets/metro_ui.dart';
import '../widgets/remote_image.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({required this.movie, super.key});

  final MovieItem movie;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen>
    with WidgetsBindingObserver {
  static const Map<String, String> _networkHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Android) AppleWebKit/537.36 Mobile Safari/537.36',
    'Accept': '*/*',
  };

  VideoPlayerController? _videoController;
  Future<void>? _videoFuture;
  bool _initializingVideo = false;
  bool _loadingDetail = false;
  bool _requestedPlayback = false;
  String? _videoError;
  late MovieItem _movie;
  final GlobalKey _playerSectionKey = GlobalKey();
  final GlobalKey _lockedSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _movie = widget.movie;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshMovieDetail();
    });
  }

  bool _canWatch(SocialHubController controller) {
    return _movie.accessType == 'free' ||
        _movie.canWatch ||
        controller.activeSubscription?.isActive == true;
  }

  VideoFormat? _resolveVideoFormat(String url) {
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.contains('.m3u8')) {
      return VideoFormat.hls;
    }
    return null;
  }

  Future<void> _refreshMovieDetail() async {
    setState(() => _loadingDetail = true);

    try {
      final latestMovie = await context
          .read<SocialHubController>()
          .fetchMovieDetail(widget.movie.id);
      if (!mounted) return;

      final requiresPlayerReset =
          latestMovie.bannerUrl != _movie.bannerUrl ||
          latestMovie.posterUrl != _movie.posterUrl ||
          latestMovie.thirdPartyUrl != _movie.thirdPartyUrl;

      if (requiresPlayerReset) {
        await _resetVideoPlayer();
      }

      if (!mounted) return;
      setState(() => _movie = latestMovie);
    } catch (_) {
      // Keep the list item data if the refresh request fails.
    } finally {
      if (mounted) {
        setState(() => _loadingDetail = false);
      }
    }
  }

  Future<void> _resetVideoPlayer() async {
    final controller = _videoController;
    setState(() {
      _videoController = null;
      _videoFuture = null;
      _videoError = null;
      _initializingVideo = false;
    });
    controller?.pause();
    await controller?.dispose();
  }

  Future<void> _pauseVideo() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    if (!controller.value.isPlaying) return;
    await controller.pause();
  }

  void _maybeInitializeVideo(SocialHubController controller) {
    if (!_canWatch(controller)) return;
    if (_videoController != null || _initializingVideo) return;

    final uri = Uri.tryParse(_movie.thirdPartyUrl);
    if (uri == null) {
      setState(
        () => _videoError = AppLocalizer.current.tr(
          'This stream link is not available yet.',
        ),
      );
      return;
    }

    final controllerInstance = VideoPlayerController.networkUrl(
      uri,
      formatHint: _resolveVideoFormat(_movie.thirdPartyUrl),
      httpHeaders: _networkHeaders,
    );

    setState(() {
      _initializingVideo = true;
      _videoError = null;
      _videoController = controllerInstance;
      _videoFuture = controllerInstance
          .initialize()
          .then((_) => controllerInstance.setLooping(false))
          .then((_) {
            if (!mounted) return;
            setState(() {});
          })
          .catchError((Object error) {
            controllerInstance.dispose();
            if (!mounted) return;
            setState(() {
              _videoController = null;
              _videoError = AppLocalizer.current.tr(
                'Unable to load the movie stream right now.',
              );
            });
          })
          .whenComplete(() {
            if (!mounted) return;
            setState(() => _initializingVideo = false);
          });
    });
  }

  Future<void> _subscribe(MoviePlanModel plan) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await context.read<SocialHubController>().subscribeToMoviePlan(plan.id);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            context.tr('{plan} is now active for this account.', {
              'plan': context.tr(plan.name),
            }),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.tr('Could not activate the plan right now.')),
        ),
      );
    }
  }

  Future<void> _restartVideo() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    await controller.seekTo(Duration.zero);
    await controller.play();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(context.tr(message)),
      ),
    );
  }

  Future<void> _scrollToSection(GlobalKey key) async {
    final currentContext = key.currentContext;
    if (currentContext == null) return;
    await Scrollable.ensureVisible(
      currentContext,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.12,
    );
  }

  Future<void> _handlePrimaryWatch(SocialHubController controller) async {
    if (!_canWatch(controller)) {
      await _scrollToSection(_lockedSectionKey);
      return;
    }

    setState(() => _requestedPlayback = true);
    _maybeInitializeVideo(controller);

    if (_videoController?.value.isInitialized == true &&
        _videoController?.value.isPlaying != true) {
      await _videoController?.play();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToSection(_playerSectionKey);
    });
  }

  Future<void> _copyMovieLink() async {
    final link = _movie.thirdPartyUrl.trim();
    if (link.isEmpty) {
      _showMessage('This stream link is not available yet.');
      return;
    }

    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    _showMessage('Movie link copied.');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _pauseVideo();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoController?.pause();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialHubController>();
    final unlocked = _canWatch(social);
    final activePlan = social.activeSubscription;
    final primaryPlan = social.moviePlans.isNotEmpty
        ? social.moviePlans.first
        : null;

    return PopScope<void>(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _videoController?.pause();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: MetroPageBackground(
          child: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 132),
              children: [
                _MovieHero(
                  movie: _movie,
                  unlocked: unlocked,
                  loadingDetail: _loadingDetail,
                  onBack: () {
                    _videoController?.pause();
                    Navigator.of(context).maybePop();
                  },
                  onPlay: () => _handlePrimaryWatch(social),
                  onShare: _copyMovieLink,
                ),
                const SizedBox(height: 16),
                _MovieMetaCard(
                  movie: _movie,
                  activePlan: activePlan,
                  unlocked: unlocked,
                  onPlay: () => _handlePrimaryWatch(social),
                  onCopyLink: _copyMovieLink,
                  onShowMessage: _showMessage,
                ),
                if (unlocked &&
                    (_requestedPlayback ||
                        _videoController != null ||
                        _initializingVideo ||
                        _videoError != null)) ...[
                  const SizedBox(height: 16),
                  Container(
                    key: _playerSectionKey,
                    child: _MoviePlayerCard(
                      controller: _videoController,
                      videoFuture: _videoFuture,
                      initializing: _initializingVideo,
                      errorMessage: _videoError,
                      onRestart: _restartVideo,
                    ),
                  ),
                ],
                if (!unlocked) ...[
                  const SizedBox(height: 16),
                  Container(
                    key: _lockedSectionKey,
                    child: _MovieLockedCard(
                      activePlan: activePlan,
                      plans: social.moviePlans,
                      submitting: social.submitting,
                      onSubscribe: _subscribe,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _MovieCastCard(movie: _movie),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: FilledButton.icon(
              onPressed: unlocked
                  ? () => _handlePrimaryWatch(social)
                  : primaryPlan == null || social.submitting
                  ? null
                  : () => _subscribe(primaryPlan),
              style: FilledButton.styleFrom(
                backgroundColor: kMetroCoral,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              icon: Icon(
                unlocked
                    ? Icons.play_circle_fill_rounded
                    : Icons.workspace_premium_rounded,
              ),
              label: Text(
                context.tr(unlocked ? 'Watch now' : 'Activate'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MovieHero extends StatelessWidget {
  const _MovieHero({
    required this.movie,
    required this.unlocked,
    required this.loadingDetail,
    required this.onBack,
    required this.onPlay,
    required this.onShare,
  });

  final MovieItem movie;
  final bool unlocked;
  final bool loadingDetail;
  final VoidCallback onBack;
  final VoidCallback onPlay;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final meta = movieShowcaseMeta(movie);
    final imageUrl = movie.bannerUrl.isNotEmpty
        ? movie.bannerUrl
        : movie.posterUrl;

    return SizedBox(
      height: 460,
      child: MetroImageFrame(
        borderColor: kMetroCoral,
        imageUrl: imageUrl,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        overlayTop: const Color(0x12000000),
        overlayBottom: const Color(0xEA111724),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Row(
                children: [
                  _MovieHeroActionButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: onBack,
                  ),
                  const Spacer(),
                  if (loadingDetail)
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 10),
                  _MovieHeroActionButton(
                    icon: Icons.share_outlined,
                    onTap: onShare,
                  ),
                ],
              ),
            ),
            Align(
              child: InkWell(
                onTap: onPlay,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: kMetroCoral.withValues(alpha: 0.96),
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x30FF5E88),
                        blurRadius: 28,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (meta.isHd)
                        const MetroBadge(
                          label: 'HD',
                          backgroundColor: Color(0x26000000),
                          foregroundColor: Colors.white,
                          outlined: false,
                        ),
                      const MetroBadge(
                        label: 'Subtitled',
                        backgroundColor: Color(0x26000000),
                        foregroundColor: Colors.white,
                        outlined: false,
                      ),
                      const MetroBadge(
                        label: 'Vietnamese',
                        backgroundColor: Color(0x26000000),
                        foregroundColor: Colors.white,
                        outlined: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr(movie.title),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontSize: 34,
                      height: 1.04,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${meta.year} • ${movieDurationLabel(meta.durationMinutes)} • ${meta.tags.take(2).map(context.tr).join(', ')}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFFD34D),
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        meta.rating.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${movieReviewLabel(meta.reviewCount)} ${context.tr('reviews')}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        context.tr(
                          unlocked ? 'Ready to watch' : 'Subscription',
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.84),
                          fontWeight: FontWeight.w800,
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

class _MovieMetaCard extends StatelessWidget {
  const _MovieMetaCard({
    required this.movie,
    required this.activePlan,
    required this.unlocked,
    required this.onPlay,
    required this.onCopyLink,
    required this.onShowMessage,
  });

  final MovieItem movie;
  final MovieSubscriptionModel? activePlan;
  final bool unlocked;
  final VoidCallback onPlay;
  final VoidCallback onCopyLink;
  final ValueChanged<String> onShowMessage;

  @override
  Widget build(BuildContext context) {
    final meta = movieShowcaseMeta(movie);
    final chips = <Widget>[
      _MovieInfoChip(
        icon: Icons.public_rounded,
        label: movie.thirdPartyProvider.isEmpty
            ? context.tr('Internet library')
            : context.tr(movie.thirdPartyProvider),
      ),
      _MovieInfoChip(
        icon: movie.accessType == 'free'
            ? Icons.lock_open_rounded
            : Icons.workspace_premium_rounded,
        label: context.tr(
          movie.accessType == 'free' ? 'Free access' : 'Monthly access',
        ),
      ),
      if (activePlan?.isActive == true)
        _MovieInfoChip(
          icon: Icons.schedule_rounded,
          label: context.tr('Active until {date}', {
            'date': AppDateUtils.formatDate(activePlan?.endsAt),
          }),
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 26,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  context.tr('About this movie'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 20),
                ),
              ),
              Text(
                '${meta.year} • ${movieDurationLabel(meta.durationMinutes)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: kMetroMuted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            context.tr(movie.summary),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MovieQuickAction(
                  icon: Icons.playlist_add_rounded,
                  label: 'My list',
                  onTap: () => onShowMessage(
                    'Your movie list will sync in the next demo update.',
                  ),
                ),
              ),
              Expanded(
                child: _MovieQuickAction(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Watched',
                  onTap: onPlay,
                ),
              ),
              Expanded(
                child: _MovieQuickAction(
                  icon: Icons.download_rounded,
                  label: 'Download',
                  onTap: () => onShowMessage(
                    'Offline movie download will be connected in the next release.',
                  ),
                ),
              ),
              Expanded(
                child: _MovieQuickAction(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: onCopyLink,
                ),
              ),
            ],
          ),
          if (unlocked) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5F7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFFE1E8)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: kMetroCoralSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.play_circle_fill_rounded,
                      color: kMetroCoral,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr(
                        'Tap Watch now to open the stream player right inside this detail page.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: kMetroInk,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MovieHeroActionButton extends StatelessWidget {
  const _MovieHeroActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _MovieQuickAction extends StatelessWidget {
  const _MovieQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FD),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kMetroLine),
              ),
              child: Icon(icon, color: kMetroInk, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(label),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: kMetroInk,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovieCastCard extends StatelessWidget {
  const _MovieCastCard({required this.movie});

  final MovieItem movie;

  @override
  Widget build(BuildContext context) {
    final meta = movieShowcaseMeta(movie);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 26,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Cast'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: meta.cast.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final member = meta.cast[index];
                return SizedBox(
                  width: 78,
                  child: Column(
                    children: [
                      ClipOval(
                        child: SizedBox(
                          width: 60,
                          height: 60,
                          child: RemoteImage(
                            url: member.avatarUrl,
                            fit: BoxFit.cover,
                            errorFallback: Container(
                              color: const Color(0xFFF4F6FB),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.person_rounded,
                                color: kMetroMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 38,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Text(
                            member.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: kMetroInk,
                                  fontWeight: FontWeight.w700,
                                  height: 1.18,
                                ),
                          ),
                        ),
                      ),
                    ],
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

class _MoviePlayerCard extends StatefulWidget {
  const _MoviePlayerCard({
    required this.controller,
    required this.videoFuture,
    required this.initializing,
    required this.errorMessage,
    required this.onRestart,
  });

  final VideoPlayerController? controller;
  final Future<void>? videoFuture;
  final bool initializing;
  final String? errorMessage;
  final Future<void> Function() onRestart;

  @override
  State<_MoviePlayerCard> createState() => _MoviePlayerCardState();
}

class _MoviePlayerCardState extends State<_MoviePlayerCard> {
  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant _MoviePlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?.removeListener(_handleControllerChanged);
      widget.controller?.addListener(_handleControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _isReady => widget.controller?.value.isInitialized == true;

  bool get _isBusy =>
      widget.initializing || (widget.controller?.value.isBuffering ?? false);

  Future<void> _togglePlayPause() async {
    final controller = widget.controller;
    if (controller == null || !_isReady) return;

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
  }

  Future<void> _seekBy(Duration delta) async {
    final controller = widget.controller;
    if (controller == null || !_isReady) return;

    final duration = controller.value.duration;
    var next = controller.value.position + delta;
    if (next < Duration.zero) {
      next = Duration.zero;
    }
    if (next > duration) {
      next = duration;
    }

    await controller.seekTo(next);
  }

  Future<void> _openFullscreen() async {
    final controller = widget.controller;
    if (controller == null || !_isReady) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _MovieFullscreenScreen(
          controller: controller,
          onRestart: widget.onRestart,
        ),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeController = widget.controller;
    final controllerValue = activeController?.value;
    final isPlaying = controllerValue?.isPlaying == true;
    final isReady = _isReady;
    final isBusy = _isBusy;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF081122),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Now playing'),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isBusy
                ? context.tr('Loading your stream...')
                : isReady
                ? '${_formatPlaybackTime(controllerValue?.position)} / ${_formatPlaybackTime(controllerValue?.duration)}'
                : context.tr('Preparing video controls...'),
            style: const TextStyle(
              color: Color(0xFF8DA3C7),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: activeController?.value.isInitialized == true
                  ? activeController!.value.aspectRatio
                  : 16 / 9,
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Color(0xFF020817)),
                child: Builder(
                  builder: (context) {
                    if (widget.errorMessage != null) {
                      return _PlayerMessage(
                        icon: Icons.warning_amber_rounded,
                        message: widget.errorMessage!,
                      );
                    }
                    if (activeController == null ||
                        widget.videoFuture == null) {
                      return _PlayerLoadingOverlay(
                        message: context.tr('Loading video stream...'),
                      );
                    }

                    return FutureBuilder<void>(
                      future: widget.videoFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done &&
                            !isReady) {
                          return _PlayerLoadingOverlay(
                            message: context.tr('Loading video stream...'),
                          );
                        }

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            VideoPlayer(activeController),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.black.withValues(alpha: 0.04),
                                      Colors.black.withValues(alpha: 0.24),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 12,
                              right: 12,
                              child: _PlayerIconControl(
                                icon: Icons.fullscreen_rounded,
                                onTap: _openFullscreen,
                                enabled: isReady,
                              ),
                            ),
                            Positioned.fill(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: isBusy ? null : _togglePlayPause,
                                  child: Center(
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      child: isBusy
                                          ? const _PlayerLoadingBadge()
                                          : _PlayerCenterButton(
                                              key: ValueKey(isPlaying),
                                              icon: isPlaying
                                                  ? Icons.pause_rounded
                                                  : Icons.play_arrow_rounded,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (isBusy)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: _PlayerLoadingOverlay(
                                    message: context.tr(
                                      'Loading video stream...',
                                    ),
                                    compact: true,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (activeController != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: VideoProgressIndicator(
                activeController,
                allowScrubbing: isReady,
                padding: EdgeInsets.zero,
                colors: const VideoProgressColors(
                  playedColor: Color(0xFF4C9AFF),
                  backgroundColor: Color(0x332B3A50),
                  bufferedColor: Color(0x66728BB4),
                ),
              ),
            )
          else
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0x332B3A50),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                _formatPlaybackTime(controllerValue?.position),
                style: const TextStyle(
                  color: Color(0xFF8DA3C7),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                _formatPlaybackTime(controllerValue?.duration),
                style: const TextStyle(
                  color: Color(0xFF8DA3C7),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _PlayerIconControl(
                icon: Icons.replay_10_rounded,
                onTap: () => _seekBy(const Duration(seconds: -10)),
                enabled: isReady && !isBusy,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PlayerPrimaryControl(
                  icon: isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  label: isPlaying ? 'Pause' : 'Play',
                  onTap: isReady && !isBusy ? _togglePlayPause : null,
                ),
              ),
              const SizedBox(width: 10),
              _PlayerIconControl(
                icon: Icons.restart_alt_rounded,
                onTap: isReady ? widget.onRestart : null,
                enabled: isReady,
              ),
              const SizedBox(width: 10),
              _PlayerIconControl(
                icon: Icons.fullscreen_rounded,
                onTap: _openFullscreen,
                enabled: isReady,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MovieFullscreenScreen extends StatefulWidget {
  const _MovieFullscreenScreen({
    required this.controller,
    required this.onRestart,
  });

  final VideoPlayerController controller;
  final Future<void> Function() onRestart;

  @override
  State<_MovieFullscreenScreen> createState() => _MovieFullscreenScreenState();
}

class _MovieFullscreenScreenState extends State<_MovieFullscreenScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _togglePlayPause() async {
    if (!widget.controller.value.isInitialized) return;

    if (widget.controller.value.isPlaying) {
      await widget.controller.pause();
    } else {
      await widget.controller.play();
    }
  }

  Future<void> _seekBy(Duration delta) async {
    if (!widget.controller.value.isInitialized) return;

    final duration = widget.controller.value.duration;
    var next = widget.controller.value.position + delta;
    if (next < Duration.zero) {
      next = Duration.zero;
    }
    if (next > duration) {
      next = duration;
    }
    await widget.controller.seekTo(next);
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value;
    final isReady = value.isInitialized;
    final isBusy = value.isBuffering;
    final isPlaying = value.isPlaying;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: AspectRatio(
                  aspectRatio: isReady ? value.aspectRatio : 16 / 9,
                  child: isReady
                      ? VideoPlayer(widget.controller)
                      : _PlayerLoadingOverlay(
                          message: context.tr('Loading fullscreen player...'),
                        ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.38),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.42),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.45, 1],
                  ),
                ),
              ),
            ),
            if (isBusy)
              Positioned.fill(
                child: IgnorePointer(
                  child: _PlayerLoadingOverlay(
                    message: context.tr('Buffering video...'),
                    compact: true,
                  ),
                ),
              ),
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  _PlayerIconControl(
                    icon: Icons.arrow_back_rounded,
                    onTap: () async => Navigator.of(context).pop(),
                    enabled: true,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    context.tr('Fullscreen'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_formatPlaybackTime(value.position)} / ${_formatPlaybackTime(value.duration)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isBusy ? null : _togglePlayPause,
                  child: Center(
                    child: isBusy
                        ? const _PlayerLoadingBadge()
                        : _PlayerCenterButton(
                            icon: isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 18,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: VideoProgressIndicator(
                      widget.controller,
                      allowScrubbing: isReady,
                      padding: EdgeInsets.zero,
                      colors: const VideoProgressColors(
                        playedColor: Color(0xFF4C9AFF),
                        backgroundColor: Color(0x332B3A50),
                        bufferedColor: Color(0x66728BB4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _PlayerIconControl(
                        icon: Icons.replay_10_rounded,
                        onTap: () => _seekBy(const Duration(seconds: -10)),
                        enabled: isReady && !isBusy,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PlayerPrimaryControl(
                          icon: isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          label: isPlaying ? 'Pause' : 'Play',
                          onTap: isReady && !isBusy ? _togglePlayPause : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _PlayerIconControl(
                        icon: Icons.restart_alt_rounded,
                        onTap: isReady ? widget.onRestart : null,
                        enabled: isReady,
                      ),
                      const SizedBox(width: 10),
                      _PlayerIconControl(
                        icon: Icons.fullscreen_exit_rounded,
                        onTap: () async => Navigator.of(context).pop(),
                        enabled: true,
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

String _formatPlaybackTime(Duration? duration) {
  final value = duration ?? Duration.zero;
  final totalSeconds = value.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

class _PlayerPrimaryControl extends StatelessWidget {
  const _PlayerPrimaryControl({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Material(
      color: enabled ? const Color(0xFF2D7BEA) : const Color(0xFF26415F),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                context.tr(label),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
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

class _PlayerIconControl extends StatelessWidget {
  const _PlayerIconControl({
    required this.icon,
    required this.onTap,
    required this.enabled,
  });

  final IconData icon;
  final Future<void> Function()? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 54,
          height: 54,
          child: Icon(
            icon,
            color: enabled ? Colors.white : const Color(0xFF607389),
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _PlayerCenterButton extends StatelessWidget {
  const _PlayerCenterButton({required this.icon, super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Icon(icon, color: Colors.white, size: 34),
      ),
    );
  }
}

class _PlayerLoadingBadge extends StatelessWidget {
  const _PlayerLoadingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.52),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: const Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Colors.white,
            ),
          ),
          Icon(Icons.movie_creation_outlined, color: Colors.white, size: 18),
        ],
      ),
    );
  }
}

class _PlayerLoadingOverlay extends StatelessWidget {
  const _PlayerLoadingOverlay({required this.message, this.compact = false});

  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: compact ? 0.28 : 0.42),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _PlayerLoadingBadge(),
              const SizedBox(height: 12),
              Text(
                context.tr(message),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovieLockedCard extends StatelessWidget {
  const _MovieLockedCard({
    required this.activePlan,
    required this.plans,
    required this.submitting,
    required this.onSubscribe,
  });

  final MovieSubscriptionModel? activePlan;
  final List<MoviePlanModel> plans;
  final bool submitting;
  final Future<void> Function(MoviePlanModel plan) onSubscribe;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 26,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4DF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFC78720),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  activePlan?.isActive == true
                      ? context.tr(
                          'Your plan is active. Refresh this page or reopen the movie to start streaming.',
                        )
                      : context.tr(
                          'This title is part of the monthly movie access plan.',
                        ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(height: 1.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...plans.map(
            (plan) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F8FE),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr(plan.name),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr('{currency} {price} for {days} days', {
                              'currency': plan.currency,
                              'price': plan.price.toStringAsFixed(2),
                              'days': '${plan.durationDays}',
                            }),
                          ),
                          if (plan.description.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              context.tr(plan.description),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: submitting ? null : () => onSubscribe(plan),
                      child: Text(context.tr('Activate')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MovieInfoChip extends StatelessWidget {
  const _MovieInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF1B74E4)),
          const SizedBox(width: 7),
          Text(
            context.tr(label),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PlayerMessage extends StatelessWidget {
  const _PlayerMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 34),
            const SizedBox(height: 12),
            Text(
              context.tr(message),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
