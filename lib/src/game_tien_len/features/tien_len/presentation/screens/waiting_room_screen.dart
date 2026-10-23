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

String _formatMatchCountdown(int seconds) {
  if (seconds < 60) return '$seconds giây';
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;
  return '$minutes phút ${remainingSeconds.toString().padLeft(2, '0')} giây';
}

class WaitingRoomScreen extends StatefulWidget {
  const WaitingRoomScreen({
    required this.room,
    this.initialOpponentCount = 0,
    this.hostName = 'Tây Bích 88',
    this.entryLabel,
    this.roomId,
    this.roomIdGenerator,
    super.key,
  });

  final DemoRoom room;
  final int initialOpponentCount;
  final String hostName;
  final String? entryLabel;
  final String? roomId;
  final String Function()? roomIdGenerator;

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  static const int _autoStartDelaySeconds = 15;
  static const int _maxBotOpponents = 3;
  static const int _minOpponentsToStart = 1;
  static const int _maxRoomCreationAttempts = 4;
  static const String _roomIdAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  Timer? _autoStartTimer;
  StreamSubscription<TienLenRoomState>? _roomStateSubscription;
  StreamSubscription<Map<String, dynamic>>? _eventSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  Timer? _retryTimer;
  bool _isReady = false;
  bool _joinedRealtime = false;
  bool _openingTable = false;
  bool _tableOpenScheduled = false;
  bool _leaving = false;
  bool _allowPop = false;
  bool _actionInFlight = false;
  bool _recoveringLostRoom = false;
  ChatSocketService? _socketService;
  late int _joinedOpponents;
  late String _roomId;
  int _opponentJoinRemaining = _autoStartDelaySeconds;
  late String _status;
  TienLenRoomState? _roomState;

  @override
  void initState() {
    super.initState();
    _roomId = widget.roomId ?? _generateRoomId();
    _joinedOpponents = widget.initialOpponentCount
        .clamp(0, _maxBotOpponents)
        .toInt();
    _opponentJoinRemaining = _autoStartDelaySeconds;
    _status = _waitingForReadyStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _socketService ??= context.read<ChatSocketService>();
    _joinRealtimeRoomOnce();
  }

  @override
  void dispose() {
    _autoStartTimer?.cancel();
    _roomStateSubscription?.cancel();
    _eventSubscription?.cancel();
    _connectionSubscription?.cancel();
    _retryTimer?.cancel();
    if (!_openingTable && !_leaving) {
      unawaited(_leaveSilently());
    }
    super.dispose();
  }

  Future<void> _leaveSilently({bool forceServerLeave = false}) async {
    try {
      final socket = _socketService;
      if (forceServerLeave) {
        await socket?.forceLeaveTienLenRoom();
      } else {
        await socket?.leaveTienLenRoom();
      }
    } catch (_) {}
  }

  String _generateRoomId() {
    final customId = widget.roomIdGenerator?.call().trim();
    if (customId != null && customId.isNotEmpty) return customId;

    final random = math.Random.secure();
    final suffix = List<String>.generate(
      16,
      (_) => _roomIdAlphabet[random.nextInt(_roomIdAlphabet.length)],
      growable: false,
    ).join();
    return 'NT$suffix';
  }

  bool get _isHostedByUser => widget.hostName == 'Tây Bích 88';

  bool get _isRemoteHost => _roomState?.isHost ?? _isHostedByUser;

  bool get _canAutoMatchBot {
    final state = _roomState;
    return !_leaving &&
        !_openingTable &&
        state != null &&
        state.isWaiting &&
        state.isHost &&
        state.playerCount <= 2 &&
        state.autoBotJoinDueAt != null;
  }

  bool get _allConnectedHumansReady {
    final state = _roomState;
    if (state == null) return _isReady;
    return _connectedHumansReady(state);
  }

