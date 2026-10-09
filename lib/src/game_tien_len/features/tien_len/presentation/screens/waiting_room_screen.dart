import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../controllers/session_controller.dart';
import '../../../../core/audio/game_audio.dart';
import '../../../../core/theme/game_theme.dart';
import '../../../../core/widgets/game_stage.dart';
import '../../../../core/widgets/gpt_button.dart';
import '../../../../core/widgets/profile_chip.dart';
import '../../../../../services/chat_socket_service.dart';
import '../../data/game_data.dart';
import '../../data/realtime_game_models.dart';
import 'table_screen.dart';

class WaitingRoomScreen extends StatefulWidget {
  const WaitingRoomScreen({
    required this.room,
    this.initialOpponentCount = 0,
    this.hostName = 'Tây Bích 88',
    this.entryLabel,
    this.roomId,
    super.key,
  });

  final DemoRoom room;
  final int initialOpponentCount;
  final String hostName;
  final String? entryLabel;
  final String? roomId;

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  static const int _autoStartDelaySeconds = 15;
  static const int _maxBotOpponents = 2;
  static const int _minOpponentsToStart = 1;
  static const List<int> _joinMilestones = <int>[4, 9];

  Timer? _autoStartTimer;
  StreamSubscription<TienLenRoomState>? _roomStateSubscription;
  StreamSubscription<Map<String, dynamic>>? _eventSubscription;
  bool _isReady = false;
  bool _joinedRealtime = false;
  late int _joinedOpponents;
  late int _autoFillLimit;
  late final String _roomId;
  int _opponentJoinRemaining = _joinMilestones.first;
  int _autoStartRemaining = _autoStartDelaySeconds;
  late String _status;
  TienLenRoomState? _roomState;

  @override
  void initState() {
    super.initState();
    _roomId = widget.roomId ?? _generateRoomId();
    _joinedOpponents = widget.initialOpponentCount
        .clamp(0, _maxBotOpponents)
        .toInt();
    _autoFillLimit = _maxBotOpponents;
    _opponentJoinRemaining = _secondsUntilNextJoin(_autoStartRemaining);
    _status = _countdownStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _joinRealtimeRoomOnce();
  }

  @override
  void dispose() {
    _autoStartTimer?.cancel();
    _roomStateSubscription?.cancel();
    _eventSubscription?.cancel();
    super.dispose();
  }

  String _generateRoomId() {
    final int suffix = DateTime.now().millisecondsSinceEpoch % 90000 + 10000;
    return 'NT$suffix';
  }

  bool get _isHostedByUser => widget.hostName == 'Tây Bích 88';

  bool get _isRemoteHost => _roomState?.isHost ?? _isHostedByUser;

  int get _remoteOpponentCount {
    final state = _roomState;
    if (state == null) return _joinedOpponents;
    return state.players.where((player) => player.id != state.viewerId).length;
  }

  String get _playerName {
    final session = context.read<SessionController>();
    final userName = session.user?.name.trim() ?? '';
    final username = session.user?.username.trim() ?? '';
    if (userName.isNotEmpty) return userName;
    if (username.isNotEmpty) return username;
    return 'Tây Bích 88';
  }

  int get _playerCoins {
    return context.read<SessionController>().user?.gameCoins ?? 0;
  }

  Future<void> _joinRealtimeRoomOnce() async {
    if (_joinedRealtime) return;
    _joinedRealtime = true;
    final session = context.read<SessionController>();
    final user = session.user;
    final app = session.selectedApp;
    if (user == null || app == null) {
      setState(() => _status = 'Bạn cần đăng nhập để vào phòng realtime.');
      return;
    }

    final socket = context.read<ChatSocketService>();
    _roomStateSubscription = socket.tienLenRoomStateStream.listen((state) {
      if (!mounted || state.roomId != _roomId) return;
      _applyRemoteState(state);
    });
    _eventSubscription = socket.tienLenEventStream.listen((event) {
      if (!mounted || event['roomId']?.toString() != _roomId) return;
      if (event['event'] == 'kicked') {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Bạn đã bị mời ra khỏi phòng.')),
        );
        Navigator.of(context).maybePop();
      }
    });

