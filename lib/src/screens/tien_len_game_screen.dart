import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game_tien_len/core/audio/game_audio.dart';
import '../game_tien_len/core/theme/game_theme.dart';
import '../game_tien_len/features/tien_len/presentation/screens/home_screen.dart';

class TienLenGameScreen extends StatefulWidget {
  const TienLenGameScreen({super.key});

  @override
  State<TienLenGameScreen> createState() => _TienLenGameScreenState();
}

class _TienLenGameScreenState extends State<TienLenGameScreen> {
  final GlobalKey<NavigatorState> _gameNavigatorKey =
      GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    GameAudio.startLobbyMusic();
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

  @override
  Widget build(BuildContext context) {
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
                child: Navigator(
                  key: _gameNavigatorKey,
                  onGenerateRoute: (_) {
                    return MaterialPageRoute<void>(
                      builder: (_) => const HomeScreen(),
                    );
                  },
                ),
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
