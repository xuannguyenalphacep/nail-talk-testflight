import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../controllers/social_hub_controller.dart';
import '../core/utils/app_date_utils.dart';
import '../models/movie_item.dart';
import '../models/movie_plan_model.dart';
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
  String? _videoError;
  late MovieItem _movie;

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
      setState(() => _videoError = 'This stream link is not available yet.');
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
              _videoError = 'Unable to load the movie stream right now.';
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
        SnackBar(content: Text('${plan.name} is now active for this account.')),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not activate the plan right now.')),
      );
    }
  }

  Future<void> _restartVideo() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    await controller.seekTo(Duration.zero);
    await controller.play();
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

    if (unlocked && _videoController == null && !_initializingVideo) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _maybeInitializeVideo(context.read<SocialHubController>());
      });
    }

    return PopScope<void>(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _videoController?.pause();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () {
              _videoController?.pause();
              Navigator.of(context).maybePop();
            },
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(_movie.title),
          actions: [
            if (_loadingDetail)
              const Padding(
                padding: EdgeInsets.only(right: 18),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _MovieHero(movie: _movie),
            const SizedBox(height: 16),
            _MovieMetaCard(movie: _movie, activePlan: activePlan),
            const SizedBox(height: 16),
            if (unlocked)
              _MoviePlayerCard(
                controller: _videoController,
                videoFuture: _videoFuture,
                initializing: _initializingVideo,
                errorMessage: _videoError,
                onRestart: _restartVideo,
              )
            else
              _MovieLockedCard(
                activePlan: activePlan,
                plans: social.moviePlans,
                submitting: social.submitting,
                onSubscribe: _subscribe,
              ),
          ],
        ),
      ),
    );
  }
}

class _MovieHero extends StatelessWidget {
  const _MovieHero({required this.movie});

  final MovieItem movie;

  @override
  Widget build(BuildContext context) {
    final imageUrl = movie.bannerUrl.isNotEmpty
        ? movie.bannerUrl
        : movie.posterUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: imageUrl.isEmpty
                ? Container(
                    color: const Color(0xFF173A70),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.movie_creation_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  )
                : RemoteImage(
                    url: imageUrl,
                    fit: BoxFit.cover,
                    errorFallback:
                        movie.posterUrl.isNotEmpty &&
                            movie.posterUrl != imageUrl
                        ? RemoteImage(url: movie.posterUrl, fit: BoxFit.cover)
                        : Container(
                            color: const Color(0xFF173A70),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.movie_creation_rounded,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                  ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF09111E).withValues(alpha: 0.12),
                    const Color(0xFF09111E).withValues(alpha: 0.84),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    movie.category?.name.isNotEmpty == true
                        ? movie.category!.name
                        : 'Movie feature',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  movie.title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    height: 1.08,
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

class _MovieMetaCard extends StatelessWidget {
  const _MovieMetaCard({required this.movie, required this.activePlan});

  final MovieItem movie;
  final MovieSubscriptionModel? activePlan;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _MovieInfoChip(
        icon: Icons.public_rounded,
        label: movie.thirdPartyProvider.isEmpty
            ? 'Internet library'
            : movie.thirdPartyProvider,
      ),
      _MovieInfoChip(
        icon: movie.accessType == 'free'
            ? Icons.lock_open_rounded
            : Icons.workspace_premium_rounded,
        label: movie.accessType == 'free' ? 'Free access' : 'Monthly access',
      ),
      if (activePlan?.isActive == true)
        _MovieInfoChip(
          icon: Icons.schedule_rounded,
          label: 'Active until ${AppDateUtils.formatDate(activePlan?.endsAt)}',
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
          Text(
            'About this movie',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 10),
          Text(
            movie.summary,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
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
          const Text(
            'Now playing',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isBusy
                ? 'Loading your stream...'
                : isReady
                ? '${_formatPlaybackTime(controllerValue?.position)} / ${_formatPlaybackTime(controllerValue?.duration)}'
                : 'Preparing video controls...',
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
                      return const _PlayerLoadingOverlay(
                        message: 'Loading video stream...',
                      );
                    }

                    return FutureBuilder<void>(
                      future: widget.videoFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done &&
                            !isReady) {
                          return const _PlayerLoadingOverlay(
                            message: 'Loading video stream...',
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
                              const Positioned.fill(
                                child: IgnorePointer(
                                  child: _PlayerLoadingOverlay(
                                    message: 'Loading video stream...',
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
                      : const _PlayerLoadingOverlay(
                          message: 'Loading fullscreen player...',
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
              const Positioned.fill(
                child: IgnorePointer(
                  child: _PlayerLoadingOverlay(
                    message: 'Buffering video...',
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
                  const Text(
                    'Fullscreen',
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
                label,
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
                message,
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
                      ? 'Your plan is active. Refresh this page or reopen the movie to start streaming.'
                      : 'This title is part of the monthly movie access plan.',
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
                            plan.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${plan.currency} ${plan.price.toStringAsFixed(2)} for ${plan.durationDays} days',
                          ),
                          if (plan.description.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              plan.description,
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
                      child: const Text('Activate'),
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
            label,
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
              message,
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