    try {
      if (!socket.isConnected) {
        await socket.connect(
          socketUrl: app.socketUrl,
          user: user,
          notifyApiUrl: session.notifyApiUrl,
        );
      }

      final state = widget.roomId == null
          ? await socket.createTienLenRoom(
              roomId: _roomId,
              title: widget.room.title,
              baseBet: widget.room.baseBet,
              userId: user.id,
              name: _playerName,
              coins: _playerCoins,
              maxPlayers: 3,
            )
          : await socket.joinTienLenRoom(
              roomId: _roomId,
              title: widget.room.title,
              baseBet: widget.room.baseBet,
              userId: user.id,
              name: _playerName,
              coins: _playerCoins,
            );
      _applyRemoteState(state);
      _startAutoStartTimer();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = 'Không vào được phòng realtime: ${_shortError(error)}';
      });
    }
  }

  String _shortError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '');
    if (raw.contains('room-already-started')) return 'bàn đã bắt đầu';
    if (raw.contains('room-full')) return 'phòng đã đủ người';
    return raw;
  }

  void _applyRemoteState(TienLenRoomState state) {
    setState(() {
      _roomState = state;
      _joinedOpponents = _remoteOpponentCount.clamp(0, _maxBotOpponents);
      _isReady = state.viewerPlayer?.ready ?? _isReady;
      _status = _remoteStatus(state);
    });

    if (state.isPlaying) {
      _openRealtimeTable(state);
    }
  }

  String _remoteStatus(TienLenRoomState state) {
    if (state.isPlaying) {
      final thinker = state.currentTurnPlayer?.name ?? 'người chơi';
      return '$thinker đang suy nghĩ đánh bài';
    }
    if (state.isRoundEnded) {
      return 'Ván đã kết thúc · chờ chủ phòng chia ván mới';
    }
    final canStart = _remoteOpponentCount >= _minOpponentsToStart;
    final label = widget.entryLabel == null ? '' : '${widget.entryLabel} · ';
    if (canStart) {
      return '$labelĐủ người · Chủ phòng có thể bắt đầu';
    }
    return '$labelĐang chờ thêm người hoặc thêm bot';
  }

  void _openRealtimeTable(TienLenRoomState state) {
    _autoStartTimer?.cancel();
    if (!mounted) return;
    GameAudio.enterRoom();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            RealtimeTableScreen(room: widget.room, initialState: state),
      ),
    );
  }

  int _secondsUntilNextJoin(int remainingSeconds) {
    if (_joinedOpponents >= _autoFillLimit) {
      return 0;
    }
    final int elapsedSeconds = _autoStartDelaySeconds - remainingSeconds;
    final int nextMilestone = _joinMilestones[_joinedOpponents];
    return math.max(1, nextMilestone - elapsedSeconds);
  }

  int _matchedOpponentsForRemaining(int remainingSeconds) {
    final int elapsedSeconds = _autoStartDelaySeconds - remainingSeconds;
    int matchedOpponents = widget.initialOpponentCount
        .clamp(0, _maxBotOpponents)
        .toInt();
    for (
      int index = matchedOpponents;
      index < _joinMilestones.length && index < _autoFillLimit;
      index++
    ) {
      if (elapsedSeconds >= _joinMilestones[index]) {
        matchedOpponents = index + 1;
      }
    }
    return matchedOpponents.clamp(0, _autoFillLimit).toInt();
  }

  String _countdownStatus() {
    final bool canStart = _joinedOpponents >= _minOpponentsToStart;
    final String prefix = _joinedOpponents >= _maxBotOpponents
        ? 'Đủ bot hỗ trợ'
        : canStart
        ? 'Đủ 2 người · Có thể bắt đầu'
        : 'Đang ghép người chơi thứ 2';
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
          if (_joinedOpponents < _minOpponentsToStart) {
            _autoStartRemaining = 0;
            _opponentJoinRemaining = 0;
            _status =
                'Phòng $_roomId đang thiếu người · Chủ phòng mời thêm rồi start lại';
            return;
          }
          _opponentJoinRemaining = 0;
          _autoStartRemaining = 0;
          _status = 'Đủ 2 người · Chủ phòng ${widget.hostName} đang start';
        });
        if (_joinedOpponents < _minOpponentsToStart) {
          return;
        }
        if (_isRemoteHost) {
          _startGame(autoStart: true);
        }
        return;
      }
      setState(() {
        _autoStartRemaining--;
        if (_roomState == null) {
          _joinedOpponents = _matchedOpponentsForRemaining(_autoStartRemaining);
        }
        _opponentJoinRemaining = _secondsUntilNextJoin(_autoStartRemaining);
        _status = _roomState == null
            ? _countdownStatus()
            : _remoteStatus(_roomState!);
      });
    });
  }

  Future<void> _toggleReady() async {
    setState(() {
      _isReady = !_isReady;
      _status = _isReady
          ? 'Bạn đã sẵn sàng · Chủ phòng ${widget.hostName} sẽ start sau $_autoStartRemaining giây'
          : _countdownStatus();
    });
    try {
      final state = await context.read<ChatSocketService>().readyTienLen(
        ready: _isReady,
      );
      _applyRemoteState(state);
    } catch (_) {
      // Local ready state is enough for display if ack is slow.
    }
  }

  Future<void> _inviteFriend() async {
    final socket = context.read<ChatSocketService>();
    if (!_isRemoteHost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chỉ chủ phòng được thêm bot.')),
      );
      return;
    }
    try {
      final state = await socket.addTienLenBot();
      if (!mounted) return;
      _applyRemoteState(state);
      return;
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thêm bot được: ${_shortError(error)}')),
      );
    }
  }

  Future<void> _kickOpponent(int seatNumber) async {
    final socket = context.read<ChatSocketService>();
    final state = _roomState;
    if (!_isRemoteHost || state == null) {
      return;
    }
    final opponents = state.players
        .where((player) => player.id != state.viewerId)
        .toList();
    if (seatNumber < 1 || seatNumber > opponents.length) return;
    try {
      final nextState = await socket.kickTienLenPlayer(
        opponents[seatNumber - 1].id,
      );
      if (!mounted) return;
      _applyRemoteState(nextState);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không đá được: ${_shortError(error)}')),
      );
    }
  }

  Future<void> _startGame({bool autoStart = false}) async {
    final socket = context.read<ChatSocketService>();
    if (_joinedOpponents < _minOpponentsToStart) {
      setState(
        () => _status = 'Cần ít nhất 2 người · Đang ghép thêm người chơi',
      );
      return;
    }
    if (!_isRemoteHost) {
      setState(() => _status = 'Chờ chủ phòng bấm bắt đầu.');
      return;
    }
    try {
      final state = await socket.startTienLenRoom();
      if (!mounted) return;
      _openRealtimeTable(state);
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Chưa bắt đầu được: ${_shortError(error)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final playerName = session.user?.name.trim().isNotEmpty == true
        ? session.user!.name
        : 'Tây Bích 88';
    final playerCoins = session.user?.gameCoins ?? 0;
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
                  ProfileChip(name: playerName, balance: playerCoins),
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
                roomId: _roomId,
                roomState: _roomState,
                canKick: _isRemoteHost,
                onKickOpponent: _kickOpponent,
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
                      onPressed:
                          _isRemoteHost &&
                              _joinedOpponents >= _minOpponentsToStart
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
    required this.roomId,
    required this.roomState,
    required this.canKick,
    required this.onKickOpponent,
  });

  final DemoRoom room;
  final bool isReady;
  final int joinedOpponents;
  final int opponentJoinRemaining;
  final int autoStartRemaining;
  final String status;
  final String hostName;
  final String roomId;
  final TienLenRoomState? roomState;
  final bool canKick;
  final ValueChanged<int> onKickOpponent;

  bool get _isHostedByUser => hostName == 'Tây Bích 88';

  List<TienLenRealtimePlayer> get _opponents {
    final state = roomState;
    if (state == null) return const <TienLenRealtimePlayer>[];
    return state.players
        .where((player) => player.id != state.viewerId)
        .toList();
  }

  String _seatName(int seatNumber) {
    final int index = seatNumber - 1;
    if (index >= 0 && index < _opponents.length) {
      return _opponents[index].name;
    }
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
    final int index = seatNumber - 1;
    if (index >= 0 && index < _opponents.length) {
      final player = _opponents[index];
      if (player.isBot) return 'Bot · Sẵn sàng';
      if (player.id == roomState?.hostId) return 'Chủ phòng · Sẵn sàng';
      return player.ready ? 'Đã sẵn sàng' : 'Đang chuẩn bị';
    }
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
                Expanded(
                  child: Text(
                    'Phòng chờ · ID $roomId',
                    style: const TextStyle(
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
                      onKick: canKick && joinedOpponents >= 1
                          ? () => onKickOpponent(1)
                          : null,
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
                      onKick: canKick && joinedOpponents >= 2
                          ? () => onKickOpponent(2)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _SeatCard(
                      name: 'Chỗ trống',
                      detail: 'Không tự thêm bot',
                      icon: Icons.block,
                      isReady: false,
                      muted: true,
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
                      joinedOpponents >= 1
                          ? Icons.play_circle_fill
                          : Icons.search,
                      color: joinedOpponents >= 1
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
          joinedOpponents >= 2
              ? '3/3 người chơi · Chủ phòng start sau ${autoStartRemaining}s'
              : joinedOpponents >= 1
              ? '${joinedOpponents + 1}/3 người chơi · Có thể bắt đầu · ${joinedOpponents >= 2 ? 'Tối đa 2 bot' : 'Ghép thêm sau ${opponentJoinRemaining}s'}'
              : '1/3 người chơi · Cần 2 người · Ghép sau ${opponentJoinRemaining}s',
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
    this.onKick,
  });

  final String name;
  final String detail;
  final IconData icon;
  final bool isReady;
  final bool isPlayer;
  final bool muted;
  final VoidCallback? onKick;

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
            if (onKick != null) ...<Widget>[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: onKick,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xCC5D160D),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFFFB07A)),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    child: Text(
                      'Đá',
                      style: TextStyle(
                        color: Color(0xFFFFE1C7),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
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
