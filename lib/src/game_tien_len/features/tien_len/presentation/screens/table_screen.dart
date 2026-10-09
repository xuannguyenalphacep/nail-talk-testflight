import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/audio/game_audio.dart';
import '../../../../core/theme/game_theme.dart';
import '../../../../core/widgets/card_view.dart';
import '../../../../core/widgets/game_stage.dart';
import '../../../../core/widgets/gpt_button.dart';
import '../../../../core/widgets/profile_chip.dart';
import '../../data/game_data.dart';
import '../../domain/bot_strategy.dart';
import '../../domain/play_rules.dart';
import 'lobby_screen.dart';
import 'result_screen.dart';

class TableScreen extends StatefulWidget {
  const TableScreen({
    required this.room,
    this.initialBalance = 12500,
    super.key,
  });

  final DemoRoom room;
  final int initialBalance;

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  static const int _humanIndex = 0;
  static const int _playerCount = 4;
  static const int _turnThinkingSeconds = 15;
  static const int _newRoundDelaySeconds = 8;
  static const double _botFavoredDealRate = 0.60;
  static const int _dealSearchAttempts = 80;
  static const List<String> _seatNames = <String>[
    'Tây Bích 88',
    'Minh Khang',
    'Lan Anh',
    'Hoàng Nam',
  ];

  final Set<int> _selectedCards = <int>{};
  final math.Random _random = math.Random();
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
  String _status = 'Đang chia bài...';

  int get _stake => widget.room.baseBet;
  int get _pot => _stake * _playerCount;
  bool get _isHumanTurn =>
      _currentTurn == _humanIndex && !_roundEnded && !_isFinished(_humanIndex);
  bool get _canHumanAct => _isHumanTurn && !_roundEnded;
  PlayEvaluation? get _lastPlay =>
      _playHistory.isEmpty ? null : _playHistory.last;
  _TablePlayer get _human => _players[_humanIndex];

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

