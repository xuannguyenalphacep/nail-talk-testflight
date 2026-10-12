import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../controllers/session_controller.dart';
import '../../../../core/audio/game_audio.dart';
import '../../../../core/theme/game_theme.dart';
import '../../../../core/widgets/card_view.dart';
import '../../../../core/widgets/game_stage.dart';
import '../../../../core/widgets/gpt_button.dart';
import '../../../../core/widgets/profile_chip.dart';
import '../../../../../services/chat_socket_service.dart';
import '../../data/game_data.dart';
import '../../data/realtime_game_models.dart';
import '../../domain/bot_strategy.dart';
import '../../domain/play_rules.dart';
import 'lobby_screen.dart';
import 'result_screen.dart';

class TableScreen extends StatefulWidget {
  const TableScreen({
    required this.room,
    this.opponentNames = const <String>['Minh Khang'],
    this.initialBalance = 12500,
    super.key,
  });

  final DemoRoom room;
  final List<String> opponentNames;
  final int initialBalance;

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  static const int _humanIndex = 0;
  static const int _turnThinkingSeconds = 15;
  static const int _newRoundDelaySeconds = 15;

  final Set<int> _selectedCards = <int>{};
  final math.Random _random = math.Random.secure();
  Timer? _opponentTurnTimer;
  Timer? _turnTimer;
  Timer? _newRoundTimer;

  late List<_TablePlayer> _players;
  late int _playerCoins;
  List<int> _opponentCoins = <int>[12500, 12500, 12500];
  int _roundNumber = 1;
  int _currentTurn = _humanIndex;
  int? _lastActor;
  int? _nextStarter;
  bool _roundEnded = false;
  bool _firstPlayPending = true;
  int _turnRemaining = _turnThinkingSeconds;
  int _newRoundRemaining = _newRoundDelaySeconds;
  List<int> _finishedOrder = <int>[];
  Set<int> _passedPlayers = <int>{};
  List<PlayingCardData> _tableCards = <PlayingCardData>[];
  List<PlayEvaluation> _playHistory = <PlayEvaluation>[];
  List<String> _turnLogs = <String>[];
  int _lastHumanCoinDelta = 0;
  String _status = 'Đang chia bài...';

  int get _stake => widget.room.baseBet;
  int get _pot => _stake * _playerCount;
  bool get _isHumanTurn =>
      _currentTurn == _humanIndex && !_roundEnded && !_isFinished(_humanIndex);
  bool get _canHumanAct => _isHumanTurn && !_roundEnded;
  PlayEvaluation? get _lastPlay =>
      _playHistory.isEmpty ? null : _playHistory.last;
  _TablePlayer get _human => _players[_humanIndex];
  int get _playerCount =>
      math.max(2, math.min(3, 1 + widget.opponentNames.length));
  List<String> get _seatNames {
    final List<String> names = <String>[
      'Tây Bích 88',
      ...widget.opponentNames.take(2),
    ];
    const List<String> fallbackBots = <String>['Minh Khang', 'Lan Anh'];
    for (final String botName in fallbackBots) {
      if (names.length >= _playerCount) {
        break;
      }
      if (!names.contains(botName)) {
        names.add(botName);
      }
    }
    return names;
  }

  _TablePlayer? _playerAt(int index) {
    if (index < 0 || index >= _players.length) {
      return null;
    }
    return _players[index];
  }

  bool _isActiveSeat(int index) {
    return index >= 0 && index < _players.length && _currentTurn == index;
  }

  bool _isFinishedSeat(int index) {
    return index >= 0 && index < _players.length && _isFinished(index);
  }

  int get _coveredTableCardCount =>
      _playHistory.length <= 1 ? 0 : (_playHistory.length - 1).clamp(0, 5);

  @override
  void initState() {
    super.initState();
    _playerCoins = widget.initialBalance;
    _dealNewRound();
    _restartTurnTimer();
    _maybeScheduleOpponentTurn();
  }

  @override
  void dispose() {
    _opponentTurnTimer?.cancel();
    _turnTimer?.cancel();
    _newRoundTimer?.cancel();
    super.dispose();
  }

  void _dealNewRound() {
    _opponentTurnTimer?.cancel();
    _turnTimer?.cancel();
    _newRoundTimer?.cancel();
    _turnRemaining = _turnThinkingSeconds;
    _newRoundRemaining = _newRoundDelaySeconds;
    final bool firstTableRound = _roundNumber == 1;
    final List<List<PlayingCardData>> hands = _dealHands();
    final List<String> seatNames = _seatNames;

    _players = List<_TablePlayer>.generate(_playerCount, (int index) {
      return _TablePlayer(
        name: seatNames[index],
        isComputerControlled: index != _humanIndex,
        coins: index == _humanIndex ? _playerCoins : _opponentCoins[index - 1],
        hand: hands[index],
      );
    });
    _tableCards = <PlayingCardData>[];
    _playHistory = <PlayEvaluation>[];
    _finishedOrder = <int>[];
    _passedPlayers = <int>{};
    _selectedCards.clear();
    _lastHumanCoinDelta = 0;
    _lastActor = null;
    _roundEnded = false;
    _firstPlayPending = firstTableRound;
    _currentTurn = firstTableRound
        ? _random.nextInt(_players.length)
        : (_nextStarter ?? _random.nextInt(_players.length));
    _turnLogs = <String>[
      firstTableRound
          ? 'Ván đầu: ${_displayName(_currentTurn)} được chọn ngẫu nhiên để mở lượt'
          : '${_players[_currentTurn].name} thắng ván trước nên đi trước',
      'Bài được xào ngẫu nhiên',
    ];

    if (!firstTableRound) {
      for (int index = 0; index < _players.length; index++) {
        final WhiteWinResult? whiteWin = PlayRules.whiteWin(
          _players[index].hand,
        );
        if (whiteWin != null) {
          _finishRound(index, whiteWinReason: whiteWin.reason);
          return;
        }
      }
    }

    _status = firstTableRound
        ? _currentTurn == _humanIndex
              ? 'Ván $_roundNumber · Đến lượt bạn mở lượt'
              : 'Ván $_roundNumber · ${_players[_currentTurn].name} đang mở lượt'
        : 'Ván $_roundNumber · ${_players[_currentTurn].name} đi trước';
  }

  List<PlayingCardData> _buildDeck() {
    return <PlayingCardData>[
      for (final String rank in PlayRules.rankOrder)
        for (final CardSuit suit in CardSuit.values)
          PlayingCardData(rank, suit),
    ];
  }

  List<List<PlayingCardData>> _dealHands() {
    final List<List<PlayingCardData>> hands = _shuffleDealHands();
    for (final List<PlayingCardData> hand in hands) {
      hand.sort(PlayRules.compareCards);
    }
    return hands;
  }

  List<List<PlayingCardData>> _shuffleDealHands() {
    final List<PlayingCardData> deck = _buildDeck()..shuffle(_random);
    final List<List<PlayingCardData>> hands =
        List<List<PlayingCardData>>.generate(
          _playerCount,
          (_) => <PlayingCardData>[],
        );

    for (int round = 0; round < 13; round++) {
      for (int seat = 0; seat < _playerCount; seat++) {
        hands[seat].add(deck.removeAt(0));
      }
    }

    return hands;
  }

  void _recordTurn(String message) {
    _turnLogs = <String>[message, ..._turnLogs].take(5).toList();
  }

  String _displayName(int index) {
    return index == _humanIndex ? 'Bạn' : _players[index].name;
  }

  String _turnName(int index) {
    return index == _humanIndex ? 'bạn' : _players[index].name;
  }

  bool _isFinished(int index) {
    return _finishedOrder.contains(index);
  }

  String _placeLabel(int place) {
    return switch (place) {
      1 => 'về nhất',
      2 => 'về nhì',
      3 => 'về ba',
      _ => 'về cuối',
    };
  }

  List<int> _unfinishedPlayers() {
    return <int>[
      for (int index = 0; index < _players.length; index++)
        if (!_isFinished(index)) index,
    ];
  }

  int _nextAvailablePlayerAfter(int from, {bool ignorePassed = false}) {
    for (int step = 1; step <= _players.length; step++) {
      final int index = (from + step) % _players.length;
      if (_isFinished(index)) {
        continue;
      }
      if (!ignorePassed && _passedPlayers.contains(index)) {
        continue;
      }
      return index;
    }
    return from;
  }

  bool _everyoneElsePassedOrFinished(int actor) {
    for (int index = 0; index < _players.length; index++) {
      if (index == actor || _isFinished(index)) {
        continue;
      }
      if (!_passedPlayers.contains(index)) {
        return false;
      }
    }
    return true;
  }

  void _finishPlayer(int index) {
    if (_isFinished(index)) {
      return;
    }
    _finishedOrder.add(index);
    _passedPlayers.remove(index);
    final String place = _placeLabel(_finishedOrder.length);
    _recordTurn('${_displayName(index)} xong bài · $place');
    _status = index == _humanIndex
        ? 'Bạn đã xong bài · $place · Chờ người còn lại'
        : '${_players[index].name} xong bài · $place';
  }

  bool _finishRoundIfReady() {
    final List<int> remaining = _unfinishedPlayers();
    if (remaining.length > 1) {
      return false;
    }
    if (remaining.length == 1) {
      _finishPlayer(remaining.first);
    }
    _finishRoundByRanks();
    return true;
  }

  void _startFreshTrickFrom(int preferredStarter) {
    _playHistory = <PlayEvaluation>[];
    _tableCards = <PlayingCardData>[];
    _lastActor = null;
    _passedPlayers.clear();
    final int starter = _isFinished(preferredStarter)
        ? _nextAvailablePlayerAfter(preferredStarter, ignorePassed: true)
        : preferredStarter;
    _currentTurn = starter;
    _status = starter == _humanIndex
        ? 'Đến lượt bạn · Mở vòng mới'
        : '${_players[starter].name} mở vòng mới';
  }

  void _advanceTurnAfterPlay(int actor) {
    if (_finishRoundIfReady()) {
      return;
    }
    if (_everyoneElsePassedOrFinished(actor)) {
      _startFreshTrickFrom(actor);
      return;
    }
    _currentTurn = _nextAvailablePlayerAfter(actor);
    _status = _currentTurn == _humanIndex
        ? 'Đến lượt bạn · Chọn bài để chặn'
        : 'Đến lượt ${_players[_currentTurn].name}';
  }

