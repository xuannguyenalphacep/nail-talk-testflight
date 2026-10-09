import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/audio/game_audio.dart';
import '../../../../core/theme/game_theme.dart';
import '../../../../core/widgets/game_stage.dart';
import '../../../../core/widgets/gpt_button.dart';
import '../../../../core/widgets/profile_chip.dart';
import '../../data/game_data.dart';
import 'table_screen.dart';

class WaitingRoomScreen extends StatefulWidget {
  const WaitingRoomScreen({
    required this.room,
    this.initialOpponentCount = 0,
    this.hostName = 'Tây Bích 88',
    this.entryLabel,
    super.key,
  });

  final DemoRoom room;
  final int initialOpponentCount;
  final String hostName;
  final String? entryLabel;

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  static const int _autoStartDelaySeconds = 15;
  static const int _neededOpponents = 3;
  static const List<int> _joinMilestones = <int>[4, 8, 12];

  Timer? _autoStartTimer;
  bool _isReady = false;
  late int _joinedOpponents;
  int _opponentJoinRemaining = _joinMilestones.first;
  int _autoStartRemaining = _autoStartDelaySeconds;
  late String _status;

  @override
  void initState() {
    super.initState();
    _joinedOpponents = widget.initialOpponentCount
        .clamp(0, _neededOpponents)
        .toInt();
    _opponentJoinRemaining = _secondsUntilNextJoin(_autoStartRemaining);
    _status = _countdownStatus();
    _startAutoStartTimer();
  }

  @override
  void dispose() {
    _autoStartTimer?.cancel();
    super.dispose();
  }

  int _secondsUntilNextJoin(int remainingSeconds) {
    if (_joinedOpponents >= _neededOpponents) {
      return 0;
    }
    final int elapsedSeconds = _autoStartDelaySeconds - remainingSeconds;
    final int nextMilestone = _joinMilestones[_joinedOpponents];
    return math.max(1, nextMilestone - elapsedSeconds);
  }

  int _matchedOpponentsForRemaining(int remainingSeconds) {
    final int elapsedSeconds = _autoStartDelaySeconds - remainingSeconds;
    int matchedOpponents = widget.initialOpponentCount
        .clamp(0, _neededOpponents)
        .toInt();
    for (
      int index = matchedOpponents;
      index < _joinMilestones.length;
      index++
    ) {
      if (elapsedSeconds >= _joinMilestones[index]) {
        matchedOpponents = index + 1;
      }
    }
    return matchedOpponents.clamp(0, _neededOpponents).toInt();
  }

  String _countdownStatus() {
    final String prefix = _joinedOpponents >= _neededOpponents
        ? 'Đủ người chơi'
        : 'Đang ghép ${_joinedOpponents + 1}/4 người chơi';
    final String tableLabel = widget.entryLabel == null
        ? ''
        : '${widget.entryLabel} · ';
    return '$tableLabel$prefix · Chủ phòng ${widget.hostName} sẽ start sau $_autoStartRemaining giây';
  }