  bool _connectedHumansReady(TienLenRoomState state) {
    final humans = state.players.where(
      (player) => !player.isSystemOpponent && player.connected,
    );
    return humans.isNotEmpty && humans.every((player) => player.ready);
  }

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
      _joinedRealtime = false;
      setState(() => _status = 'Bạn cần đăng nhập để vào phòng realtime.');
      return;
    }

    final socket = _socketService ?? context.read<ChatSocketService>();
    _roomStateSubscription ??= socket.tienLenRoomStateStream.listen((state) {
      if (!mounted || state.roomId != _roomId) return;
      _applyRemoteState(state);
    });
    _eventSubscription ??= socket.tienLenEventStream.listen((event) {
      if (!mounted || event['roomId']?.toString() != _roomId) return;
      if (event['event'] == 'kicked') {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Bạn đã bị mời ra khỏi phòng.')),
        );
        unawaited(_leaveAndPop());
      } else if (event['event'] == 'session-replaced') {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Bàn chơi đã được mở trên một thiết bị khác.'),
          ),
        );
        unawaited(_leaveAndPop());
      } else if (event['event'] == 'feature-paused') {
        unawaited(_handleFeaturePaused());
      } else if (event['event'] == 'reconnecting') {
        setState(() => _status = 'Mất kết nối · đang vào lại bàn...');
      } else if (event['event'] == 'reconnect-failed') {
        final message = (event['message'] ?? '').toString();
        if (message.contains('room-not-found')) {
          unawaited(_recoverLostWaitingRoom());
        } else {
          setState(() => _status = 'Đang thử khôi phục kết nối bàn chơi...');
        }
      }
    });
    _connectionSubscription ??= socket.connectionStream.listen((connected) {
      if (!mounted || _openingTable) return;
      if (!connected) {
        setState(() => _status = 'Mất kết nối · đang kết nối lại...');
      }
    });

    try {
      if (!socket.isConnected) {
        await socket.connect(
          socketUrl: app.socketUrl,
          user: user,
          notifyApiUrl: session.notifyApiUrl,
          accessToken: session.token!,
        );
      }

      late TienLenRoomState state;
      final createsOwnRoom = widget.roomId == null;
      if (createsOwnRoom) {
        state = await _createOwnRealtimeRoom(socket, user.id);
      } else {
        state = await socket.joinTienLenRoom(
          roomId: _roomId,
          title: widget.room.title,
          baseBet: widget.room.baseBet,
          userId: user.id,
          name: _playerName,
          coins: _playerCoins,
        );
      }
      _applyRemoteState(state);
      _startAutoStartTimer();
    } catch (error) {
      if (!mounted) return;
      _joinedRealtime = false;
      if (widget.roomId == null) {
        // A failed create acknowledgement is ambiguous: the server may have
        // created and joined the old room. Explicitly leave it and use a new
        // unguessable ID on the next create. Never fall through to join,
        // because that could put this player in somebody else's room.
        await _leaveSilently(forceServerLeave: true);
        if (!mounted) return;
        setState(() {
          _roomId = _generateRoomId();
          _roomState = null;
          _isReady = false;
          _joinedOpponents = widget.initialOpponentCount
              .clamp(0, _maxBotOpponents)
              .toInt();
          _opponentJoinRemaining = _autoStartDelaySeconds;
        });
      }
      setState(() {
        _status = 'Không vào được phòng realtime: ${_shortError(error)}';
      });
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && !_openingTable && !_leaving) {
          unawaited(_joinRealtimeRoomOnce());
        }
      });
    }
  }

  Future<TienLenRoomState> _createOwnRealtimeRoom(
    ChatSocketService socket,
    int userId,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt < _maxRoomCreationAttempts; attempt++) {
      try {
        return await socket.createTienLenRoom(
          roomId: _roomId,
          title: widget.room.title,
          baseBet: widget.room.baseBet,
          userId: userId,
          name: _playerName,
          coins: _playerCoins,
          maxPlayers: 4,
        );
      } catch (error) {
        lastError = error;
        final isCollision = error.toString().contains('room-already-exists');
        if (!isCollision || attempt == _maxRoomCreationAttempts - 1) {
          rethrow;
        }
        if (!mounted) rethrow;
        setState(() {
          _roomId = _generateRoomId();
          _status = 'ID phòng vừa trùng · đang tạo phòng mới...';
        });
      }
    }
    throw StateError('room-create-failed: $lastError');
  }

  Future<void> _recoverLostWaitingRoom() async {
    if (_recoveringLostRoom || _leaving || _openingTable) return;
    _recoveringLostRoom = true;
    _autoStartTimer?.cancel();

    if (widget.roomId != null) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text(
              'Phòng này đã kết thúc. Đang quay lại danh sách bàn.',
            ),
          ),
        );
      }
      await _leaveAndPop();
      _recoveringLostRoom = false;
      return;
    }

    if (mounted) {
      setState(() => _status = 'Kết nối đã trở lại · đang tạo lại phòng...');
    }
    await _leaveSilently(forceServerLeave: true);
    if (!mounted) return;

    setState(() {
      _roomId = _generateRoomId();
      _roomState = null;
      _joinedRealtime = false;
      _isReady = false;
      _joinedOpponents = 0;
      _opponentJoinRemaining = _autoStartDelaySeconds;
      _status = 'Đang tạo lại phòng...';
    });
    _recoveringLostRoom = false;
    await _joinRealtimeRoomOnce();
  }

  String _shortError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '');
    final normalized = raw.toLowerCase();
    if (raw.contains('room-already-started')) return 'bàn đã bắt đầu';
    if (raw.contains('room-full')) return 'phòng đã đủ người';
    if (normalized.contains('bot-matchmaking-pending')) {
      return 'đang ghép người chơi, vui lòng chờ trong giây lát';
    }
    if (normalized.contains('bot') ||
        normalized.contains('bankroll') ||
        normalized.contains('system-opponent')) {
      return 'chưa thể ghép đối thủ lúc này';
    }
    return raw;
  }

  void _applyRemoteState(TienLenRoomState state) {
    if (!mounted || _openingTable) return;
    setState(() {
      _roomState = state;
      _joinedOpponents = _remoteOpponentCount.clamp(0, _maxBotOpponents);
      _isReady = state.viewerPlayer?.ready ?? _isReady;
      _opponentJoinRemaining = state.remainingAutoMatchSeconds(DateTime.now());
      _status = _remoteStatus(state);
    });

    if (state.isPlaying || state.isRoundEnded || state.isSpectator) {
      _scheduleOpenRealtimeTable(state);
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
    final label = widget.entryLabel == null ? '' : '${widget.entryLabel} · ';
    if (state.viewerPlayer?.ready != true) {
      if (_remoteOpponentCount == 0) {
        return '$label'
            'Tự ghép đối thủ sau ${_formatMatchCountdown(_opponentJoinRemaining)} · Bấm Sẵn sàng khi bạn đã sẵn sàng';
      }
      return '$label'
          'Đối thủ đang chờ · Bấm Sẵn sàng để bắt đầu';
    }
    if (!_connectedHumansReady(state)) {
      return '$label'
          'Bạn đã sẵn sàng · đang chờ người chơi khác';
    }
    final canStart = _remoteOpponentCount >= _minOpponentsToStart;
    if (canStart) {
      return '$labelĐủ người · Chủ phòng có thể bắt đầu';
    }
    return '$labelĐang chờ ghép đối thủ · còn ${_formatMatchCountdown(_opponentJoinRemaining)}';
  }

  void _openRealtimeTable(TienLenRoomState state) {
    _autoStartTimer?.cancel();
    _retryTimer?.cancel();
    if (!mounted || _openingTable) return;
    _openingTable = true;
    GameAudio.enterRoom();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            RealtimeTableScreen(room: widget.room, initialState: state),
      ),
    );
  }

  void _scheduleOpenRealtimeTable(TienLenRoomState state) {
    if (_openingTable || _tableOpenScheduled || !mounted) return;
    _tableOpenScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tableOpenScheduled = false;
      if (!mounted || _openingTable || _leaving) return;
      _openRealtimeTable(state);
    });
  }

  Future<void> _leaveAndPop() async {
    if (_leaving || _openingTable) return;
    setState(() => _leaving = true);
    _autoStartTimer?.cancel();
    _retryTimer?.cancel();
    await _leaveSilently();
    if (!mounted) return;

    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final didPop = await Navigator.of(context).maybePop();
    if (!didPop && mounted) {
      setState(() {
        _allowPop = false;
        _leaving = false;
      });
    }
  }

  Future<void> _handleFeaturePaused() async {
    if (_leaving) return;
    await context.read<SessionController>().refreshFeatureFlags();
    if (!mounted) return;
    if (_roomState?.mustDrainWhenFeatureDisabled == true) {
      setState(() {
        _status =
            'Game đã tắt cho lượt mới · ván hiện tại tiếp tục đến khi quyết toán';
      });
      return;
    }
    setState(() {
      _status = 'Game bài đang tạm bảo trì · đang rời bàn...';
    });
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('Game bài đang tạm bảo trì. Vui lòng thử lại sau.'),
      ),
    );
    if (mounted) await _leaveAndPop();
  }

  String _waitingForReadyStatus() {
    final tableLabel = widget.entryLabel == null
        ? ''
        : '${widget.entryLabel} · ';
    if (_joinedOpponents == 0) {
      return '$tableLabel'
          'Đối thủ sẽ tự vào sau ${_formatMatchCountdown(_opponentJoinRemaining)} · Bấm Sẵn sàng khi bạn đã sẵn sàng';
    }
    return '$tableLabel'
        'Đối thủ đang chờ · Bấm Sẵn sàng để bắt đầu';
  }

  void _startAutoStartTimer() {
    _autoStartTimer?.cancel();
    _autoStartTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final state = _roomState;
      if (state == null || !state.isWaiting) return;
      final remaining = state.remainingAutoMatchSeconds(DateTime.now());
      setState(() {
        _opponentJoinRemaining = remaining;
        _status = _remoteStatus(state);
      });
    });
  }

  Future<void> _toggleReady() async {
    if (_actionInFlight) return;
    final previousReady = _isReady;
    setState(() {
      _actionInFlight = true;
      _isReady = !_isReady;
      _status = _isReady
          ? _joinedOpponents >= _minOpponentsToStart
                ? 'Bạn đã sẵn sàng · Có thể bắt đầu ván'
                : 'Bạn đã sẵn sàng · Đang chờ đối thủ tự vào sau ${_formatMatchCountdown(_opponentJoinRemaining)}'
          : _waitingForReadyStatus();
    });
    try {
      final state = await context.read<ChatSocketService>().readyTienLen(
        ready: _isReady,
      );
      if (!mounted) return;
      _applyRemoteState(state);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isReady = previousReady;
        _status = 'Không cập nhật được sẵn sàng: ${_shortError(error)}';
      });
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  Future<void> _kickOpponent(int seatNumber) async {
    if (_actionInFlight) return;
    final socket = context.read<ChatSocketService>();
    final state = _roomState;
    if (!_isRemoteHost || state == null) {
      return;
    }
    final opponents = state.players
        .where((player) => player.id != state.viewerId)
        .toList();
    if (seatNumber < 1 || seatNumber > opponents.length) return;
    setState(() => _actionInFlight = true);
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
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  Future<void> _startGame() async {
    if (_actionInFlight || _openingTable) return;
    final socket = context.read<ChatSocketService>();
    if (!_allConnectedHumansReady) {
      setState(() {
        _status = _isReady
            ? 'Đang chờ tất cả người chơi bấm Sẵn sàng.'
            : _waitingForReadyStatus();
      });
      return;
    }
    if (_joinedOpponents < _minOpponentsToStart) {
      setState(
        () => _status =
            'Cần ít nhất 2 người · Đối thủ sẽ tự vào sau ${_formatMatchCountdown(_opponentJoinRemaining)}',
      );
      return;
    }
    if (!_isRemoteHost) {
      setState(() => _status = 'Chờ chủ phòng bấm bắt đầu.');
      return;
    }
    setState(() => _actionInFlight = true);
    try {
      final state = await socket.startTienLenRoom();
      if (!mounted) return;
      _openRealtimeTable(state);
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Chưa bắt đầu được: ${_shortError(error)}');
    } finally {
      if (mounted && !_openingTable) {
        setState(() => _actionInFlight = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final playerName = session.user?.name.trim().isNotEmpty == true
        ? session.user!.name
        : 'Tây Bích 88';
    final playerCoins = session.user?.gameCoins ?? 0;
    return PopScope<void>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_leaveAndPop());
      },
      child: GameStage(
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
                  playerName: playerName,
                  isReady: _isReady,
                  joinedOpponents: _joinedOpponents,
                  opponentJoinRemaining: _opponentJoinRemaining,
                  status: _status,
                  hostName: widget.hostName,
                  roomId: _roomId,
                  roomState: _roomState,
                  autoMatchingBots: _canAutoMatchBot,
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
                        key: const ValueKey<String>('ready-room-button'),
                        assetPath: _isReady
                            ? 'assets/game_tien_len/buttons/cancel_ready.png'
                            : 'assets/game_tien_len/buttons/ready.png',
                        semanticLabel: _isReady ? 'Hủy sẵn sàng' : 'Sẵn sàng',
                        onPressed: _actionInFlight ? null : _toggleReady,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GptButton(
                        key: const ValueKey<String>('leave-room-button'),
                        assetPath:
                            'assets/game_tien_len/buttons/leave_room.png',
                        semanticLabel: 'Rời phòng',
                        onPressed: _leaving
                            ? null
                            : () => unawaited(_leaveAndPop()),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GptButton(
                        key: const ValueKey<String>('start-room-button'),
                        assetPath:
                            'assets/game_tien_len/buttons/start_game.png',
                        semanticLabel: 'Bắt đầu chơi',
                        onPressed:
                            !_actionInFlight &&
                                _isRemoteHost &&
                                _allConnectedHumansReady &&
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
    required this.playerName,
    required this.isReady,
    required this.joinedOpponents,
    required this.opponentJoinRemaining,
    required this.status,
    required this.hostName,
    required this.roomId,
    required this.roomState,
    required this.autoMatchingBots,
    required this.canKick,
    required this.onKickOpponent,
  });

  final DemoRoom room;
  final String playerName;
  final bool isReady;
  final int joinedOpponents;
  final int opponentJoinRemaining;
  final String status;
  final String hostName;
  final String roomId;
  final TienLenRoomState? roomState;
  final bool autoMatchingBots;
  final bool canKick;
  final ValueChanged<int> onKickOpponent;

  bool get _isHostedByUser => roomState?.isHost ?? hostName == 'Tây Bích 88';

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
      if (player.isSystemOpponent) {
        return player.ready
            ? 'Người chơi tự động · Đã sẵn sàng'
            : 'Người chơi tự động · Đang chuẩn bị';
      }
      if (player.id == roomState?.hostId) {
        return player.ready
            ? 'Chủ phòng · Đã sẵn sàng'
            : 'Chủ phòng · Chưa sẵn sàng';
      }
      return player.ready ? 'Đã sẵn sàng' : 'Đang chuẩn bị';
    }
    if (!_isHostedByUser && seatNumber == 1) {
      return 'Chủ phòng · Đang chuẩn bị';
    }
    return 'Đã vào · Đang chuẩn bị';
  }

  bool _seatIsReady(int seatNumber) {
    final int index = seatNumber - 1;
    if (index >= 0 && index < _opponents.length) {
      return _opponents[index].ready;
    }
    return false;
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
                  autoMatchingBots: autoMatchingBots,
                  canStart: _allConnectedHumansReady,
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
                      name: playerName,
                      detail: isReady
                          ? 'Bạn · Đã sẵn sàng'
                          : _isHostedByUser
                          ? 'Bạn · Chủ bàn · Chưa sẵn sàng'
                          : 'Bạn · Chưa sẵn sàng',
                      icon: Icons.person,
                      isReady: isReady,
                      isPlayer: true,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _SeatCard(
                      key: const ValueKey<String>('waiting-opponent-seat-1'),
                      name: joinedOpponents >= 1
                          ? _seatName(1)
                          : 'Đang tìm người',
                      detail: joinedOpponents >= 1
                          ? _seatDetail(1)
                          : 'Ghép đối thủ sau ${_formatMatchCountdown(opponentJoinRemaining)}',
                      icon: joinedOpponents >= 1
                          ? Icons.person
                          : Icons.hourglass_top,
                      isReady: _seatIsReady(1),
                      muted: joinedOpponents < 1,
                      onKick: canKick && joinedOpponents >= 1
                          ? () => onKickOpponent(1)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _SeatCard(
                      key: const ValueKey<String>('waiting-opponent-seat-2'),
                      name: joinedOpponents >= 2 ? _seatName(2) : 'Chỗ trống',
                      detail: joinedOpponents >= 2
                          ? _seatDetail(2)
                          : 'Đang chờ đối thủ',
                      icon: joinedOpponents >= 2
                          ? Icons.person
                          : Icons.person_add_alt_1,
                      isReady: _seatIsReady(2),
                      muted: joinedOpponents < 2,
                      onKick: canKick && joinedOpponents >= 2
                          ? () => onKickOpponent(2)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _SeatCard(
                      key: const ValueKey<String>('waiting-opponent-seat-3'),
                      name: joinedOpponents >= 3 ? _seatName(3) : 'Chỗ trống',
                      detail: joinedOpponents >= 3
                          ? _seatDetail(3)
                          : 'Đang chờ đối thủ',
                      icon: joinedOpponents >= 3
                          ? Icons.person
                          : Icons.person_add_alt_1,
                      isReady: _seatIsReady(3),
                      muted: joinedOpponents < 3,
                      onKick: canKick && joinedOpponents >= 3
                          ? () => onKickOpponent(3)
                          : null,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
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
                    if (_waitingForReadinessNotice case final notice?) ...[
                      const SizedBox(height: 4),
                      Text(
                        notice,
                        key: const ValueKey<String>(
                          'waiting-wager-safety-notice',
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: GameTheme.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _allConnectedHumansReady {
    final state = roomState;
    if (state == null) return isReady;
    final humans = state.players.where(
      (player) => !player.isSystemOpponent && player.connected,
    );
    return humans.isNotEmpty && humans.every((player) => player.ready);
  }

  bool get _hostIsReady {
    final state = roomState;
    if (state == null) return !_isHostedByUser || isReady;
    for (final player in state.players) {
      if (player.id == state.hostId) return player.ready;
    }
    return false;
  }

  String? get _waitingForReadinessNotice {
    if (joinedOpponents < 1 || _allConnectedHumansReady) return null;
    if (!_hostIsReady) {
      return 'Đối thủ đang chờ chủ phòng bấm Sẵn sàng · '
          'Ván chưa bắt đầu, chưa trừ xu';
    }
    return 'Đang chờ người chơi khác bấm Sẵn sàng · '
        'Ván chưa bắt đầu, chưa trừ xu';
  }
}

class _CounterBadge extends StatelessWidget {
  const _CounterBadge({
    required this.joinedOpponents,
    required this.opponentJoinRemaining,
    required this.autoMatchingBots,
    required this.canStart,
  });

  final int joinedOpponents;
  final int opponentJoinRemaining;
  final bool autoMatchingBots;
  final bool canStart;

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
              ? '4/4 người chơi · ${canStart ? 'Có thể bắt đầu' : 'Chờ Sẵn sàng'}'
              : joinedOpponents >= 1
              ? '${joinedOpponents + 1}/4 người chơi · ${canStart ? 'Có thể bắt đầu' : 'Chờ Sẵn sàng'} · ${autoMatchingBots ? 'Ghép đối thủ sau ${_formatMatchCountdown(opponentJoinRemaining)}' : 'Chờ thêm người chơi'}'
              : '1/4 người chơi · Cần 2 người · ${autoMatchingBots ? 'Ghép đối thủ sau ${_formatMatchCountdown(opponentJoinRemaining)}' : 'Chờ thêm người chơi'}',
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
    super.key,
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