    _players = List<_TablePlayer>.generate(_playerCount, (int index) {
      return _TablePlayer(
        name: _seatNames[index],
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
    _lastActor = null;
    _roundEnded = false;
    _firstPlayPending = firstTableRound;
    _currentTurn = firstTableRound
        ? _findOpeningPlayer()
        : (_nextStarter ?? _findOpeningPlayer());
    _turnLogs = <String>[
      firstTableRound
          ? 'Ván đầu: ${_displayName(_currentTurn)} có 3♠ mở lượt'
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
              ? 'Ván $_roundNumber · Bạn có 3♠, hãy mở lượt đúng luật'
              : 'Ván $_roundNumber · ${_players[_currentTurn].name} có 3♠, đang mở lượt'
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
    final bool botFavored = _random.nextDouble() < _botFavoredDealRate;
    List<List<PlayingCardData>>? bestHands;
    int bestPenalty = 1 << 30;

    for (int attempt = 0; attempt < _dealSearchAttempts; attempt++) {
      final List<List<PlayingCardData>> hands = _shuffleDealHands();
      final int penalty = _dealPenalty(hands, botFavored: botFavored);
      if (penalty < bestPenalty) {
        bestPenalty = penalty;
        bestHands = hands;
        if (penalty == 0) {
          break;
        }
      }
    }

    final List<List<PlayingCardData>> hands = bestHands ?? _shuffleDealHands();
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

    int seat = 0;
    while (deck.isNotEmpty) {
      hands[seat].add(deck.removeAt(0));
      seat = (seat + 1) % _playerCount;
    }

    return hands;
  }

  int _dealPenalty(
    List<List<PlayingCardData>> hands, {
    required bool botFavored,
  }) {
    final List<int> strengths = hands.map(_handStrength).toList();
    final int bestIndex = _strongestPlayerIndex(strengths);
    final int humanStrength = strengths[_humanIndex];
    final int bestBotStrength = strengths
        .asMap()
        .entries
        .where((MapEntry<int, int> entry) => entry.key != _humanIndex)
        .map((MapEntry<int, int> entry) => entry.value)
        .reduce(math.max);

    int penalty = _humanHandShapePenalty(hands[_humanIndex]);

    if (botFavored) {
      if (bestIndex == _humanIndex) {
        penalty += 2200;
      }
      final int botLead = bestBotStrength - humanStrength;
      if (botLead < 18) {
        penalty += (18 - botLead) * 16;
      }
      if (botLead > 115) {
        penalty += (botLead - 115) * 10;
      }
    } else {
      if (bestIndex != _humanIndex) {
        penalty += 2200;
      }
      final int humanLead = humanStrength - bestBotStrength;
      if (humanLead < 12) {
        penalty += (12 - humanLead) * 18;
      }
      if (humanLead > 125) {
        penalty += (humanLead - 125) * 8;
      }
    }

    return penalty;
  }

  int _strongestPlayerIndex(List<int> strengths) {
    int bestIndex = 0;
    for (int index = 1; index < strengths.length; index++) {
      if (strengths[index] > strengths[bestIndex]) {
        bestIndex = index;
      }
    }
    return bestIndex;
  }

  int _humanHandShapePenalty(List<PlayingCardData> hand) {
    int penalty = 0;
    final int lowCardCount = hand
        .where((PlayingCardData card) => PlayRules.rankValue(card.rank) <= 2)
        .length;
    final int highCardCount = hand
        .where((PlayingCardData card) => PlayRules.rankValue(card.rank) >= 8)
        .length;
    final Map<int, int> groups = _rankCounts(hand);
    final int lowComboCards = groups.entries
        .where((MapEntry<int, int> entry) => entry.key <= 2 && entry.value >= 2)
        .fold<int>(0, (int total, MapEntry<int, int> entry) {
          return total + entry.value;
        });

    if (lowCardCount > 6) {
      penalty += (lowCardCount - 6) * 520;
    }
    if (highCardCount < 3) {
      penalty += (3 - highCardCount) * 620;
    }
    if (lowComboCards > 5) {
      penalty += (lowComboCards - 5) * 420;
    }
    return penalty;
  }

  int _handStrength(List<PlayingCardData> hand) {
    int score = 0;
    for (final PlayingCardData card in hand) {
      final int rank = PlayRules.rankValue(card.rank);
      score += rank * 12 + PlayRules.suitValue(card.suit);
      if (rank == PlayRules.twoRank) {
        score += 46;
      } else if (rank >= 8) {
        score += 18;
      }
    }

    final Map<int, int> groups = _rankCounts(hand);
    for (final MapEntry<int, int> entry in groups.entries) {
      final int rank = entry.key;
      final int count = entry.value;
      if (count >= 2) {
        score += 34 + rank * 4;
      }
      if (count >= 3) {
        score += 62 + rank * 5;
      }
      if (count == 4) {
        score += 170 + rank * 8;
      }
    }

    score += _longestStraightLength(groups) * 18;
    score += _consecutivePairLength(groups) * 28;
    return score;
  }

  Map<int, int> _rankCounts(List<PlayingCardData> hand) {
    final Map<int, int> groups = <int, int>{};
    for (final PlayingCardData card in hand) {
      final int rank = PlayRules.rankValue(card.rank);
      groups[rank] = (groups[rank] ?? 0) + 1;
    }
    return groups;
  }

  int _longestStraightLength(Map<int, int> groups) {
    int longest = 0;
    int current = 0;
    for (int rank = 0; rank < PlayRules.twoRank; rank++) {
      if (groups.containsKey(rank)) {
        current++;
        longest = math.max(longest, current);
      } else {
        current = 0;
      }
    }
    return longest >= 3 ? longest : 0;
  }

  int _consecutivePairLength(Map<int, int> groups) {
    int longest = 0;
    int current = 0;
    for (int rank = 0; rank < PlayRules.twoRank; rank++) {
      if ((groups[rank] ?? 0) >= 2) {
        current++;
        longest = math.max(longest, current);
      } else {
        current = 0;
      }
    }
    return longest >= 3 ? longest : 0;
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

  int _findOpeningPlayer() {
    for (int index = 0; index < _players.length; index++) {
      if (_containsThreeSpades(_players[index].hand)) {
        return index;
      }
    }
    return _humanIndex;
  }

  bool _containsThreeSpades(List<PlayingCardData> cards) {
    return cards.any(
      (PlayingCardData card) =>
          card.rank == '3' && card.suit == CardSuit.spades,
    );
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
        _status = '$baseStatus · Tự chia ván mới sau $_newRoundRemaining giây';
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
    if (_firstPlayPending && !_containsThreeSpades(evaluation.cards)) {
      return 'lượt đầu phải có 3♠';
    }
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
    if (_firstPlayPending && !_containsThreeSpades(evaluation.cards)) {
      setState(() => _status = 'Lượt đầu tiên bắt buộc đánh bộ có 3♠');
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
      mustContainThreeSpades: _firstPlayPending,
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
      final int delta = _stake == 0
          ? 0
          : (_playerCount - (2 * (placeIndex + 1)) + 1) * _stake;
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
    final String coinText = _stake == 0
        ? 'Không tính xu'
        : humanDelta >= 0
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
    _status = '$resultStatus · Tự chia ván mới sau $_newRoundDelaySeconds giây';
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
                          child: _TopOpponent(
                            player: _players[2],
                            active: _currentTurn == 2,
                            finished: _isFinished(2),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              SizedBox(
                                width: 68,
                                child: _SideOpponent(
                                  player: _players[1],
                                  active: _currentTurn == 1,
                                  finished: _isFinished(1),
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
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 68,
                                child: _SideOpponent(
                                  player: _players[3],
                                  active: _currentTurn == 3,
                                  finished: _isFinished(3),
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
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
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
                const SizedBox(width: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xAA071B1B),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: accent.withValues(alpha: 0.72)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 5,
                    ),
                    child: Text(
                      roundEnded
                          ? 'Tự sang ván mới ${remainingSeconds}s'
                          : '${remainingSeconds}s',
                      style: TextStyle(
                        color: accent,
                        fontFamily: 'Bungee',
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopOpponent extends StatelessWidget {
  const _TopOpponent({
    required this.player,
    required this.active,
    required this.finished,
  });

  final _TablePlayer player;
  final bool active;
  final bool finished;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _SeatBadge(
          name: finished
              ? '${player.name} · Xong bài'
              : active
              ? '${player.name} · Đang đánh'
              : player.name,
          compact: true,
          active: active,
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 260,
          height: 62,
          child: finished
              ? const _FinishedSeatPill()
              : _TopCardBackFan(count: player.hand.length),
        ),
        const SizedBox(width: 12),
        _CoinPill(coins: player.coins),
      ],
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

class _SideOpponent extends StatelessWidget {
  const _SideOpponent({
    required this.player,
    required this.active,
    required this.finished,
  });

  final _TablePlayer player;
  final bool active;
  final bool finished;

  @override
  Widget build(BuildContext context) {
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
          player.name,
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
          finished ? 'Xong bài' : '${player.hand.length} lá',
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
                        index < math.min(player.hand.length, 5);
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
    required this.roundEnded,
    required this.remainingSeconds,
    required this.newRoundRemainingSeconds,
    required this.turnLogs,
  });

  final List<PlayingCardData> cards;
  final int coveredCardCount;
  final PlayEvaluation? currentPlay;
  final String? lastActorName;
  final String currentPlayerName;
  final bool isHumanTurn;
  final bool roundEnded;
  final int remainingSeconds;
  final int newRoundRemainingSeconds;
  final List<String> turnLogs;

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
                      )
                    : cards.isEmpty
                    ? const _EmptyBoard()
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
    required this.currentPlayerName,
    required this.remainingSeconds,
  });

  final bool isHumanTurn;
  final String currentPlayerName;
  final int remainingSeconds;

  @override
  Widget build(BuildContext context) {
    final Color accent = isHumanTurn
        ? const Color(0xFF52F7FF)
        : const Color(0xFFFFD675);
    final String title = isHumanTurn
        ? 'ĐẾN LƯỢT BẠN'
        : 'Đang chờ $currentPlayerName';
    final String subtitle = isHumanTurn
        ? 'Chọn bài rồi bấm Đánh bài · còn ${remainingSeconds}s'
        : '$currentPlayerName đang suy nghĩ · còn ${remainingSeconds}s';

    return Semantics(
      liveRegion: true,
      label: isHumanTurn
          ? 'Đến lượt bạn, còn $remainingSeconds giây'
          : 'Đang chờ $currentPlayerName, còn $remainingSeconds giây',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isHumanTurn
                ? const <Color>[Color(0xEE07364D), Color(0xEE0C746B)]
                : const <Color>[Color(0xBB241608), Color(0xBB4C2B09)],
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: accent.withValues(alpha: 0.82), width: 1.5),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: accent.withValues(alpha: isHumanTurn ? 0.45 : 0.22),
              blurRadius: isHumanTurn ? 24 : 14,
              spreadRadius: isHumanTurn ? 1 : 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              isHumanTurn ? Icons.touch_app : Icons.hourglass_top,
              color: accent,
              size: 18,
            ),
            const SizedBox(width: 9),
            Text(
              title,
              style: TextStyle(
                color: isHumanTurn ? const Color(0xFFE9FFFF) : GameTheme.ivory,
                fontFamily: 'Bungee',
                fontSize: isHumanTurn ? 15 : 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
                shadows: const <Shadow>[
                  Shadow(color: Colors.black, blurRadius: 8),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              subtitle,
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundCountdownPanel extends StatelessWidget {
  const _RoundCountdownPanel({required this.remainingSeconds, super.key});

  final int remainingSeconds;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xEE331B06),
              Color(0xEE0E3F36),
              Color(0xEE071F29),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: GameTheme.gold, width: 2),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0xAAE8B84D),
              blurRadius: 34,
              spreadRadius: 2,
            ),
            BoxShadow(color: Color(0xAA000000), blurRadius: 26),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 22),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.emoji_events,
                color: GameTheme.gold,
                size: 52,
                shadows: <Shadow>[Shadow(color: Colors.black, blurRadius: 10)],
              ),
              const SizedBox(width: 18),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'TỰ CHIA VÁN MỚI',
                    style: TextStyle(
                      color: GameTheme.ivory,
                      fontFamily: 'Bungee',
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                      shadows: <Shadow>[
                        Shadow(color: Colors.black, blurRadius: 10),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '$remainingSeconds',
                        style: const TextStyle(
                          color: Color(0xFF52F7FF),
                          fontFamily: 'Bungee',
                          fontSize: 44,
                          fontWeight: FontWeight.w900,
                          shadows: <Shadow>[
                            Shadow(color: Color(0xAA52F7FF), blurRadius: 18),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'giây',
                        style: TextStyle(
                          color: GameTheme.gold,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Không cần bấm gì, hệ thống tự bắt đầu ván kế tiếp.',
                    style: TextStyle(
                      color: Color(0xFFC8F8FF),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
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
  const _EmptyBoard();

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
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          child: Text(
            'Chọn bài và đánh để mở lượt',
            style: TextStyle(
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