  void _startAutoStartTimer() {
    _autoStartTimer?.cancel();
    _autoStartTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        return;
      }
      if (_autoStartRemaining <= 1) {
        timer.cancel();
        setState(() {
          _joinedOpponents = _neededOpponents;
          _opponentJoinRemaining = 0;
          _autoStartRemaining = 0;
          _status = 'Đủ người chơi · Chủ phòng ${widget.hostName} đang start';
        });
        _startGame(autoStart: true);
        return;
      }
      setState(() {
        _autoStartRemaining--;
        _joinedOpponents = _matchedOpponentsForRemaining(_autoStartRemaining);
        _opponentJoinRemaining = _secondsUntilNextJoin(_autoStartRemaining);
        _status = _countdownStatus();
      });
    });
  }

  void _toggleReady() {
    setState(() {
      _isReady = !_isReady;
      _status = _isReady
          ? 'Bạn đã sẵn sàng · Chủ phòng ${widget.hostName} sẽ start sau $_autoStartRemaining giây'
          : _countdownStatus();
    });
  }

  void _inviteFriend() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Đã tạo lời mời cho bạn bè.')));
  }

  void _startGame({bool autoStart = false}) {
    if (_joinedOpponents < _neededOpponents) {
      setState(
        () => _status =
            'Chưa đủ người · Chủ phòng ${widget.hostName} sẽ start sau $_autoStartRemaining giây',
      );
      return;
    }
    _autoStartTimer?.cancel();
    GameAudio.enterRoom();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => TableScreen(room: widget.room)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GameStage(
      backgroundAsset: 'assets/game_tien_len/backgrounds/lobby_stage.png',
      stageWidth: 1672,
      stageHeight: 941,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(44, 24, 44, 28),
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 104,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const ProfileChip(name: 'Tây Bích 88', balance: 12500),
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: 330,
                        height: 104,
                        child: Image.asset(
                          'assets/game_tien_len/branding/title.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 250,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: _RoomBadge(room: widget.room),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _WaitingPanel(
                room: widget.room,
                isReady: _isReady,
                joinedOpponents: _joinedOpponents,
                opponentJoinRemaining: _opponentJoinRemaining,
                autoStartRemaining: _autoStartRemaining,
                status: _status,
                hostName: widget.hostName,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 94,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: GptButton(
                      assetPath: _isReady
                          ? 'assets/game_tien_len/buttons/cancel_ready.png'
                          : 'assets/game_tien_len/buttons/ready.png',
                      semanticLabel: _isReady ? 'Hủy sẵn sàng' : 'Sẵn sàng',
                      onPressed: _toggleReady,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GptButton(
                      assetPath:
                          'assets/game_tien_len/buttons/invite_friend.png',
                      semanticLabel: 'Mời bạn',
                      onPressed: _inviteFriend,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GptButton(
                      assetPath: 'assets/game_tien_len/buttons/leave_room.png',
                      semanticLabel: 'Rời phòng',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GptButton(
                      assetPath: 'assets/game_tien_len/buttons/start_game.png',
                      semanticLabel: 'Bắt đầu chơi',
                      onPressed: _joinedOpponents >= _neededOpponents
                          ? () => _startGame()
                          : null,
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

class _RoomBadge extends StatelessWidget {
  const _RoomBadge({required this.room});

  final DemoRoom room;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xD90B2C28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GameTheme.gold.withValues(alpha: 0.62)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              room.title,
              style: const TextStyle(
                color: GameTheme.ivory,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Cược bàn: ${room.stakeLabel}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: GameTheme.mint,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaitingPanel extends StatelessWidget {
  const _WaitingPanel({
    required this.room,
    required this.isReady,
    required this.joinedOpponents,
    required this.opponentJoinRemaining,
    required this.autoStartRemaining,
    required this.status,
    required this.hostName,
  });

  final DemoRoom room;
  final bool isReady;
  final int joinedOpponents;
  final int opponentJoinRemaining;
  final int autoStartRemaining;
  final String status;
  final String hostName;

  bool get _isHostedByUser => hostName == 'Tây Bích 88';

  String _seatName(int seatNumber) {
    if (_isHostedByUser) {
      return switch (seatNumber) {
        1 => 'Minh Khang',
        2 => 'Lan Anh',
        _ => 'Hoàng Nam',
      };
    }
    return switch (seatNumber) {
      1 => hostName,
      2 => 'Minh Khang',
      _ => 'Lan Anh',
    };
  }

  String _seatDetail(int seatNumber) {
    if (!_isHostedByUser && seatNumber == 1) {
      return 'Chủ phòng · Sẵn sàng';
    }
    return 'Đã vào · Sẵn sàng';
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xBA082D29),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: GameTheme.gold.withValues(alpha: 0.7)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x88000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.meeting_room, color: GameTheme.gold, size: 28),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Phòng chờ · Ghép người chơi',
                    style: TextStyle(
                      color: GameTheme.ivory,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      shadows: <Shadow>[
                        Shadow(color: Colors.black, blurRadius: 8),
                      ],
                    ),
                  ),
                ),
                _CounterBadge(
                  joinedOpponents: joinedOpponents,
                  opponentJoinRemaining: opponentJoinRemaining,
                  autoStartRemaining: autoStartRemaining,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: _SeatCard(
                      name: 'Tây Bích 88',
                      detail: isReady
                          ? 'Bạn · Đã sẵn sàng'
                          : _isHostedByUser
                          ? 'Bạn · Chủ bàn'
                          : 'Bạn · Khách vào bàn',
                      icon: Icons.person,
                      isReady: isReady,
                      isPlayer: true,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _SeatCard(
                      name: joinedOpponents >= 1
                          ? _seatName(1)
                          : 'Đang tìm người',
                      detail: joinedOpponents >= 1
                          ? _seatDetail(1)
                          : 'Ghép sau ${opponentJoinRemaining}s',
                      icon: joinedOpponents >= 1
                          ? Icons.person
                          : Icons.hourglass_top,
                      isReady: joinedOpponents >= 1,
                      muted: joinedOpponents < 1,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _SeatCard(
                      name: joinedOpponents >= 2 ? _seatName(2) : 'Chỗ trống',
                      detail: joinedOpponents >= 2
                          ? _seatDetail(2)
                          : 'Người chơi thực',
                      icon: joinedOpponents >= 2
                          ? Icons.person
                          : Icons.person_add_alt_1,
                      isReady: joinedOpponents >= 2,
                      muted: joinedOpponents < 2,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _SeatCard(
                      name: joinedOpponents >= 3 ? _seatName(3) : 'Chỗ trống',
                      detail: joinedOpponents >= 3
                          ? _seatDetail(3)
                          : 'Người chơi thực',
                      icon: joinedOpponents >= 3
                          ? Icons.person
                          : Icons.person_add_alt_1,
                      isReady: joinedOpponents >= 3,
                      muted: joinedOpponents < 3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xB3071717),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: GameTheme.mint.withValues(alpha: 0.28),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      joinedOpponents >= 3
                          ? Icons.play_circle_fill
                          : Icons.search,
                      color: joinedOpponents >= 3
                          ? GameTheme.mint
                          : GameTheme.gold,
                      size: 20,
                    ),
                    const SizedBox(width: 9),
                    Flexible(
                      child: Text(
                        '$status · Cược ${room.stakeLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CounterBadge extends StatelessWidget {
  const _CounterBadge({
    required this.joinedOpponents,
    required this.opponentJoinRemaining,
    required this.autoStartRemaining,
  });

  final int joinedOpponents;
  final int opponentJoinRemaining;
  final int autoStartRemaining;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xC9085C4F),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: GameTheme.mint.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        child: Text(
          joinedOpponents >= 3
              ? '4/4 người chơi · Chủ phòng start sau ${autoStartRemaining}s'
              : '${joinedOpponents + 1}/4 người chơi · Ghép thêm sau ${opponentJoinRemaining}s',
          style: const TextStyle(
            color: GameTheme.ivory,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SeatCard extends StatelessWidget {
  const _SeatCard({
    required this.name,
    required this.detail,
    required this.icon,
    required this.isReady,
    this.isPlayer = false,
    this.muted = false,
  });

  final String name;
  final String detail;
  final IconData icon;
  final bool isReady;
  final bool isPlayer;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final Color accent = muted
        ? Colors.white38
        : isReady
        ? GameTheme.mint
        : GameTheme.gold;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: muted ? const Color(0x55203C37) : const Color(0x92203934),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            CircleAvatar(
              radius: 30,
              backgroundColor: accent.withValues(alpha: 0.18),
              child: Icon(icon, color: accent, size: 30),
            ),
            const SizedBox(height: 10),
            Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: muted ? Colors.white60 : GameTheme.ivory,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (isPlayer) ...<Widget>[
              const SizedBox(height: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xAA071B1B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  child: Text(
                    'Bạn',
                    style: TextStyle(
                      color: GameTheme.ivory,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
