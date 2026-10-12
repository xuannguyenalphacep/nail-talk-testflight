import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/session_controller.dart';
import '../game_tien_len/core/audio/game_audio.dart';
import '../game_tien_len/core/theme/game_theme.dart';
import '../game_tien_len/features/tien_len/data/realtime_game_models.dart';
import '../game_tien_len/features/tien_len/presentation/screens/home_screen.dart';
import '../services/chat_socket_service.dart';
import 'login_screen.dart';

class TienLenGameScreen extends StatefulWidget {
  const TienLenGameScreen({super.key});

  @override
  State<TienLenGameScreen> createState() => _TienLenGameScreenState();
}

class _TienLenGameScreenState extends State<TienLenGameScreen> {
  final GlobalKey<NavigatorState> _gameNavigatorKey =
      GlobalKey<NavigatorState>();
  bool _prepared = false;
  bool _closing = false;
  bool _featureCleanupScheduled = false;
  ChatSocketService? _socketService;
  StreamSubscription<TienLenRoomState>? _roomStateSubscription;
  TienLenRoomState? _latestRoomState;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    GameAudio.startLobbyMusic();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareGame());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final socketService = context.read<ChatSocketService>();
    if (identical(_socketService, socketService)) return;

    unawaited(_roomStateSubscription?.cancel());
    _socketService = socketService;
    _roomStateSubscription = socketService.tienLenRoomStateStream.listen((
      state,
    ) {
      if (!mounted) return;
      final wasDraining = _mustDrainDisabledFeature;
      _latestRoomState = state;

      // Room snapshots can arrive in the same frame that the nested game
      // navigator pushes the realtime table. Rebuilding the whole shell for
      // every turn used to make Flutter reparent/deactivate inherited widgets
      // around that navigator unnecessarily. The shell only consumes room
      // state while a remotely-disabled game is draining its current round.
      final featureEnabled = context
          .read<SessionController>()
          .cardGameFeatureEnabled;
      final isDraining = _mustDrainDisabledFeature;
      if (!featureEnabled && wasDraining != isDraining) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    GameAudio.stopLobbyMusic();
    unawaited(_roomStateSubscription?.cancel());
    unawaited(_leaveSilently());
    super.dispose();
  }

  bool get _mustDrainDisabledFeature {
    final state = _latestRoomState;
    final activeRoomId = _socketService?.activeTienLenRoomId;
    return state != null &&
        activeRoomId != null &&
        state.roomId == activeRoomId &&
        state.mustDrainWhenFeatureDisabled;
  }

  Future<void> _leaveSilently() async {
    try {
      await _socketService?.leaveTienLenRoom();
    } catch (_) {}
  }

  Future<void> _handleBack() async {
    final gameNavigator = _gameNavigatorKey.currentState;
    if (gameNavigator != null && await gameNavigator.maybePop()) {
      return;
    }
    if (mounted) {
      await _leaveAndClose();
    }
  }

  Future<void> _leaveAndClose() async {
    if (_closing) return;
    _closing = true;
    await _leaveSilently();
    if (mounted) Navigator.of(context).pop();
  }

  void _closeGame() {
    unawaited(_leaveAndClose());
  }

  Future<void> _prepareGame() async {
    if (_prepared || !mounted) return;
    final session = context.read<SessionController>();
    if (!session.isLoggedIn || !session.cardGameFeatureEnabled) return;
    _prepared = true;

    try {
      final granted = await session.claimGameDailyCoin();
      if (mounted && granted > 0) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('Đã cộng $granted xu hôm nay.')),
        );
      }
    } catch (_) {
      // Không chặn game nếu API coin đang lỗi.
    }

    if (!mounted) return;

    try {
      final app = session.selectedApp;
      final user = session.user;
      if (app != null && user != null) {
        final socket = context.read<ChatSocketService>();
        if (!socket.isConnected) {
          await socket.connect(
            socketUrl: app.socketUrl,
            user: user,
            notifyApiUrl: session.notifyApiUrl,
            accessToken: session.token!,
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Chưa kết nối được realtime game.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = context
        .select<SessionController, ({bool isLoggedIn, bool featureEnabled})>(
          (session) => (
            isLoggedIn: session.isLoggedIn,
            featureEnabled: session.cardGameFeatureEnabled,
          ),
        );
    final featureEnabled = sessionState.featureEnabled;
    final drainingDisabledFeature =
        !featureEnabled && _mustDrainDisabledFeature;
    final canShowGame = featureEnabled || drainingDisabledFeature;
    if (sessionState.isLoggedIn && featureEnabled && !_prepared) {
      _featureCleanupScheduled = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _prepareGame());
    }
    if (drainingDisabledFeature) {
      _featureCleanupScheduled = false;
    } else if (!featureEnabled && !_featureCleanupScheduled) {
      _featureCleanupScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _leaveSilently();
      });
    }
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Theme(
        data: GameTheme.theme,
        child: Scaffold(
          backgroundColor: const Color(0xFF031622),
          body: SafeArea(
            child: _GameShellLayout(
              onClose: _closeGame,
              notice: drainingDisabledFeature ? const _GameDrainNotice() : null,
              child: !canShowGame
                  ? _GameFeatureUnavailable(onClose: _closeGame)
                  : sessionState.isLoggedIn
                  ? Navigator(
                      key: _gameNavigatorKey,
                      onGenerateRoute: (_) {
                        return MaterialPageRoute<void>(
                          builder: (_) => const HomeScreen(),
                        );
                      },
                    )
                  : _GameLoginRequired(onClose: _closeGame),
            ),
          ),
        ),
      ),
    );
  }
}

