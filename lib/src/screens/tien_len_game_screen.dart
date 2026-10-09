import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/session_controller.dart';
import '../game_tien_len/core/audio/game_audio.dart';
import '../game_tien_len/core/theme/game_theme.dart';
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
  void dispose() {
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    GameAudio.stopLobbyMusic();
    super.dispose();
  }

  Future<void> _handleBack() async {
    final gameNavigator = _gameNavigatorKey.currentState;
    if (gameNavigator != null && await gameNavigator.maybePop()) {
      return;
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _closeGame() {
    Navigator.of(context).pop();
  }

  Future<void> _prepareGame() async {
    if (_prepared || !mounted) return;
    final session = context.read<SessionController>();
    if (!session.isLoggedIn) return;
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
    final session = context.watch<SessionController>();
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
          body: Stack(
            children: [
              Positioned.fill(
                child: session.isLoggedIn
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
              Positioned(
                top: MediaQuery.paddingOf(context).top + 10,
                left: 12,
                child: _GameCloseButton(onPressed: _closeGame),
              ),
            ],
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
  const _GameCloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: IconButton(
        tooltip: 'Đóng game',
        onPressed: onPressed,
        icon: const Icon(Icons.close_rounded, color: Colors.white),
      ),
    );
  }
}
