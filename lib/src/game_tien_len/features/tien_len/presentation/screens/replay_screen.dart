import 'package:flutter/material.dart';

import '../../../../core/theme/game_theme.dart';
import '../../../../core/widgets/game_stage.dart';
import '../../../../core/widgets/gpt_button.dart';
import '../../../../core/widgets/profile_chip.dart';
import '../../data/game_data.dart';
import 'lobby_screen.dart';
import 'waiting_room_screen.dart';

class ReplayScreen extends StatelessWidget {
  const ReplayScreen({required this.room, super.key});

  final DemoRoom room;

  void _backToLobby(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LobbyScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GameStage(
      backgroundAsset: 'assets/game_tien_len/backgrounds/table_stage.png',
      stageWidth: 1659,
      stageHeight: 948,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(34, 24, 34, 28),
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 68,
              child: Row(
                children: <Widget>[
                  const ProfileChip(name: 'Tây Bích 88', balance: 12750),
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: 290,
                        height: 82,
                        child: Image.asset(
                          'assets/game_tien_len/branding/title.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    '${room.title} · Nhật ký ván',
                    style: const TextStyle(
                      color: GameTheme.ivory,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xE20A2E29),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: GameTheme.gold.withValues(alpha: 0.75),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 22, 32, 24),
                  child: Column(
                    children: <Widget>[
                      const Text(
                        'Xem lại ván',
                        style: TextStyle(
                          color: GameTheme.ivory,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Các lượt đánh trong ván vừa hoàn thành',
                        style: TextStyle(
                          color: GameTheme.mint,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: const <Widget>[
                            Expanded(child: _ReplayTimeline()),
                            SizedBox(width: 22),
                            Expanded(child: _ReplayTip()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 92,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: GptButton(
                      assetPath: 'assets/game_tien_len/buttons/rematch.png',
                      semanticLabel: 'Chơi lại',
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => WaitingRoomScreen(room: room),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: GptButton(
                      assetPath:
                          'assets/game_tien_len/buttons/back_lobby_v2.png',
                      semanticLabel: 'Quay lại sảnh',
                      onPressed: () => _backToLobby(context),
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

class _ReplayTimeline extends StatelessWidget {
  const _ReplayTimeline();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x7A071B1B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GameTheme.mint.withValues(alpha: 0.32)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
        child: Column(
          children: <Widget>[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Diễn biến chính',
                style: TextStyle(
                  color: GameTheme.mint,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                children: const <Widget>[
                  _ReplayEvent(
                    time: '00:18',
                    player: 'Tây Bích 88',
                    move: 'Đánh 3♥ 4♣ 5♦',
                  ),
                  _ReplayEvent(
                    time: '00:31',
                    player: 'Minh Khang',
                    move: 'Đánh 6♠ 7♥ 8♣',
                  ),
                  _ReplayEvent(
                    time: '00:47',
                    player: 'Lan Anh',
                    move: 'Bỏ lượt',
                  ),
                  _ReplayEvent(
                    time: '01:12',
                    player: 'Tây Bích 88',
                    move: 'Đánh đôi J♥ Q♣',
                  ),
                  _ReplayEvent(
                    time: '01:38',
                    player: 'Tây Bích 88',
                    move: 'Về nhất · +250 xu',
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

class _ReplayEvent extends StatelessWidget {
  const _ReplayEvent({
    required this.time,
    required this.player,
    required this.move,
  });

  final String time;
  final String player;
  final String move;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 55,
            child: Text(
              time,
              style: const TextStyle(
                color: GameTheme.gold,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  player,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  move,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplayTip extends StatelessWidget {
  const _ReplayTip();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x7A071B1B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GameTheme.gold.withValues(alpha: 0.32)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const <Widget>[
            Icon(Icons.auto_awesome, color: GameTheme.gold, size: 40),
            SizedBox(height: 12),
            Text(
              'Bản ghi ván chơi',
              style: TextStyle(
                color: GameTheme.ivory,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Luồng xem lại này sẽ nối với lịch sử trận đấu online khi tích hợp dữ liệu thật.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}