class _GameShellLayout extends StatelessWidget {
  const _GameShellLayout({
    required this.onClose,
    required this.child,
    this.notice,
  });

  final VoidCallback onClose;
  final Widget child;
  final Widget? notice;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool useSideRail = constraints.maxWidth >= constraints.maxHeight;
        final Widget viewport = _GameViewport(notice: notice, child: child);

        // Keep one element hierarchy while Android transitions from portrait
        // to the game's forced landscape mode. Switching Row <-> Column moved
        // the GlobalKey-backed Navigator between two parents and could leave a
        // Theme/MediaQuery dependent attached during deactivation.
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Positioned(
              left: useSideRail ? _GameCloseSlot.slotExtent : 0,
              top: useSideRail ? 0 : _GameCloseSlot.slotExtent,
              right: 0,
              bottom: 0,
              child: KeyedSubtree(
                key: const ValueKey<String>('tien-len-game-viewport'),
                child: viewport,
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              right: useSideRail ? null : 0,
              bottom: useSideRail ? 0 : null,
              width: useSideRail ? _GameCloseSlot.slotExtent : null,
              height: useSideRail ? null : _GameCloseSlot.slotExtent,
              child: _GameCloseSlot(onClose: onClose, sideRail: useSideRail),
            ),
          ],
        );
      },
    );
  }
}

class _GameViewport extends StatelessWidget {
  const _GameViewport({required this.child, this.notice});

  final Widget child;
  final Widget? notice;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        child,
        if (notice != null) Positioned(top: 10, right: 12, child: notice!),
      ],
    );
  }
}

class _GameCloseSlot extends StatelessWidget {
  const _GameCloseSlot({required this.onClose, required this.sideRail});

  static const double slotExtent = 68;

  final VoidCallback onClose;
  final bool sideRail;

  @override
  Widget build(BuildContext context) {
    final BorderSide divider = BorderSide(
      color: GameTheme.gold.withValues(alpha: 0.48),
    );

    return Container(
      key: const ValueKey<String>('tien-len-close-slot'),
      width: sideRail ? slotExtent : null,
      height: sideRail ? null : slotExtent,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: sideRail ? Alignment.topCenter : Alignment.centerLeft,
          end: sideRail ? Alignment.bottomCenter : Alignment.centerRight,
          colors: const <Color>[Color(0xFF0A302A), Color(0xFF071E22)],
        ),
        border: Border(
          right: sideRail ? divider : BorderSide.none,
          bottom: sideRail ? BorderSide.none : divider,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x66000000), blurRadius: 16),
        ],
      ),
      child: Align(
        alignment: sideRail ? Alignment.topCenter : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: _GameCloseButton(
            key: const ValueKey<String>('tien-len-close-button'),
            onPressed: onClose,
          ),
        ),
      ),
    );
  }
}

class _GameDrainNotice extends StatelessWidget {
  const _GameDrainNotice();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE61A2523),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x66FFFFFF)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Text(
          'Game đã tắt cho lượt mới · ván hiện tại tiếp tục đến khi quyết toán',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _GameFeatureUnavailable extends StatelessWidget {
  const _GameFeatureUnavailable({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF092E2A),
      child: Center(
        child: SizedBox(
          width: 520,
          child: Card(
            color: const Color(0xFF0A2C27),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videogame_asset_off, size: 52),
                  const SizedBox(height: 16),
                  const Text(
                    'Game bài đang tạm ẩn',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Tính năng này hiện được quản trị viên tắt.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: onClose, child: const Text('Đóng')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GameLoginRequired extends StatelessWidget {
  const _GameLoginRequired({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF092E2A), Color(0xFF191022)],
        ),
      ),
      child: Center(
        child: SizedBox(
          width: 520,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xD90A2C27),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: GameTheme.gold),
              boxShadow: const [
                BoxShadow(color: Color(0x99000000), blurRadius: 28),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_rounded,
                    color: GameTheme.gold,
                    size: 52,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Đăng nhập để chơi game',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: GameTheme.ivory,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Coin và phòng realtime sẽ gắn theo tài khoản của bạn.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Đăng nhập'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: onClose,
                        child: const Text('Đóng'),
                      ),
                    ],
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

class _GameCloseButton extends StatelessWidget {
  const _GameCloseButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xE60B2C28),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: GameTheme.gold.withValues(alpha: 0.72)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x77000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
            BoxShadow(color: Color(0x4438DFFF), blurRadius: 14),
          ],
        ),
        child: IconButton(
          tooltip: 'Đóng game',
          onPressed: onPressed,
          icon: const Icon(Icons.close_rounded, color: GameTheme.ivory),
        ),
      ),
    );
  }
}
