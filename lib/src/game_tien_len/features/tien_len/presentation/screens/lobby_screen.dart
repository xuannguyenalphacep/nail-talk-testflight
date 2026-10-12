import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../controllers/session_controller.dart';
import '../../../../core/audio/game_audio.dart';
import '../../../../core/widgets/game_stage.dart';
import '../../../../core/widgets/gpt_button.dart';
import '../../../../core/widgets/profile_chip.dart';
import '../../data/game_data.dart';
import 'home_screen.dart';
import 'waiting_room_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  bool _openingRoom = false;

  Future<void> _openRoom(BuildContext context, DemoRoom room) async {
    if (_openingRoom) return;
    setState(() => _openingRoom = true);
    GameAudio.enterRoom();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => WaitingRoomScreen(room: room)),
    );
    if (mounted) setState(() => _openingRoom = false);
  }

  void _backToHome(BuildContext context) {
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((Route<dynamic> route) => route.isFirst);
      return;
    }
    navigator.pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final playerName = session.user?.name.trim().isNotEmpty == true
        ? session.user!.name
        : 'Người chơi';
    final playerCoins = session.user?.gameCoins ?? 0;
    return GameStage(
      backgroundAsset: 'assets/game_tien_len/backgrounds/lobby_stage.png',
      stageWidth: 1672,
      stageHeight: 941,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(44, 26, 44, 32),
        child: Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ProfileChip(name: playerName, balance: playerCoins),
                SizedBox(
                  width: 355,
                  height: 110,
                  child: Image.asset(
                    'assets/game_tien_len/branding/title.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 215),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 0, bottom: 0),
              child: SizedBox(
                width: 650,
                height: 210,
                child: Image.asset(
                  'assets/game_tien_len/branding/lobby_heading.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: demoRooms
                    .map(
                      (DemoRoom room) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 7),
                          child: Column(
                            children: <Widget>[
                              Expanded(
                                child: GptButton(
                                  assetPath: room.buttonAsset,
                                  semanticLabel: room.title,
                                  onPressed: _openingRoom
                                      ? null
                                      : () => _openRoom(context, room),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            SizedBox(
              width: 300,
              height: 82,
              child: GptButton(
                assetPath: 'assets/game_tien_len/buttons/back_lobby_v2.png',
                semanticLabel: 'Quay lại sảnh',
                onPressed: () => _backToHome(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