  void _applyPass(int actor) {
    _selectedCards.clear();
    _passedPlayers.add(actor);
    _recordTurn('${_displayName(actor)} bỏ lượt');

    final int? leader = _lastActor;
    if (leader != null && _everyoneElsePassedOrFinished(leader)) {
      _startFreshTrickFrom(leader);
      return;
    }

    _currentTurn = _nextAvailablePlayerAfter(actor);
    _status = actor == _humanIndex
        ? 'Bạn bỏ lượt · Đến lượt ${_turnName(_currentTurn)}'
        : '${_players[actor].name} bỏ lượt · Đến lượt ${_turnName(_currentTurn)}';
  }

  void _maybeScheduleOpponentTurn() {
    _opponentTurnTimer?.cancel();
    if (!_roundEnded &&
        _currentTurn != _humanIndex &&
        !_isFinished(_currentTurn)) {
      _opponentTurnTimer = Timer(
        const Duration(milliseconds: 900),
        _performOpponentTurn,
      );
    }
  }

  void _restartTurnTimer() {
    _turnTimer?.cancel();
    if (_roundEnded || _unfinishedPlayers().length <= 1) {
      return;
    }
    _turnRemaining = _turnThinkingSeconds;
    _turnTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted || _roundEnded) {
        timer.cancel();
        return;
      }
      if (_turnRemaining <= 1) {
        timer.cancel();
        _handleTurnTimeout();
        return;
      }
      setState(() => _turnRemaining--);
    });
  }

  void _handleTurnTimeout() {
    if (!mounted || _roundEnded || _isFinished(_currentTurn)) {
      return;
    }
    final int actor = _currentTurn;
    if (_lastPlay != null) {
      setState(() {
        _applyPass(actor);
        _status = actor == _humanIndex
            ? 'Bạn hết giờ · Tự bỏ lượt'
            : '${_players[actor].name} hết giờ · Bỏ lượt';
      });
      _restartTurnTimer();
      _maybeScheduleOpponentTurn();
      return;
    }

    final PlayEvaluation? timeoutPlay = _chooseOpponentPlay(actor);
    if (timeoutPlay == null) {
      setState(() => _applyPass(actor));
      _restartTurnTimer();
      _maybeScheduleOpponentTurn();
      return;
    }

    GameAudio.playCard();
    setState(() {
      final _TablePlayer player = _players[actor];
      for (final PlayingCardData card in timeoutPlay.cards) {
        player.hand.remove(card);
      }
      _playHistory = <PlayEvaluation>[..._playHistory, timeoutPlay];
      _tableCards = timeoutPlay.cards;
      _firstPlayPending = false;
      _lastActor = actor;
      _passedPlayers.remove(actor);
      _recordTurn('${_displayName(actor)} hết giờ đánh ${timeoutPlay.summary}');
      _status = actor == _humanIndex
          ? 'Bạn hết giờ · Tự đánh ${timeoutPlay.summary}'
          : '${player.name} hết giờ · Đánh ${timeoutPlay.summary}';
      if (player.hand.isEmpty) {
        _finishPlayer(actor);
      }
      _advanceTurnAfterPlay(actor);
    });
    _restartTurnTimer();
    _maybeScheduleOpponentTurn();
  }

  void _startNewRoundCountdown(String baseStatus) {
    _newRoundTimer?.cancel();
    _newRoundRemaining = _newRoundDelaySeconds;
    _newRoundTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_newRoundRemaining <= 1) {
        timer.cancel();
        _newRound();
        return;
      }
      setState(() {
        _newRoundRemaining--;
        _status = baseStatus;
      });
    });
  }

  void _toggleCard(int index) {
    if (!_canHumanAct) {
      setState(() => _status = 'Chưa đến lượt bạn · Đợi người chơi khác');
      return;
    }
    if (index >= _human.hand.length) {
      return;
    }
    setState(() {
      if (_selectedCards.contains(index)) {
        _selectedCards.remove(index);
      } else {
        _selectedCards.add(index);
      }
      if (_selectedCards.isEmpty) {
        _status = _lastPlay == null
            ? 'Đến lượt bạn · Chọn bài để mở lượt'
            : 'Đến lượt bạn · Chọn bài để chặn ${_lastPlay!.summary}';
        return;
      }
      final List<PlayingCardData> selectedCards = _selectedCards
          .map((int selectedIndex) => _human.hand[selectedIndex])
          .toList();
      final PlayEvaluation? evaluation = PlayRules.evaluate(selectedCards);
      _status = evaluation == null
          ? 'Đã chọn ${_selectedCards.length} lá · Bộ này chưa đúng luật'
          : 'Đã chọn ${evaluation.summary} · ${_previewPlayHint(evaluation)}';
    });
  }

  String _previewPlayHint(PlayEvaluation evaluation) {
    if (!PlayRules.isValidPlay(candidate: evaluation, previous: _lastPlay)) {
      return PlayRules.invalidReason(
        candidate: evaluation,
        previous: _lastPlay,
      );
    }
    return 'có thể đánh';
  }

  void _sortCards() {
    setState(() {
      _human.hand.sort(PlayRules.compareCards);
      _selectedCards.clear();
      _status = 'Đã sắp bài theo thứ tự tăng dần';
    });
  }

  void _playCards() {
    if (!_canHumanAct) {
      setState(() => _status = 'Chưa đến lượt bạn · Đợi người chơi khác');
      return;
    }
    if (_selectedCards.isEmpty) {
      setState(() => _status = 'Hãy chọn ít nhất một lá trước khi đánh');
      return;
    }
    final List<int> selectedIndexes = _selectedCards.toList()..sort();
    final List<PlayingCardData> selectedCards = selectedIndexes
        .map((int index) => _human.hand[index])
        .toList();
    final PlayEvaluation? evaluation = PlayRules.evaluate(selectedCards);
    if (!_isLegalCandidate(evaluation)) {
      return;
    }

    final PlayEvaluation play = evaluation!;
    final PlayEvaluation? previous = _lastPlay;
    GameAudio.playCard();
    setState(() {
      _human.hand = <PlayingCardData>[
        for (int index = 0; index < _human.hand.length; index++)
          if (!_selectedCards.contains(index)) _human.hand[index],
      ];
      _playHistory = <PlayEvaluation>[..._playHistory, play];
      _tableCards = play.cards;
      _selectedCards.clear();
      _firstPlayPending = false;
      _lastActor = _humanIndex;
      _passedPlayers.remove(_humanIndex);
      _recordTurn('Bạn đánh ${play.summary}');
      _status = previous != null && play.type != previous.type
          ? 'Bạn chặt bằng ${play.summary}'
          : 'Bạn đánh ${play.summary}';
      if (_human.hand.isEmpty) {
        _finishPlayer(_humanIndex);
      }
      _advanceTurnAfterPlay(_humanIndex);
    });
    _restartTurnTimer();
    _maybeScheduleOpponentTurn();
  }

  bool _isLegalCandidate(PlayEvaluation? evaluation) {
    if (evaluation == null) {
      setState(
        () => _status = PlayRules.invalidReason(
          candidate: null,
          previous: _lastPlay,
        ),
      );
      return false;
    }
    if (!PlayRules.isValidPlay(candidate: evaluation, previous: _lastPlay)) {
      setState(
        () => _status = PlayRules.invalidReason(
          candidate: evaluation,
          previous: _lastPlay,
        ),
      );
      return false;
    }
    return true;
  }

  void _passTurn() {
    if (!_canHumanAct) {
      setState(() => _status = 'Chưa đến lượt bạn · Đợi người chơi khác');
      return;
    }
    if (_lastPlay == null) {
      setState(() => _status = 'Bạn đang mở lượt nên không thể bỏ lượt');
      return;
    }
    setState(() {
      _applyPass(_humanIndex);
    });
    _restartTurnTimer();
    _maybeScheduleOpponentTurn();
  }

  void _performOpponentTurn() {
    if (!mounted ||
        _roundEnded ||
        _currentTurn == _humanIndex ||
        _isFinished(_currentTurn)) {
      return;
    }
    final int actor = _currentTurn;
    final _TablePlayer player = _players[actor];
    final PlayEvaluation? opponentPlay = _chooseOpponentPlay(actor);
    if (opponentPlay == null) {
      setState(() {
        _applyPass(actor);
      });
      _restartTurnTimer();
      _maybeScheduleOpponentTurn();
      return;
    }

    GameAudio.playCard();
    setState(() {
      for (final PlayingCardData card in opponentPlay.cards) {
        player.hand.remove(card);
      }
      _playHistory = <PlayEvaluation>[..._playHistory, opponentPlay];
      _tableCards = opponentPlay.cards;
      _firstPlayPending = false;
      _lastActor = actor;
      _passedPlayers.remove(actor);
      _recordTurn('${player.name} đánh ${opponentPlay.summary}');
      _status = '${player.name} đánh ${opponentPlay.summary}';
      if (player.hand.isEmpty) {
        _finishPlayer(actor);
      }
      _advanceTurnAfterPlay(actor);
    });
    _restartTurnTimer();
    _maybeScheduleOpponentTurn();
  }

  PlayEvaluation? _chooseOpponentPlay(int playerIndex) {
    return TienLenBot.choosePlay(
      hand: _players[playerIndex].hand,
      previous: _lastPlay,
      firstPlayPending: _firstPlayPending,
      mustContainThreeSpades: false,
      lastActorIsHuman: _lastActor == _humanIndex,
      humanCardCount: _human.hand.length,
    );
  }

  void _finishRound(int winnerIndex, {String? whiteWinReason}) {
    _opponentTurnTimer?.cancel();
    _finishedOrder = <int>[
      winnerIndex,
      for (int index = 0; index < _players.length; index++)
        if (index != winnerIndex) index,
    ];
    _finishRoundByRanks(whiteWinReason: whiteWinReason);
  }

  void _finishRoundByRanks({String? whiteWinReason}) {
    _opponentTurnTimer?.cancel();
    _turnTimer?.cancel();
    if (_finishedOrder.length < _players.length) {
      final List<int> remaining =
          <int>[
            for (int index = 0; index < _players.length; index++)
              if (!_finishedOrder.contains(index)) index,
          ]..sort((int a, int b) {
            return _players[a].hand.length.compareTo(_players[b].hand.length);
          });
      _finishedOrder = <int>[..._finishedOrder, ...remaining];
    }

    _roundEnded = true;
    _nextStarter = _finishedOrder.first;
    _currentTurn = _nextStarter!;
    _passedPlayers.clear();

    final Map<int, int> deltas = <int, int>{};
    for (int placeIndex = 0; placeIndex < _finishedOrder.length; placeIndex++) {
      final int playerIndex = _finishedOrder[placeIndex];
      final int delta = (_playerCount - (2 * (placeIndex + 1)) + 1) * _stake;
      deltas[playerIndex] = delta;
      _players[playerIndex].coins = math.max(
        0,
        _players[playerIndex].coins + delta,
      );
    }

    _playerCoins = _human.coins;
    _opponentCoins = <int>[
      for (int index = 1; index < _players.length; index++)
        _players[index].coins,
    ];

    final int humanPlace = _finishedOrder.indexOf(_humanIndex) + 1;
    final int humanDelta = deltas[_humanIndex] ?? 0;
    _lastHumanCoinDelta = humanDelta;
    final String coinText = humanDelta >= 0
        ? '+$humanDelta xu'
        : '$humanDelta xu';
    final String rankText = _placeLabel(humanPlace);
    final String summary = _finishedOrder
        .map((int index) {
          final int place = _finishedOrder.indexOf(index) + 1;
          return '${_displayName(index)} ${_placeLabel(place)}';
        })
        .join(' · ');

    _recordTurn('Kết quả: $summary');
    _human.coins = _playerCoins;
    final String resultStatus = whiteWinReason != null
        ? '${_displayName(_finishedOrder.first)} tới trắng: $whiteWinReason · $coinText'
        : 'Bạn xong bài · $rankText · $coinText';
    _status = resultStatus;
    _startNewRoundCountdown(resultStatus);
  }

  void _newRound() {
    _newRoundTimer?.cancel();
    setState(() {
      _roundNumber++;
      _dealNewRound();
    });
    _restartTurnTimer();
    _maybeScheduleOpponentTurn();
  }

  void _finishRoundManually() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => ResultScreen(room: widget.room)),
    );
  }

  void _backToLobby() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LobbyScreen()),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _openMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF20A2C27),
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 22, 28, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: SizedBox(
                    height: 156,
                    child: GptButton(
                      assetPath: 'assets/game_tien_len/buttons/finish_game.png',
                      semanticLabel: 'Kết thúc ván',
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _finishRoundManually();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: SizedBox(
                    height: 156,
                    child: GptButton(
                      assetPath:
                          'assets/game_tien_len/buttons/back_lobby_v2.png',
                      semanticLabel: 'Quay lại sảnh',
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _backToLobby();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GameStage(
      backgroundAsset: 'assets/game_tien_len/backgrounds/table_stage.png',
      stageWidth: 1659,
      stageHeight: 948,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 22, 28, 26),
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 62,
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: GptButton(
                      assetPath: 'assets/game_tien_len/buttons/table_menu.png',
                      semanticLabel: 'Mở menu bàn chơi',
                      onPressed: _openMenu,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      '${widget.room.title} · Cược ${widget.room.stakeLabel} · Pot $_pot xu · Ván $_roundNumber',
                      style: const TextStyle(
                        color: GameTheme.ivory,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        shadows: <Shadow>[
                          Shadow(color: Colors.black, blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                  ProfileChip(name: 'Tây Bích 88', balance: _playerCoins),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        SizedBox(
                          height: 74,
                          child: _TopOpponentSlot(
                            player: _playerAt(2),
                            active: _isActiveSeat(2),
                            finished: _isFinishedSeat(2),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              SizedBox(
                                width: 68,
                                child: _SideOpponentSlot(
                                  player: _playerAt(1),
                                  active: _isActiveSeat(1),
                                  finished: _isFinishedSeat(1),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _CenterBoard(
                                  cards: _tableCards,
                                  coveredCardCount: _coveredTableCardCount,
                                  currentPlay: _lastPlay,
                                  lastActorName: _lastActor == null
                                      ? null
                                      : _players[_lastActor!].name,
                                  currentPlayerName:
                                      _players[_currentTurn].name,
                                  isHumanTurn: _isHumanTurn,
                                  roundEnded: _roundEnded,
                                  remainingSeconds: _turnRemaining,
                                  newRoundRemainingSeconds: _newRoundRemaining,
                                  turnLogs: _turnLogs,
                                  viewerWon:
                                      _roundEnded &&
                                      _finishedOrder.isNotEmpty &&
                                      _finishedOrder.first == _humanIndex,
                                  viewerCoinDelta: _lastHumanCoinDelta,
                                  viewerBalance: _playerCoins,
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 68,
                                child: _SideOpponentSlot(
                                  player: _playerAt(3),
                                  active: _isActiveSeat(3),
                                  finished: _isFinishedSeat(3),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 236,
                          child: _PlayerHand(
                            player: _human,
                            active: _isHumanTurn,
                            cards: _human.hand,
                            onCardTap: _toggleCard,
                            selected: _selectedCards,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 128,
                    child: Column(
                      children: <Widget>[
                        Expanded(
                          child: GptButton(
                            assetPath:
                                'assets/game_tien_len/buttons/sort_cards.png',
                            semanticLabel: 'Sắp bài',
                            onPressed: _roundEnded ? null : _sortCards,
                          ),
                        ),
                        Expanded(
                          child: GptButton(
                            assetPath:
                                'assets/game_tien_len/buttons/play_card.png',
                            semanticLabel: 'Đánh bài',
                            onPressed: _canHumanAct && _selectedCards.isNotEmpty
                                ? _playCards
                                : null,
                          ),
                        ),
                        Expanded(
                          child: GptButton(
                            assetPath:
                                'assets/game_tien_len/buttons/pass_turn.png',
                            semanticLabel: 'Bỏ lượt',
                            onPressed: _canHumanAct && _lastPlay != null
                                ? _passTurn
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.center,
              child: _TurnBanner(
                message: _status,
                highlighted: _isHumanTurn,
                roundEnded: _roundEnded,
                remainingSeconds: _roundEnded
                    ? _newRoundRemaining
                    : _turnRemaining,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TablePlayer {
  _TablePlayer({
    required this.name,
    required this.isComputerControlled,
    required this.coins,
    required this.hand,
  });

  final String name;
  final bool isComputerControlled;
  int coins;
  List<PlayingCardData> hand;
}

class RealtimeTableScreen extends StatefulWidget {
  const RealtimeTableScreen({
    required this.room,
    required this.initialState,
    super.key,
  });

  final DemoRoom room;
  final TienLenRoomState initialState;

  @override
  State<RealtimeTableScreen> createState() => _RealtimeTableScreenState();
}

class _RealtimeTableScreenState extends State<RealtimeTableScreen> {
  static const Map<String, String> _reactionEmoji = <String, String>{
    'like': '👍',
    'haha': '😂',
    'wow': '😮',
    'love': '❤️',
    'angry': '😠',
    'cry': '😢',
    'fire': '🔥',
    'clap': '👏',
  };
  final Set<int> _selectedCards = <int>{};
  StreamSubscription<TienLenRoomState>? _stateSubscription;
  StreamSubscription<Map<String, dynamic>>? _eventSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  Timer? _clockTimer;
  Timer? _reactionTimer;
  late TienLenRoomState _state;
  DateTime _now = DateTime.now();
  String? _localStatus;
  String? _recentReaction;
  bool _actionInFlight = false;
  bool _leaving = false;
  bool _allowPop = false;
  int _walletSyncedRound = 0;
  int _walletRefreshScheduledRound = 0;
  ChatSocketService? _socketService;
  SessionController? _sessionController;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _socketService ??= context.read<ChatSocketService>();
    _sessionController ??= context.read<SessionController>();
    _stateSubscription ??= _socketService!.tienLenRoomStateStream.listen((
      TienLenRoomState state,
    ) {
      if (!mounted || state.roomId != _state.roomId) return;
      _applyRealtimeState(state);
    });
    _eventSubscription ??= _socketService!.tienLenEventStream.listen((
      Map<String, dynamic> event,
    ) {
      if (!mounted || event['roomId']?.toString() != _state.roomId) {
        return;
      }
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
        setState(() => _localStatus = 'Mất kết nối · đang vào lại bàn...');
      } else if (event['event'] == 'reconnect-failed') {
        final message = (event['message'] ?? '').toString();
        if (message.contains('room-not-found')) {
          unawaited(_handleLostRealtimeRound());
        } else {
          setState(
            () => _localStatus = 'Đang thử khôi phục kết nối bàn chơi...',
          );
        }
      } else if (event['event'] == 'round-settled') {
        unawaited(_refreshWalletForRound(_state.roundNumber));
      } else if (event['event'] == 'reaction') {
        final emoji = _reactionEmoji[event['reaction']?.toString()];
        if (emoji != null) {
          _reactionTimer?.cancel();
          setState(
            () => _recentReaction = '${event['name'] ?? 'Người chơi'} $emoji',
          );
          _reactionTimer = Timer(const Duration(seconds: 4), () {
            if (mounted) setState(() => _recentReaction = null);
          });
        }
      } else if (event['event'] == 'turn-timeout' &&
          event['playerId']?.toString() == _state.viewerId) {
        final action = event['action']?.toString() == 'play'
            ? 'đã tự đánh một lá hợp lệ'
            : 'đã tự bỏ lượt';
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('Hết thời gian · hệ thống $action.')),
        );
      }
    });
    _connectionSubscription ??= _socketService!.connectionStream.listen((ok) {
      if (!mounted) return;
      if (!ok) {
        setState(() => _localStatus = 'Mất kết nối · đang kết nối lại...');
      }
    });
    _scheduleWalletSyncIfNeeded(_state);
  }

  void _applyRealtimeState(TienLenRoomState state) {
    if (!mounted) return;
    final previousState = _state;
    final keepSelectedCards =
        _selectedCards.isNotEmpty &&
        previousState.phase == state.phase &&
        previousState.roundId == state.roundId &&
        previousState.roundNumber == state.roundNumber &&
        previousState.currentTurnPlayerId == state.currentTurnPlayerId &&
        _sameHand(previousState.viewerPlayer?.hand, state.viewerPlayer?.hand);
    setState(() {
      _state = state;
      if (keepSelectedCards) {
        _localStatus =
            'Đã chọn ${_selectedCards.length} lá · Bấm Đánh bài để gửi lượt';
      } else {
        _selectedCards.clear();
        _localStatus = null;
      }
    });
    _scheduleWalletSyncIfNeeded(state);
  }

  bool _sameHand(
    List<TienLenRealtimeCard>? previous,
    List<TienLenRealtimeCard>? next,
  ) {
    if (identical(previous, next)) return true;
    if (previous == null || next == null || previous.length != next.length) {
      return false;
    }
    for (var index = 0; index < previous.length; index++) {
      if (previous[index].code != next[index].code) return false;
    }
    return true;
  }

  void _scheduleWalletSyncIfNeeded(TienLenRoomState state) {
    if (!state.isRoundEnded ||
        !state.isSettlementSettled ||
        state.roundNumber <= _walletSyncedRound ||
        state.roundNumber <= _walletRefreshScheduledRound) {
      return;
    }
    _walletRefreshScheduledRound = state.roundNumber;
    unawaited(
      Future<void>.delayed(
        const Duration(seconds: 3),
        () => _refreshWalletForRound(state.roundNumber),
      ),
    );
  }

  Future<void> _refreshWalletForRound(int roundNumber) async {
    if (roundNumber <= _walletSyncedRound) return;
    final session = _sessionController;
    if (session == null) return;
    try {
      await session.refreshCurrentUser();
      _walletSyncedRound = roundNumber;
    } catch (_) {
      // Keep the in-room balance; a later settlement event/refresh can retry.
    }
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _eventSubscription?.cancel();
    _connectionSubscription?.cancel();
    _clockTimer?.cancel();
    _reactionTimer?.cancel();
    if (!_leaving) unawaited(_leaveSilently());
    super.dispose();
  }

  Future<void> _leaveSilently() async {
    try {
      await _socketService?.leaveTienLenRoom();
    } catch (_) {}
  }

  Future<void> _leaveAndPop() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    await _leaveSilently();
    if (!mounted) return;

    final navigator = Navigator.of(context);
    final tableRoute = ModalRoute.of(context);
    if (tableRoute != null) {
      navigator.popUntil((route) => route == tableRoute);
    }
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final didPop = await navigator.maybePop();
    if (!didPop && mounted) {
      setState(() {
        _allowPop = false;
        _leaving = false;
      });
    }
  }

  Future<void> _handleLostRealtimeRound() async {
    if (_leaving) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text(
          'Ván đã được hủy an toàn khi máy chủ khởi động lại. Không bị trừ xu.',
        ),
      ),
    );
    await _leaveAndPop();
  }

  Future<void> _handleFeaturePaused() async {
    if (_leaving) return;
    await context.read<SessionController>().refreshFeatureFlags();
    if (!mounted) return;
    if (_state.mustDrainWhenFeatureDisabled) {
      setState(() {
        _localStatus =
            'Game đã tắt cho lượt mới · ván hiện tại tiếp tục đến khi quyết toán';
      });
      return;
    }
    setState(() {
      _localStatus = 'Game bài đã được quản trị viên tắt · đang rời bàn...';
    });
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Game bài đã được quản trị viên tắt.')),
    );
    if (mounted) await _leaveAndPop();
  }

  List<TienLenRealtimePlayer> get _seatedPlayers {
    final viewerId = _state.viewerId;
    final viewer = _state.viewerPlayer;
    final others = _state.players
        .where((player) => player.id != viewerId)
        .toList(growable: false);
    if (_state.isSpectator) {
      return List<TienLenRealtimePlayer>.of(_state.players)
        ..sort((left, right) => left.seatIndex.compareTo(right.seatIndex));
    }
    final seated = <TienLenRealtimePlayer>[];
    if (viewer != null) seated.add(viewer);
    seated.addAll(others);
    return seated;
  }

  TienLenRealtimePlayer? _seatPlayer(int index) {
    final players = _seatedPlayers;
    if (index < 0 || index >= players.length) return null;
    return players[index];
  }

  _TablePlayer? _tablePlayerAt(int index) {
    final player = _seatPlayer(index);
    if (player == null) return null;
    return _TablePlayer(
      name: player.name,
      isComputerControlled: player.isSystemOpponent,
      coins: player.coins,
      hand: List<PlayingCardData>.generate(
        player.id == _state.viewerId ? player.hand.length : player.handCount,
        (int cardIndex) => player.id == _state.viewerId
            ? player.hand[cardIndex].playingCard
            : const PlayingCardData('A', CardSuit.spades),
      ),
    );
  }

  _TablePlayer get _humanTablePlayer {
    return _tablePlayerAt(0) ??
        _TablePlayer(
          name: 'Bạn',
          isComputerControlled: false,
          coins: 0,
          hand: const <PlayingCardData>[],
        );
  }

  _TablePlayer get _viewerProfilePlayer {
    final participant = _state.viewerParticipant;
    return _TablePlayer(
      name: participant?.name ?? 'Bạn',
      isComputerControlled: false,
      coins: participant?.coins ?? 0,
      hand: const <PlayingCardData>[],
    );
  }

  bool _isActiveSeat(int index) {
    final player = _seatPlayer(index);
    return player != null && player.id == _state.currentTurnPlayerId;
  }

  bool _isFinishedSeat(int index) {
    final player = _seatPlayer(index);
    return player?.finished ?? false;
  }

  bool get _isHumanTurn => _state.isViewerTurn;
  bool get _isSpectating => _state.isSpectator;
  bool get _turnExpired =>
      _state.isPlaying && _state.remainingTurnSeconds(_now) == 0;

  List<TienLenRealtimeCard> get _humanCards {
    return _state.viewerPlayer?.hand ?? const <TienLenRealtimeCard>[];
  }

  String? _playerNameById(String playerId) {
    if (playerId.isEmpty) return null;
    for (final player in _state.players) {
      if (player.id == playerId) return player.name;
    }
    return null;
  }

  PlayEvaluation? get _lastPlay {
    final play = _state.lastPlay;
    if (play == null) return null;
    return PlayEvaluation(
      type: _playTypeFromRealtime(play.type),
      rankValue: play.rankValue,
      suitValue: play.suitValue,
      cards: play.cards.map((card) => card.playingCard).toList(),
    );
  }

  PlayType _playTypeFromRealtime(String type) {
    return switch (type) {
      'pair' => PlayType.pair,
      'triple' => PlayType.triple,
      'straight' => PlayType.straight,
      'threePairs' => PlayType.threePairs,
      'fourPairs' => PlayType.fourPairs,
      'fivePairs' => PlayType.fivePairs,
      'bomb' => PlayType.bomb,
      _ => PlayType.single,
    };
  }

  String get _status {
    if (_localStatus != null) return _localStatus!;
    if (_isSpectating) {
      if (_state.viewerSpectator?.waitingReason == 'insufficient-coins') {
        return 'Số dư chưa đủ mức cược · Cần thêm xu để vào ván sau';
      }
      return _state.isRoundEnded
          ? 'Đang chờ vào ván sau · Bạn sẽ được xếp chỗ khi ván mới bắt đầu'
          : 'Đang xem ván hiện tại · Bạn sẽ vào từ ván kế tiếp';
    }
    if (_state.isRoundEnded) {
      if (_state.isSettlementPending) {
        return 'Đang chốt kết quả và cập nhật ví...';
      }
      if (_state.isSettlementFailed) {
        return _state.isHost
            ? 'Cập nhật ví thất bại · hãy bấm Thử chốt ví lại'
            : 'Cập nhật ví thất bại · đang chờ chủ bàn thử lại';
      }
      final winner = _state.finishedOrder.isEmpty
          ? null
          : _playerNameById(_state.finishedOrder.first);
      final result = winner == null
          ? 'Ván đã kết thúc'
          : '$winner thắng ván ${_state.roundNumber}';
      return result;
    }
    if (_turnExpired) {
      return 'Hết thời gian · đang chờ máy chủ chuyển lượt';
    }
    final current = _state.currentTurnPlayer;
    if (_isHumanTurn) {
      return _lastPlay == null
          ? 'Đến lượt bạn · Mở vòng mới'
          : 'Đến lượt bạn · Chọn bài để chặn';
    }
    return '${current?.name ?? 'Người chơi'} đang suy nghĩ đánh bài';
  }

  void _toggleCard(int index) {
    if (!_isHumanTurn || _actionInFlight || _turnExpired) {
      setState(() => _localStatus = 'Chưa đến lượt bạn · Đợi người chơi khác');
      return;
    }
    setState(() {
      if (_selectedCards.contains(index)) {
        _selectedCards.remove(index);
      } else {
        _selectedCards.add(index);
      }
      _localStatus = _selectedCards.isEmpty
          ? null
          : 'Đã chọn ${_selectedCards.length} lá · Bấm Đánh bài để gửi lượt';
    });
  }

  Future<void> _sortCards() async {
    if (_actionInFlight || _isSpectating) return;
    setState(() => _actionInFlight = true);
    try {
      final state = await context.read<ChatSocketService>().sortTienLenHand();
      if (!mounted) return;
      setState(() {
        _state = state;
        _selectedCards.clear();
        _localStatus = 'Đã sắp bài theo thứ tự tăng dần';
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _localStatus = 'Không sắp bài được: ${_shortError(error)}',
      );
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  Future<void> _playCards() async {
    if (!_isHumanTurn ||
        _selectedCards.isEmpty ||
        _actionInFlight ||
        _turnExpired) {
      return;
    }
    final indexes = _selectedCards.toList()..sort();
    final cards = _humanCards;
    final codes = <String>[
      for (final index in indexes)
        if (index >= 0 && index < cards.length) cards[index].code,
    ];
    setState(() => _actionInFlight = true);
    try {
      final state = await context.read<ChatSocketService>().playTienLenCards(
        codes,
      );
      if (!mounted) return;
      GameAudio.playCard();
      setState(() {
        _state = state;
        _selectedCards.clear();
        _localStatus = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _localStatus = 'Không đánh được: ${_shortError(error)}');
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  Future<void> _passTurn() async {
    if (!_isHumanTurn || _actionInFlight || _turnExpired) return;
    setState(() => _actionInFlight = true);
    try {
      final state = await context.read<ChatSocketService>().passTienLenTurn();
      if (!mounted) return;
      setState(() {
        _state = state;
        _selectedCards.clear();
        _localStatus = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _localStatus = 'Không bỏ lượt được: ${_shortError(error)}',
      );
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  Future<void> _startNextRound() async {
    if (_actionInFlight ||
        !_state.isHost ||
        !_state.canStartNextRoundAt(DateTime.now())) {
      return;
    }
    setState(() {
      _actionInFlight = true;
      _localStatus = 'Đang chia ván mới...';
    });
    try {
      final state = await context.read<ChatSocketService>().startTienLenRoom();
      if (!mounted) return;
      _applyRealtimeState(state);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _localStatus = 'Không bắt đầu được ván mới: ${_shortError(error)}';
      });
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  Future<void> _retrySettlement() async {
    if (_actionInFlight ||
        !_state.isHost ||
        !_state.isRoundEnded ||
        !_state.isSettlementFailed) {
      return;
    }
    setState(() {
      _actionInFlight = true;
      _localStatus = 'Đang thử chốt kết quả và cập nhật ví...';
    });
    try {
      final state = await context
          .read<ChatSocketService>()
          .retryTienLenSettlement();
      if (!mounted) return;
      _applyRealtimeState(state);
      if (state.isSettlementSettled) {
        unawaited(_refreshWalletForRound(state.roundNumber));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _localStatus = 'Chưa cập nhật được ví: ${_shortError(error)}';
      });
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  String _shortError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '');
    final normalized = raw.toLowerCase();
    if (raw.contains('spectator-waiting-next-round')) {
      return 'bạn đang chờ vào ván sau';
    }
    if (raw.contains('not-your-turn')) return 'chưa đến lượt bạn';
    if (raw.contains('invalid-play')) return 'bộ bài chưa hợp lệ';
    if (raw.contains('cannot-pass-opening-turn')) {
      return 'đang mở lượt nên không thể bỏ';
    }
    if (raw.contains('next-round-countdown')) {
      return 'vui lòng chờ đủ 15 giây trước ván mới';
    }
    if (normalized.contains('bot-matchmaking-pending')) {
      return 'đang ghép người chơi, vui lòng chờ trong giây lát';
    }
    if (normalized.contains('bot') ||
        normalized.contains('bankroll') ||
        normalized.contains('system-opponent')) {
      return 'dịch vụ bàn chơi tạm thời chưa sẵn sàng, vui lòng thử lại';
    }
    return raw;
  }

  Future<void> _openMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF20A2C27),
      barrierColor: Colors.black54,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'Tùy chọn bàn chơi',
                  style: TextStyle(
                    color: GameTheme.ivory,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.chat_bubble_outline,
                    color: GameTheme.mint,
                  ),
                  title: const Text(
                    'Chat trong bàn',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openRoomChat();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.emoji_emotions_outlined,
                    color: GameTheme.gold,
                  ),
                  title: const Text(
                    'Thả biểu cảm',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openReactionPicker();
                  },
                ),
                if (_state.isHost)
                  for (final player in <TienLenRealtimePlayer>[
                    ..._state.players,
                    ..._state.spectators,
                  ])
                    if (player.id != _state.viewerId && player.connected)
                      ListTile(
                        leading: const Icon(
                          Icons.person_remove_outlined,
                          color: Color(0xFFFFAE8A),
                        ),
                        title: Text(
                          'Mời ${player.name} rời bàn',
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          _kickPlayerFromTable(player);
                        },
                      ),
                ListTile(
                  leading: const Icon(Icons.exit_to_app, color: GameTheme.gold),
                  title: const Text(
                    'Rời bàn',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _leaveAndPop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _kickPlayerFromTable(TienLenRealtimePlayer player) async {
    if (!_state.isHost || _actionInFlight) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mời người chơi rời bàn?'),
        content: Text(
          '${player.name} sẽ rời bàn ngay. Nếu ván đang chơi, '
          'bài và xu của ván này vẫn được chốt khi ván kết thúc.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Mời rời bàn'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _actionInFlight = true);
    try {
      final state = await context.read<ChatSocketService>().kickTienLenPlayer(
        player.id,
      );
      if (mounted) _applyRealtimeState(state);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('Chưa mời được: ${_shortError(error)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  Future<void> _openRoomChat() async {
    final controller = TextEditingController();
    var sending = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xF20A2C27),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Future<void> submit() async {
            final message = controller.text.trim();
            if (message.isEmpty || sending) return;
            setSheetState(() => sending = true);
            try {
              await context.read<ChatSocketService>().sendTienLenChat(message);
              if (sheetContext.mounted) controller.clear();
            } catch (error) {
              if (sheetContext.mounted) {
                ScaffoldMessenger.maybeOf(sheetContext)?.showSnackBar(
                  SnackBar(
                    content: Text('Không gửi được: ${_shortError(error)}'),
                  ),
                );
              }
            } finally {
              if (sheetContext.mounted) setSheetState(() => sending = false);
            }
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                14,
                18,
                MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
              ),
              child: SizedBox(
                height: 340,
                child: Column(
                  children: <Widget>[
                    const Text(
                      'Chat trong bàn',
                      style: TextStyle(
                        color: GameTheme.ivory,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: StreamBuilder<TienLenRoomState>(
                        stream: _socketService?.tienLenRoomStateStream,
                        initialData: _state,
                        builder: (context, snapshot) {
                          final state = snapshot.data?.roomId == _state.roomId
                              ? snapshot.data!
                              : _state;
                          final messages = state.chatMessages;
                          if (messages.isEmpty) {
                            return const Center(
                              child: Text(
                                'Chưa có tin nhắn',
                                style: TextStyle(color: Colors.white70),
                              ),
                            );
                          }
                          return ListView.builder(
                            reverse: true,
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message =
                                  messages[messages.length - index - 1];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Text(
                                  '${message['name'] ?? 'Người chơi'}: ${message['message'] ?? ''}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: controller,
                            maxLength: 280,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Nhập lời nhắn...',
                              hintStyle: TextStyle(color: Colors.white60),
                              counterText: '',
                            ),
                            onSubmitted: (_) => submit(),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Gửi tin nhắn',
                          onPressed: sending ? null : submit,
                          icon: const Icon(
                            Icons.send_rounded,
                            color: GameTheme.mint,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    controller.dispose();
  }

  Future<void> _openReactionPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF20A2C27),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _reactionEmoji.entries
                .map(
                  (entry) => InkWell(
                    key: ValueKey<String>('reaction-${entry.key}'),
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      try {
                        await context
                            .read<ChatSocketService>()
                            .sendTienLenReaction(entry.key);
                      } catch (error) {
                        if (mounted) {
                          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Chưa thả được biểu cảm: ${_shortError(error)}',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        entry.value,
                        style: const TextStyle(fontSize: 36),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final human = _isSpectating ? _viewerProfilePlayer : _humanTablePlayer;
    final bottomPlayer = _tablePlayerAt(0);
    final lastPlay = _lastPlay;
    final remaining = _state.remainingTurnSeconds(_now);
    final nextRoundRemaining = _state.remainingNextRoundSeconds(_now);
    final visibleTableCards = _state.tableCards
        .map((card) => card.playingCard)
        .toList(growable: false);
    final currentPlayerName = _state.currentTurnPlayer?.name ?? 'Người chơi';
    final winnerName = _state.finishedOrder.isEmpty
        ? null
        : _playerNameById(_state.finishedOrder.first);
    final bool? viewerWon = _isSpectating
        ? null
        : _state.finishedOrder.isNotEmpty &&
              _state.finishedOrder.first == _state.viewerId;

    return PopScope<void>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_leaveAndPop());
      },
      child: GameStage(
        backgroundAsset: 'assets/game_tien_len/backgrounds/table_stage.png',
        stageWidth: 1659,
        stageHeight: 948,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 26),
          child: Column(
            children: <Widget>[
              SizedBox(
                height: 62,
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: GptButton(
                        assetPath:
                            'assets/game_tien_len/buttons/table_menu.png',
                        semanticLabel: 'Mở menu bàn chơi',
                        onPressed: _openMenu,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        '${widget.room.title} · ID ${_state.roomId} · '
                        '${_state.activePlayerCount}/${_state.maxPlayers} đang chơi · '
                        'Ván ${_state.roundNumber}',
                        style: const TextStyle(
                          color: GameTheme.ivory,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          shadows: <Shadow>[
                            Shadow(color: Colors.black, blurRadius: 8),
                          ],
                        ),
                      ),
                    ),
                    if (_state.spectators.isNotEmpty) ...<Widget>[
                      _WaitingEntrantsBadge(spectators: _state.spectators),
                      const SizedBox(width: 10),
                    ],
                    if (_recentReaction != null) ...<Widget>[
                      Text(
                        _recentReaction!,
                        style: const TextStyle(
                          color: GameTheme.ivory,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (_state.chatMessages.isNotEmpty) ...<Widget>[
                      InkWell(
                        onTap: _openRoomChat,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 250),
                          child: Text(
                            '${_state.chatMessages.last['name'] ?? 'Người chơi'}: '
                            '${_state.chatMessages.last['message'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: GameTheme.ivory,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    IconButton(
                      key: const ValueKey<String>('realtime-chat-button'),
                      tooltip: 'Chat trong bàn',
                      onPressed: _openRoomChat,
                      icon: const Icon(
                        Icons.chat_bubble_rounded,
                        color: GameTheme.mint,
                        size: 30,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey<String>('realtime-reaction-button'),
                      tooltip: 'Thả biểu cảm',
                      onPressed: _openReactionPicker,
                      icon: const Icon(
                        Icons.emoji_emotions_rounded,
                        color: GameTheme.gold,
                        size: 30,
                      ),
                    ),
                    ProfileChip(name: human.name, balance: human.coins),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        children: <Widget>[
                          SizedBox(
                            height: 74,
                            child: _TopOpponentSlot(
                              player: _tablePlayerAt(2),
                              active: _isActiveSeat(2),
                              finished: _isFinishedSeat(2),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                SizedBox(
                                  width: 68,
                                  child: _SideOpponentSlot(
                                    player: _tablePlayerAt(1),
                                    active: _isActiveSeat(1),
                                    finished: _isFinishedSeat(1),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _CenterBoard(
                                    cards: visibleTableCards,
                                    coveredCardCount:
                                        _state.coveredTableCardCount,
                                    currentPlay: lastPlay,
                                    lastActorName: _playerNameById(
                                      _state.lastActorId,
                                    ),
                                    currentPlayerName: currentPlayerName,
                                    isHumanTurn: _isHumanTurn,
                                    isSpectator: _isSpectating,
                                    roundEnded: _state.isRoundEnded,
                                    remainingSeconds: remaining,
                                    newRoundRemainingSeconds:
                                        nextRoundRemaining,
                                    turnLogs: _state.turnLogs,
                                    roundResultLabel: winnerName == null
                                        ? null
                                        : viewerWon == true
                                        ? 'Bạn về nhất trong ván này'
                                        : '$winnerName thắng ván này',
                                    viewerWon: viewerWon,
                                    viewerCoinDelta:
                                        _state.viewerRoundCoinDelta,
                                    viewerBalance: human.coins,
                                    settlementMessage:
                                        _state.isSettlementPending
                                        ? 'Đang chốt kết quả và cập nhật ví...'
                                        : _state.isSettlementFailed
                                        ? 'Không thể cập nhật ví. Chủ bàn cần thử lại.'
                                        : null,
                                    waitingForHost:
                                        !_state.isHost &&
                                        _state.canStartNextRound &&
                                        nextRoundRemaining == 0,
                                    onRetrySettlement:
                                        _state.isHost &&
                                            _state.isSettlementFailed &&
                                            !_actionInFlight
                                        ? _retrySettlement
                                        : null,
                                    onStartNextRound:
                                        _state.isHost &&
                                            _state.canStartNextRoundAt(_now) &&
                                            !_actionInFlight
                                        ? _startNextRound
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 68,
                                  child: _SideOpponentSlot(
                                    player: _tablePlayerAt(3),
                                    active: _isActiveSeat(3),
                                    finished: _isFinishedSeat(3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 236,
                            child: _isSpectating
                                ? _SpectatorBottomSeat(
                                    player: bottomPlayer,
                                    active: _isActiveSeat(0),
                                    viewerName: human.name,
                                    waitingReason:
                                        _state.viewerSpectator?.waitingReason,
                                  )
                                : _PlayerHand(
                                    player: human,
                                    active: _isHumanTurn,
                                    cards: human.hand,
                                    onCardTap: _toggleCard,
                                    selected: _selectedCards,
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    SizedBox(
                      width: 128,
                      child: Column(
                        children: <Widget>[
                          Expanded(
                            child: GptButton(
                              key: const ValueKey<String>(
                                'realtime-sort-button',
                              ),
                              assetPath:
                                  'assets/game_tien_len/buttons/sort_cards.png',
                              semanticLabel: 'Sắp bài',
                              onPressed: _actionInFlight || _isSpectating
                                  ? null
                                  : _sortCards,
                            ),
                          ),
                          Expanded(
                            child: GptButton(
                              key: const ValueKey<String>(
                                'realtime-play-button',
                              ),
                              assetPath:
                                  'assets/game_tien_len/buttons/play_card.png',
                              semanticLabel: 'Đánh bài',
                              onPressed:
                                  _isHumanTurn &&
                                      !_turnExpired &&
                                      !_actionInFlight &&
                                      _selectedCards.isNotEmpty
                                  ? _playCards
                                  : null,
                            ),
                          ),
                          Expanded(
                            child: GptButton(
                              key: const ValueKey<String>(
                                'realtime-pass-button',
                              ),
                              assetPath:
                                  'assets/game_tien_len/buttons/pass_turn.png',
                              semanticLabel: 'Bỏ lượt',
                              onPressed:
                                  _isHumanTurn &&
                                      !_turnExpired &&
                                      !_actionInFlight &&
                                      lastPlay != null
                                  ? _passTurn
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.center,
                child: _TurnBanner(
                  message: _status,
                  highlighted: _isHumanTurn && !_isSpectating,
                  roundEnded: _state.isRoundEnded,
                  remainingSeconds: remaining,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaitingEntrantsBadge extends StatelessWidget {
  const _WaitingEntrantsBadge({required this.spectators});

  final List<TienLenRealtimePlayer> spectators;

  @override
  Widget build(BuildContext context) {
    final names = spectators.map((player) => player.name).join(', ');
    final hasInsufficientBalance = spectators.any(
      (player) => player.waitingReason == 'insufficient-coins',
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: DecoratedBox(
        key: const ValueKey<String>('waiting-next-round-badge'),
        decoration: BoxDecoration(
          color: const Color(0xD9072C31),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasInsufficientBalance
                ? const Color(0xFFFFB36B)
                : GameTheme.mint.withValues(alpha: 0.7),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                hasInsufficientBalance
                    ? Icons.account_balance_wallet_outlined
                    : Icons.event_seat_rounded,
                size: 17,
                color: hasInsufficientBalance
                    ? const Color(0xFFFFC07A)
                    : GameTheme.mint,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  '$names · ${hasInsufficientBalance ? 'Chờ đủ xu' : 'Đang chờ vào ván sau'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: GameTheme.ivory,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpectatorBottomSeat extends StatelessWidget {
  const _SpectatorBottomSeat({
    required this.player,
    required this.active,
    required this.viewerName,
    this.waitingReason,
  });

  final _TablePlayer? player;
  final bool active;
  final String viewerName;
  final String? waitingReason;

  @override
  Widget build(BuildContext context) {
    final seatPlayer = player;
    final insufficientCoins = waitingReason == 'insufficient-coins';
    final waitingMessage = insufficientCoins
        ? 'Đang xem ván hiện tại · Cần đủ xu để vào ván sau'
        : 'Đang xem ván hiện tại · Bạn sẽ vào từ ván kế tiếp';
    return Semantics(
      liveRegion: true,
      label: insufficientCoins
          ? '$viewerName đang xem, số dư chưa đủ để vào ván sau'
          : '$viewerName đang xem và chờ vào ván sau',
      child: DecoratedBox(
        key: const ValueKey<String>('spectator-waiting-panel'),
        decoration: BoxDecoration(
          color: const Color(0xB9072529),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: GameTheme.mint.withValues(alpha: 0.65)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 9, 14, 10),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  if (seatPlayer != null) ...<Widget>[
                    _SeatBadge(
                      name: active
                          ? '${seatPlayer.name} · Đang đánh'
                          : seatPlayer.name,
                      compact: true,
                      active: active,
                    ),
                    const SizedBox(width: 8),
                    _CoinPill(coins: seatPlayer.coins),
                  ] else
                    const Text(
                      'Chờ người chơi',
                      style: TextStyle(
                        color: Colors.white60,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  const Spacer(),
                  const Icon(
                    Icons.visibility_rounded,
                    color: GameTheme.mint,
                    size: 19,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'ĐANG XEM',
                    style: TextStyle(
                      color: GameTheme.mint,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: seatPlayer == null || seatPlayer.hand.isEmpty
                    ? const SizedBox.shrink()
                    : Center(
                        child: SizedBox(
                          width: 420,
                          height: 105,
                          child: _TopCardBackFan(count: seatPlayer.hand.length),
                        ),
                      ),
              ),
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: Color(0xD914443E),
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  child: Text(
                    waitingMessage,
                    key: const ValueKey<String>('spectator-waiting-message'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: GameTheme.ivory,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TurnBanner extends StatelessWidget {
  const _TurnBanner({
    required this.message,
    required this.highlighted,
    required this.roundEnded,
    required this.remainingSeconds,
  });

  final String message;
  final bool highlighted;
  final bool roundEnded;
  final int remainingSeconds;

  @override
  Widget build(BuildContext context) {
    final Color accent = roundEnded
        ? GameTheme.gold
        : highlighted
        ? const Color(0xFF52F7FF)
        : const Color(0xFFFFD675);
    final Color timerAccent = remainingSeconds <= 5 && !roundEnded
        ? const Color(0xFFFF756D)
        : accent;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1060),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[Color(0xF20A2836), Color(0xF20D5B4E)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent.withValues(alpha: 0.82), width: 1.5),
          boxShadow: <BoxShadow>[
            BoxShadow(color: accent.withValues(alpha: 0.42), blurRadius: 20),
            const BoxShadow(color: Color(0x99000000), blurRadius: 14),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 9),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 340),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
                  child: child,
                ),
              );
            },
            child: Row(
              key: ValueKey<String>(message),
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  roundEnded
                      ? Icons.emoji_events
                      : highlighted
                      ? Icons.touch_app
                      : Icons.bolt,
                  color: accent,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: GameTheme.ivory,
                      fontFamily: 'Rowdies',
                      fontSize: highlighted ? 16 : 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                      shadows: const <Shadow>[
                        Shadow(color: Colors.black, blurRadius: 7),
                        Shadow(color: Color(0xAAE8B84D), blurRadius: 13),
                      ],
                    ),
                  ),
                ),
                if (!roundEnded) ...<Widget>[
                  const SizedBox(width: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xAA071B1B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: timerAccent.withValues(alpha: 0.9),
                        width: 1.5,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: timerAccent.withValues(alpha: 0.28),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Text(
                            '$remainingSeconds',
                            style: TextStyle(
                              color: timerAccent,
                              fontFamily: 'Bungee',
                              fontSize: 24,
                              height: 0.9,
                              fontWeight: FontWeight.w900,
                              shadows: <Shadow>[
                                Shadow(color: timerAccent, blurRadius: 10),
                              ],
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 1),
                            child: Text(
                              'GIÂY',
                              style: TextStyle(
                                color: GameTheme.ivory,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopOpponentSlot extends StatelessWidget {
  const _TopOpponentSlot({
    required this.player,
    required this.active,
    required this.finished,
  });

  final _TablePlayer? player;
  final bool active;
  final bool finished;

  @override
  Widget build(BuildContext context) {
    final _TablePlayer? seatPlayer = player;
    if (seatPlayer == null) {
      return const _EmptyTopSeat();
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _SeatBadge(
          name: finished
              ? '${seatPlayer.name} · Xong bài'
              : active
              ? '${seatPlayer.name} · Đang đánh'
              : seatPlayer.name,
          compact: true,
          active: active,
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 260,
          height: 62,
          child: finished
              ? const _FinishedSeatPill()
              : _TopCardBackFan(count: seatPlayer.hand.length),
        ),
        const SizedBox(width: 12),
        _CoinPill(coins: seatPlayer.coins),
      ],
    );
  }
}

class _EmptyTopSeat extends StatelessWidget {
  const _EmptyTopSeat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x66071917),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white24),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          child: Text(
            'Chờ người chơi',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _TopCardBackFan extends StatelessWidget {
  const _TopCardBackFan({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final int visibleCount = count.clamp(0, 13).toInt();
    if (visibleCount == 0) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double cardHeight = constraints.maxHeight;
        final double cardWidth = math.min(42, cardHeight / 1.45);
        final double maxStep = visibleCount == 1
            ? 0
            : (constraints.maxWidth - cardWidth) / (visibleCount - 1);
        final double step = visibleCount == 1
            ? 0
            : math.max(0, math.min(cardWidth * 0.48, maxStep));
        final double totalWidth = cardWidth + (step * (visibleCount - 1));
        final double startLeft = math.max(
          0,
          (constraints.maxWidth - totalWidth) / 2,
        );

        return Stack(
          clipBehavior: Clip.none,
          children: List<Widget>.generate(
            visibleCount,
            (int index) => Positioned(
              left: startLeft + (index * step),
              top: 0,
              width: cardWidth,
              height: cardHeight,
              child: CardBackView(key: ValueKey<int>(index)),
            ),
          ),
        );
      },
    );
  }
}

class _SideOpponentSlot extends StatelessWidget {
  const _SideOpponentSlot({
    required this.player,
    required this.active,
    required this.finished,
  });

  final _TablePlayer? player;
  final bool active;
  final bool finished;

  @override
  Widget build(BuildContext context) {
    final _TablePlayer? seatPlayer = player;
    if (seatPlayer == null) {
      return const _EmptySideSeat();
    }
    final Color accent = finished
        ? GameTheme.gold
        : active
        ? const Color(0xFF52F7FF)
        : Colors.white54;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(
          finished
              ? Icons.done_all
              : active
              ? Icons.bolt
              : Icons.person,
          color: accent,
          size: 24,
        ),
        Text(
          seatPlayer.name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: active || finished ? GameTheme.ivory : Colors.white60,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          finished ? 'Xong bài' : '${seatPlayer.hand.length} lá',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: accent,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0x33000000),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withValues(alpha: 0.5)),
            ),
            child: finished
                ? const Center(
                    child: Icon(Icons.emoji_events, color: GameTheme.gold),
                  )
                : Stack(
                    alignment: Alignment.topCenter,
                    children: <Widget>[
                      for (
                        int index = 0;
                        index < math.min(seatPlayer.hand.length, 5);
                        index++
                      )
                        Positioned(
                          top: 8.0 + index * 18,
                          child: SizedBox(
                            width: 42,
                            height: 58,
                            child: CardBackView(key: ValueKey<int>(index)),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _EmptySideSeat extends StatelessWidget {
  const _EmptySideSeat();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Icon(Icons.person_off, color: Colors.white30, size: 22),
        const Text(
          'Trống',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0x22000000),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white24),
            ),
            child: const Center(
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(
                  'Không thêm đối thủ',
                  style: TextStyle(
                    color: Colors.white30,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FinishedSeatPill extends StatelessWidget {
  const _FinishedSeatPill();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xAA23180A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GameTheme.gold.withValues(alpha: 0.75)),
      ),
      child: const Center(
        child: Text(
          'XONG BÀI',
          style: TextStyle(
            color: GameTheme.gold,
            fontFamily: 'Bungee',
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _CenterBoard extends StatelessWidget {
  const _CenterBoard({
    required this.cards,
    required this.coveredCardCount,
    required this.currentPlay,
    required this.lastActorName,
    required this.currentPlayerName,
    required this.isHumanTurn,
    this.isSpectator = false,
    required this.roundEnded,
    required this.remainingSeconds,
    required this.newRoundRemainingSeconds,
    required this.turnLogs,
    this.roundResultLabel,
    this.viewerWon,
    this.viewerCoinDelta = 0,
    this.viewerBalance,
    this.settlementMessage,
    this.waitingForHost = false,
    this.onRetrySettlement,
    this.onStartNextRound,
  });

  final List<PlayingCardData> cards;
  final int coveredCardCount;
  final PlayEvaluation? currentPlay;
  final String? lastActorName;
  final String currentPlayerName;
  final bool isHumanTurn;
  final bool isSpectator;
  final bool roundEnded;
  final int remainingSeconds;
  final int newRoundRemainingSeconds;
  final List<String> turnLogs;
  final String? roundResultLabel;
  final bool? viewerWon;
  final int viewerCoinDelta;
  final int? viewerBalance;
  final String? settlementMessage;
  final bool waitingForHost;
  final VoidCallback? onRetrySettlement;
  final VoidCallback? onStartNextRound;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xB3072740),
            Color(0xAA061825),
            Color(0xA1114A3F),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0x8838DFFF), width: 1.4),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x88000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
          BoxShadow(color: Color(0x4438DFFF), blurRadius: 24),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  roundEnded
                      ? Icons.emoji_events
                      : isSpectator
                      ? Icons.visibility_rounded
                      : isHumanTurn
                      ? Icons.touch_app
                      : Icons.person_pin_circle,
                  color: const Color(0xFFFFD675),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  roundEnded
                      ? 'KẾT QUẢ VÁN'
                      : isSpectator
                      ? 'ĐANG XEM VÁN HIỆN TẠI'
                      : isHumanTurn
                      ? 'LƯỢT CỦA BẠN'
                      : 'LƯỢT ${currentPlayerName.toUpperCase()}',
                  style: const TextStyle(
                    color: GameTheme.ivory,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const Spacer(),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0x6600BFE8),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x8838DFFF)),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Text(
                      'Tiến Lên Miền Nam',
                      style: TextStyle(
                        color: Color(0xFFC8F8FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (currentPlay != null)
              Padding(
                padding: const EdgeInsets.only(top: 9),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0x991B3A4A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: GameTheme.gold.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Text(
                        '${lastActorName ?? 'Người chơi'} · ${PlayRules.describe(currentPlay)}',
                        style: const TextStyle(
                          color: GameTheme.ivory,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (!roundEnded)
              Padding(
                padding: const EdgeInsets.only(top: 9),
                child: _TurnNotice(
                  isHumanTurn: isHumanTurn,
                  isSpectator: isSpectator,
                  currentPlayerName: currentPlayerName,
                  remainingSeconds: remainingSeconds,
                ),
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: roundEnded
                    ? _RoundCountdownPanel(
                        key: const ValueKey<String>('round-countdown'),
                        remainingSeconds: newRoundRemainingSeconds,
                        resultLabel: roundResultLabel,
                        viewerWon: viewerWon,
                        viewerCoinDelta: viewerCoinDelta,
                        viewerBalance: viewerBalance,
                        settlementMessage: settlementMessage,
                        waitingForHost: waitingForHost,
                        onRetrySettlement: onRetrySettlement,
                        onStartNextRound: onStartNextRound,
                      )
                    : cards.isEmpty
                    ? _EmptyBoard(isSpectator: isSpectator)
                    : _PlayedCardStack(
                        key: ValueKey<String>(
                          cards
                              .map((PlayingCardData card) => card.label)
                              .join(),
                        ),
                        cards: cards,
                        coveredCardCount: coveredCardCount,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            _TurnLogPanel(logs: turnLogs),
          ],
        ),
      ),
    );
  }
}

class _TurnNotice extends StatelessWidget {
  const _TurnNotice({
    required this.isHumanTurn,
    this.isSpectator = false,
    required this.currentPlayerName,
    required this.remainingSeconds,
  });

  final bool isHumanTurn;
  final bool isSpectator;
  final String currentPlayerName;
  final int remainingSeconds;

  @override
  Widget build(BuildContext context) {
    final Color accent = isHumanTurn
        ? const Color(0xFF52F7FF)
        : const Color(0xFFFFD675);
    final Color timerAccent = remainingSeconds <= 5
        ? const Color(0xFFFF756D)
        : accent;
    final String title = isSpectator
        ? '${currentPlayerName.toUpperCase()} ĐANG ĐÁNH'
        : isHumanTurn
        ? 'ĐẾN LƯỢT BẠN!'
        : '${currentPlayerName.toUpperCase()} ĐANG SUY NGHĨ';
    final String subtitle = isSpectator
        ? 'Bạn đang xem và sẽ vào từ ván kế tiếp'
        : isHumanTurn
        ? 'Chọn bài rồi bấm Đánh bài ngay'
        : 'Vui lòng chờ lượt tiếp theo';

    return Semantics(
      liveRegion: true,
      label: isSpectator
          ? 'Đang xem lượt của $currentPlayerName, còn $remainingSeconds giây'
          : isHumanTurn
          ? 'Đến lượt bạn, còn $remainingSeconds giây'
          : 'Đang chờ $currentPlayerName, còn $remainingSeconds giây',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isHumanTurn
                ? const <Color>[Color(0xF207344B), Color(0xF20C746B)]
                : const <Color>[Color(0xE8241608), Color(0xE84C2B09)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accent.withValues(alpha: 0.95),
            width: isHumanTurn ? 2.5 : 1.8,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: accent.withValues(alpha: isHumanTurn ? 0.55 : 0.3),
              blurRadius: isHumanTurn ? 30 : 18,
              spreadRadius: isHumanTurn ? 2 : 0,
            ),
            const BoxShadow(
              color: Color(0x99000000),
              blurRadius: 14,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(color: accent.withValues(alpha: 0.65)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  isHumanTurn ? Icons.touch_app_rounded : Icons.hourglass_top,
                  color: accent,
                  size: 25,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isHumanTurn
                          ? const Color(0xFFE9FFFF)
                          : GameTheme.ivory,
                      fontFamily: 'Bungee',
                      fontSize: isHumanTurn ? 21 : 17,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                      shadows: const <Shadow>[
                        Shadow(color: Colors.black, blurRadius: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accent.withValues(alpha: 0.96),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              constraints: const BoxConstraints(minWidth: 92),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xD9071B1B),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: timerAccent, width: 2),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: timerAccent.withValues(alpha: 0.45),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '$remainingSeconds',
                    style: TextStyle(
                      color: timerAccent,
                      fontFamily: 'Bungee',
                      fontSize: 32,
                      height: 0.9,
                      fontWeight: FontWeight.w900,
                      shadows: <Shadow>[
                        Shadow(color: timerAccent, blurRadius: 12),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'GIÂY CÒN LẠI',
                    style: TextStyle(
                      color: GameTheme.ivory,
                      fontSize: 9,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
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

class _RoundCountdownPanel extends StatelessWidget {
  const _RoundCountdownPanel({
    required this.remainingSeconds,
    this.resultLabel,
    this.viewerWon,
    this.viewerCoinDelta = 0,
    this.viewerBalance,
    this.settlementMessage,
    this.waitingForHost = false,
    this.onRetrySettlement,
    this.onStartNextRound,
    super.key,
  });

  final int remainingSeconds;
  final String? resultLabel;
  final bool? viewerWon;
  final int viewerCoinDelta;
  final int? viewerBalance;
  final String? settlementMessage;
  final bool waitingForHost;
  final VoidCallback? onRetrySettlement;
  final VoidCallback? onStartNextRound;

  @override
  Widget build(BuildContext context) {
    final bool hasViewerResult = viewerWon != null;
    final Color resultAccent = viewerWon == true
        ? const Color(0xFFFFD75E)
        : viewerWon == false
        ? const Color(0xFFFF8B7F)
        : GameTheme.gold;
    final String resultTitle = viewerWon == true
        ? 'BẠN ĐÃ CHIẾN THẮNG'
        : viewerWon == false
        ? 'BẠN ĐÃ THUA'
        : onStartNextRound != null ||
              onRetrySettlement != null ||
              settlementMessage != null ||
              waitingForHost
        ? 'KẾT QUẢ VÁN'
        : 'TỰ CHIA VÁN MỚI';
    final String signedDelta = viewerCoinDelta > 0
        ? '+$viewerCoinDelta'
        : '$viewerCoinDelta';

    return Center(
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: <Widget>[
          if (viewerWon == true) const _WinnerCoinBurst(),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Color(0xF2331B06),
                    Color(0xF20E3F36),
                    Color(0xF2071F29),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: resultAccent, width: 2.4),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: resultAccent.withValues(alpha: 0.55),
                    blurRadius: 36,
                    spreadRadius: 2,
                  ),
                  const BoxShadow(color: Color(0xCC000000), blurRadius: 26),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 20,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: resultAccent.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: resultAccent.withValues(alpha: 0.7),
                          width: 2,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(13),
                        child: Icon(
                          viewerWon == false
                              ? Icons.sports_score_rounded
                              : Icons.emoji_events_rounded,
                          color: resultAccent,
                          size: 48,
                          shadows: const <Shadow>[
                            Shadow(color: Colors.black, blurRadius: 10),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            resultTitle,
                            style: TextStyle(
                              color: resultAccent,
                              fontFamily: 'Bungee',
                              fontSize: 25,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                              shadows: const <Shadow>[
                                Shadow(color: Colors.black, blurRadius: 10),
                              ],
                            ),
                          ),
                          if (resultLabel != null) ...<Widget>[
                            const SizedBox(height: 7),
                            Text(
                              resultLabel!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFD9F9FF),
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                          if (hasViewerResult) ...<Widget>[
                            const SizedBox(height: 10),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0xB8071B1B),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: resultAccent.withValues(alpha: 0.65),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                  vertical: 8,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      Icons.monetization_on_rounded,
                                      color: resultAccent,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      settlementMessage != null
                                          ? 'TẠM TÍNH $signedDelta XU'
                                          : '$signedDelta XU',
                                      style: TextStyle(
                                        color: resultAccent,
                                        fontFamily: 'Bungee',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    if (viewerBalance != null)
                                      Text(
                                        '  ·  Số dư $viewerBalance xu',
                                        style: const TextStyle(
                                          color: GameTheme.ivory,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          if (settlementMessage != null) ...<Widget>[
                            const SizedBox(height: 9),
                            Text(
                              settlementMessage!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: onRetrySettlement != null
                                    ? const Color(0xFFFFB4A9)
                                    : const Color(0xFFFFD675),
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          if (onRetrySettlement != null)
                            FilledButton.icon(
                              onPressed: onRetrySettlement,
                              icon: const Icon(Icons.sync_problem_rounded),
                              label: const Text('Thử chốt ví lại'),
                            )
                          else if (onStartNextRound != null)
                            FilledButton.icon(
                              onPressed: onStartNextRound,
                              icon: const Icon(Icons.replay_rounded),
                              label: const Text('Chia ván mới'),
                            )
                          else if (settlementMessage != null)
                            const SizedBox.shrink()
                          else if (waitingForHost)
                            const Text(
                              'Đang chờ chủ bàn chia ván mới...',
                              style: TextStyle(
                                color: Color(0xFFC8F8FF),
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          else
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Text(
                                  'Ván mới sau',
                                  style: TextStyle(
                                    color: Color(0xFFC8F8FF),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$remainingSeconds GIÂY',
                                  style: const TextStyle(
                                    color: Color(0xFF52F7FF),
                                    fontFamily: 'Bungee',
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
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

class _WinnerCoinBurst extends StatelessWidget {
  const _WinnerCoinBurst();

  static const int _coinCount = 12;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: 700,
        height: 300,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1500),
          curve: Curves.easeOutCubic,
          builder: (BuildContext context, double progress, Widget? child) {
            final double opacity = (1 - progress).clamp(0, 1);
            return Stack(
              clipBehavior: Clip.none,
              children: List<Widget>.generate(_coinCount, (int index) {
                final double angle =
                    (-math.pi * 0.92) + (math.pi * 1.84 * index / 11);
                final double distance = 55 + (175 * progress);
                final double x = math.cos(angle) * distance;
                final double y = math.sin(angle) * distance - (25 * progress);
                final double size = 22 + ((index % 3) * 4);
                return Positioned(
                  left: 350 - (size / 2),
                  top: 150 - (size / 2),
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.translate(
                      offset: Offset(x, y),
                      child: Transform.rotate(
                        angle: progress * (index.isEven ? 4 : -4),
                        child: Icon(
                          Icons.monetization_on_rounded,
                          size: size,
                          color: index.isEven
                              ? const Color(0xFFFFD75E)
                              : const Color(0xFFFFA928),
                          shadows: const <Shadow>[
                            Shadow(color: Color(0xCC000000), blurRadius: 7),
                            Shadow(color: Color(0xAAFFD75E), blurRadius: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

class _TurnLogPanel extends StatelessWidget {
  const _TurnLogPanel({required this.logs});

  final List<String> logs;

  @override
  Widget build(BuildContext context) {
    final List<String> shownLogs = logs.take(4).toList();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x99051014),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GameTheme.gold.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'DIỄN BIẾN LƯỢT',
              style: TextStyle(
                color: GameTheme.gold,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            for (final String log in shownLogs)
              Text(
                '• $log',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: GameTheme.ivory,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard({this.isSpectator = false});

  final bool isSpectator;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey<String>('empty-board'),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x44000000),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0x5538DFFF)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          child: Text(
            isSpectator
                ? 'Đang chờ người chơi mở lượt'
                : 'Chọn bài và đánh để mở lượt',
            style: const TextStyle(
              color: Color(0xFFC8F8FF),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayedCardStack extends StatelessWidget {
  const _PlayedCardStack({
    required this.cards,
    required this.coveredCardCount,
    super.key,
  });

  final List<PlayingCardData> cards;
  final int coveredCardCount;

  @override
  Widget build(BuildContext context) {
    final int shownCount = cards.length.clamp(1, 9);
    final List<PlayingCardData> shownCards = cards.length > 9
        ? cards.sublist(cards.length - 9)
        : cards;
    final double cardWidth = shownCount > 5 ? 114 : 138;
    final double cardHeight = cardWidth * 1.45;

    return SizedBox(
      width: 560,
      height: cardHeight + 78,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: <Widget>[
          const Positioned(
            bottom: 20,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0x2238DFFF),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Color(0xAA38DFFF),
                    blurRadius: 42,
                    spreadRadius: 18,
                  ),
                ],
              ),
              child: SizedBox(width: 230, height: 16),
            ),
          ),
          if (coveredCardCount > 0) _FannedCardBacks(count: coveredCardCount),
          ...List<Widget>.generate(shownCount, (int index) {
            final double normalized = shownCount == 1
                ? 0
                : (index / (shownCount - 1)) * 2 - 1;
            final double gap = shownCount > 5 ? 40 : 58;
            final double lift = shownCount > 6 ? 14 : 17;
            return Transform.translate(
              offset: Offset(normalized * gap, normalized.abs() * -lift),
              child: Transform.rotate(
                angle: normalized * 0.16,
                child: SizedBox(
                  width: cardWidth,
                  height: cardHeight,
                  child: PlayingCardView(card: shownCards[index]),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _FannedCardBacks extends StatelessWidget {
  const _FannedCardBacks({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final int visibleCount = count.clamp(1, 5);
    return SizedBox(
      width: 470,
      height: 272,
      child: Stack(
        alignment: Alignment.center,
        children: List<Widget>.generate(visibleCount, (int index) {
          final double normalized = visibleCount == 1
              ? 0
              : (index / (visibleCount - 1)) * 2 - 1;
          return Transform.translate(
            offset: Offset(normalized * 52, normalized.abs() * -18),
            child: Transform.rotate(
              angle: normalized * 0.22,
              child: const SizedBox(
                width: 145,
                height: 214,
                child: CardBackView(),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PlayerHand extends StatelessWidget {
  const _PlayerHand({
    required this.player,
    required this.active,
    required this.cards,
    required this.onCardTap,
    required this.selected,
  });

  final _TablePlayer player;
  final bool active;
  final List<PlayingCardData> cards;
  final ValueChanged<int> onCardTap;
  final Set<int> selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: Row(
            children: <Widget>[
              _SeatBadge(
                name: active ? '${player.name} · Đến lượt' : player.name,
                compact: true,
                active: active,
              ),
              const SizedBox(width: 8),
              _CoinPill(coins: player.coins),
              const SizedBox(width: 8),
              Text(
                '${cards.length} lá',
                style: const TextStyle(
                  color: GameTheme.mint,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              if (cards.isEmpty) {
                return const SizedBox.shrink();
              }

              const double spacing = 4;
              final double idealHeight = math.min(constraints.maxHeight, 210);
              final double idealWidth = math.min(128, idealHeight / 1.45);
              final double fittedWidth =
                  (constraints.maxWidth - spacing * (cards.length - 1)) /
                  cards.length;
              final double cardWidth = math.max(
                56,
                math.min(idealWidth, fittedWidth),
              );
              final double cardHeight = math.min(
                constraints.maxHeight,
                cardWidth * 1.45,
              );

              return Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: cardHeight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: cards
                        .asMap()
                        .entries
                        .map(
                          (MapEntry<int, PlayingCardData> entry) => Padding(
                            padding: EdgeInsets.only(
                              right: entry.key == cards.length - 1
                                  ? 0
                                  : spacing,
                            ),
                            child: SizedBox(
                              width: cardWidth,
                              child: PlayingCardView(
                                card: entry.value,
                                selected: selected.contains(entry.key),
                                onTap: () => onCardTap(entry.key),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SeatBadge extends StatelessWidget {
  const _SeatBadge({
    required this.name,
    required this.compact,
    this.active = false,
  });

  final String name;
  final bool compact;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 5 : 8,
      ),
      decoration: BoxDecoration(
        color: active ? const Color(0xEE153D31) : const Color(0xD90B2C28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active
              ? const Color(0xFFFFD675)
              : GameTheme.gold.withValues(alpha: 0.55),
        ),
        boxShadow: active
            ? const <BoxShadow>[
                BoxShadow(color: Color(0x77FFD675), blurRadius: 16),
              ]
            : null,
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: compact ? 12 : 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CoinPill extends StatelessWidget {
  const _CoinPill({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xD90A1F1C),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: GameTheme.gold.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.monetization_on, color: GameTheme.gold, size: 14),
            const SizedBox(width: 4),
            Text(
              '$coins',
              style: const TextStyle(
                color: GameTheme.ivory,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
