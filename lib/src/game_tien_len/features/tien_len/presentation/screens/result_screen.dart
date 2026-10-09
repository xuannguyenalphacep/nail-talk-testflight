import 'package:flutter/material.dart';

import '../../../../core/theme/game_theme.dart';
import '../../../../core/widgets/game_stage.dart';
import '../../../../core/widgets/gpt_button.dart';
import '../../../../core/widgets/profile_chip.dart';
import '../../data/game_data.dart';
import 'lobby_screen.dart';
import 'replay_screen.dart';
import 'waiting_room_screen.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({required this.room, super.key});

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
                  _RoomLabel(room: room),
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
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x99000000),
                      blurRadius: 20,
                      offset: Offset(0, 9),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(34, 22, 34, 24),
                  child: Column(
                    children: <Widget>[
                      const _VictoryHeader(),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: const <Widget>[
                            Expanded(child: _WinSummary()),
                            SizedBox(width: 22),
                            Expanded(child: _ScoreBoard()),
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
                      assetPath: 'assets/game_tien_len/buttons/replay_v2.png',
                      semanticLabel: 'Xem lại ván',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ReplayScreen(room: room),
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

class _RoomLabel extends StatelessWidget {
  const _RoomLabel({required this.room});

  final DemoRoom room;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            room.title,
            style: const TextStyle(
              color: GameTheme.ivory,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            'Kết quả ván demo',
            style: TextStyle(
              color: GameTheme.mint.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _VictoryHeader extends StatelessWidget {
  const _VictoryHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: GameTheme.gold.withValues(alpha: 0.18),
            border: Border.all(color: GameTheme.gold, width: 2),
          ),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.emoji_events, color: GameTheme.gold, size: 42),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Bạn thắng!',
          style: TextStyle(
            color: GameTheme.ivory,
            fontSize: 31,
            fontWeight: FontWeight.w900,
            shadows: <Shadow>[Shadow(color: Colors.black, blurRadius: 9)],
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'Chúc mừng bạn đã về nhất trong ván này',
          style: TextStyle(color: GameTheme.mint, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _WinSummary extends StatelessWidget {
  const _WinSummary();

  @override
  Widget build(BuildContext context) {
    return _ResultPanel(
      title: 'Phần thưởng',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Text(
            '+250 xu',
            style: TextStyle(
              color: GameTheme.gold,
              fontSize: 38,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tiền thắng ván',
            style: TextStyle(
              color: GameTheme.ivory,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xB5071717),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Text(
                'Thời gian · 04:26',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBoard extends StatelessWidget {
  const _ScoreBoard();

  @override
  Widget build(BuildContext context) {
    return _ResultPanel(
      title: 'Bảng xếp hạng',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const <Widget>[
          _RankRow(
            rank: '1',
            name: 'Tây Bích 88',
            result: 'Thắng',
            highlight: true,
          ),
          SizedBox(height: 8),
          _RankRow(rank: '2', name: 'Máy Trẻ', result: 'Còn 2 lá'),
          SizedBox(height: 8),
          _RankRow(rank: '3', name: 'Máy Sấm', result: 'Còn 5 lá'),
        ],
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x7A071B1B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GameTheme.mint.withValues(alpha: 0.32)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                color: GameTheme.mint,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Divider(color: Color(0x6675D8B4), height: 18),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.name,
    required this.result,
    this.highlight = false,
  });

  final String rank;
  final String name;
  final String result;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlight ? const Color(0xA64B3A16) : const Color(0x6E173B35),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: highlight
              ? GameTheme.gold.withValues(alpha: 0.65)
              : Colors.white10,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: <Widget>[
            Text(
              rank,
              style: TextStyle(
                color: highlight ? GameTheme.gold : Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              result,
              style: TextStyle(
                color: highlight ? GameTheme.gold : GameTheme.mint,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
