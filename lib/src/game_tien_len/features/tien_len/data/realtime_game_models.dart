import 'game_data.dart';

/// Tag shown next to every automated (system) player, so people always know
/// when a seat is not a real person.
const String systemOpponentLabel = 'BOT';

String labelSystemOpponentName(String name) {
  final trimmed = name.trim();
  const suffix = '($systemOpponentLabel)';
  if (trimmed.endsWith(suffix)) return trimmed;
  return trimmed.isEmpty ? systemOpponentLabel : '$trimmed $suffix';
}

/// Rewrites server log lines so automated players carry the BOT tag there too.
List<String> labelSystemOpponentsInLogs(
  List<String> logs,
  Iterable<TienLenRealtimePlayer> players,
) {
  final renames = <String, String>{
    for (final player in players)
      if (player.isSystemOpponent && player.rawName.trim().isNotEmpty)
        player.rawName.trim(): player.name,
  };
  if (renames.isEmpty) return logs;
  // Human names are matched too (longest first) so a person called
  // "Minh Anh Tú" is never tagged because a BOT "Minh Anh" shares the table.
  final names = <String>{
    ...renames.keys,
    for (final player in players)
      if (!player.isSystemOpponent && player.rawName.trim().isNotEmpty)
        player.rawName.trim(),
  }.toList()..sort((a, b) => b.length.compareTo(a.length));
  final pattern = RegExp(
    r'(?<![\p{L}\p{N}])(?:' +
        names.map(RegExp.escape).join('|') +
        r')(?![\p{L}\p{N}])',
    unicode: true,
  );
  return logs
      .map(
        (line) => line.replaceAllMapped(pattern, (match) {
          final matched = match[0]!;
          final label = renames[matched];
          final alreadyLabelled = line.startsWith(
            ' ($systemOpponentLabel)',
            match.end,
          );
          return label == null || alreadyLabelled ? matched : label;
        }),
      )
      .toList(growable: false);
}

class TienLenRealtimeCard {
  const TienLenRealtimeCard({
    required this.rank,
    required this.suit,
    required this.code,
    required this.label,
  });

  final String rank;
  final CardSuit suit;
  final String code;
  final String label;

  PlayingCardData get playingCard => PlayingCardData(rank, suit);

  factory TienLenRealtimeCard.fromJson(Map<String, dynamic> json) {
    final suitName = (json['suit'] ?? '').toString();
    return TienLenRealtimeCard(
      rank: (json['rank'] ?? '').toString(),
      suit: _suitFromName(suitName),
      code: (json['code'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
    );
  }

  static CardSuit _suitFromName(String value) {
    return switch (value) {
      'clubs' => CardSuit.clubs,
      'diamonds' => CardSuit.diamonds,
      'hearts' => CardSuit.hearts,
      'spades' => CardSuit.spades,
      _ => CardSuit.spades,
    };
  }
}

class TienLenRealtimePlay {
  const TienLenRealtimePlay({
    required this.type,
    required this.rankValue,
    required this.suitValue,
    required this.cards,
    required this.summary,
  });

  final String type;
  final int rankValue;
  final int suitValue;
  final List<TienLenRealtimeCard> cards;
  final String summary;

  factory TienLenRealtimePlay.fromJson(Map<String, dynamic> json) {
    final rawCards = json['cards'] as List<dynamic>? ?? const <dynamic>[];
    return TienLenRealtimePlay(
      type: (json['type'] ?? '').toString(),
      rankValue: (json['rankValue'] as num?)?.toInt() ?? 0,
      suitValue: (json['suitValue'] as num?)?.toInt() ?? 0,
      cards: rawCards
          .whereType<Map>()
          .map(
            (item) =>
                TienLenRealtimeCard.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      summary: (json['summary'] ?? '').toString(),
    );
  }
}

class TienLenRealtimePlayer {
  const TienLenRealtimePlayer({
    required this.id,
    required this.seatIndex,
    required this.name,
    required this.isSystemOpponent,
    this.rawName = '',
    required this.connected,
    required this.ready,
    required this.coins,
    required this.handCount,
    required this.hand,
    required this.finished,
    this.waitingForNextRound = false,
    this.eligibleForNextRound = true,
    this.waitingReason,
  });

  final String id;
  final int seatIndex;

  /// Display name; automated players always end with "(BOT)".
  final String name;

  /// Name exactly as sent by the server, used to tag BOTs in log lines.
  final String rawName;
  final bool isSystemOpponent;
  final bool connected;
  final bool ready;
  final int coins;
  final int handCount;
  final List<TienLenRealtimeCard> hand;
  final bool finished;
  final bool waitingForNextRound;
  final bool eligibleForNextRound;
  final String? waitingReason;

  factory TienLenRealtimePlayer.fromJson(Map<String, dynamic> json) {
    final rawHand = json['hand'] as List<dynamic>? ?? const <dynamic>[];
    final rawName = (json['name'] ?? '').toString();
    final isSystemOpponent =
        json['isSystemOpponent'] == true || json['isBot'] == true;
    return TienLenRealtimePlayer(
      id: (json['id'] ?? '').toString(),
      seatIndex: (json['seatIndex'] as num?)?.toInt() ?? 0,
      name: isSystemOpponent ? labelSystemOpponentName(rawName) : rawName,
      rawName: rawName,
      isSystemOpponent: isSystemOpponent,
      connected: json['connected'] != false,
      ready: json['ready'] == true,
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      handCount: (json['handCount'] as num?)?.toInt() ?? 0,
      hand: rawHand
          .whereType<Map>()
          .map(
            (item) =>
                TienLenRealtimeCard.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      finished: json['finished'] == true,
      waitingForNextRound: json['waitingForNextRound'] == true,
      eligibleForNextRound: json['eligibleForNextRound'] != false,
      waitingReason: (json['waitingReason'] ?? '').toString().trim().isEmpty
          ? null
          : (json['waitingReason'] ?? '').toString().trim(),
    );
  }
}

class TienLenMoneyEvent {
  const TienLenMoneyEvent({
    required this.fromId,
    required this.toId,
    required this.gross,
    required this.net,
  });

  final String fromId;
  final String toId;
  final int gross;
  final int net;

  factory TienLenMoneyEvent.fromJson(Map<String, dynamic> json) {
    return TienLenMoneyEvent(
      fromId: (json['fromId'] ?? '').toString(),
      toId: (json['toId'] ?? '').toString(),
      gross: (json['gross'] as num?)?.toInt() ?? 0,
      net: (json['net'] as num?)?.toInt() ?? 0,
    );
  }
}

class TienLenRoomSummary {
  const TienLenRoomSummary({
    required this.roomId,
    required this.title,
    required this.phase,
    required this.baseBet,
    required this.maxPlayers,
    required this.playerCount,
    required this.humanCount,
    required this.botCount,
    required this.roundNumber,
    required this.activePlayerCount,
    required this.waitingPlayerCount,
  });

  final String roomId;
  final String title;
  final String phase;
  final int baseBet;
  final int maxPlayers;
  final int playerCount;
  final int humanCount;
  final int botCount;
  final int roundNumber;
  final int activePlayerCount;
  final int waitingPlayerCount;

  bool get isFull => playerCount >= maxPlayers;

  factory TienLenRoomSummary.fromJson(Map<String, dynamic> json) {
    return TienLenRoomSummary(
      roomId: (json['roomId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      phase: (json['phase'] ?? '').toString(),
      baseBet: (json['baseBet'] as num?)?.toInt() ?? 0,
      maxPlayers: (json['maxPlayers'] as num?)?.toInt() ?? 4,
      playerCount: (json['playerCount'] as num?)?.toInt() ?? 0,
      humanCount: (json['humanCount'] as num?)?.toInt() ?? 0,
      botCount: (json['botCount'] as num?)?.toInt() ?? 0,
      roundNumber: (json['roundNumber'] as num?)?.toInt() ?? 0,
      activePlayerCount:
          (json['activePlayerCount'] as num?)?.toInt() ??
          (json['playerCount'] as num?)?.toInt() ??
          0,
      waitingPlayerCount: (json['waitingPlayerCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class TienLenRoomState extends TienLenRoomSummary {
  const TienLenRoomState({
    required super.roomId,
    required super.title,
    required super.phase,
    required super.baseBet,
    required super.maxPlayers,
    required super.playerCount,
    required super.humanCount,
    required super.botCount,
    required super.roundNumber,
    required super.activePlayerCount,
    required super.waitingPlayerCount,
    required this.roundId,
    required this.settlementStatus,
    required this.settlementError,
    required this.viewerId,
    required this.viewerRole,
    required this.viewerWaitingForNextRound,
    required this.hostId,
    required this.currentTurnPlayerId,
    required this.lastActorId,
    required this.firstPlayPending,
    required this.coveredTableCardCount,
    required this.tableCards,
    required this.lastPlay,
    required this.passedPlayerIds,
    required this.finishedOrder,
    required this.turnLogs,
    this.chatMessages = const <Map<String, dynamic>>[],
    required this.players,
    required this.spectators,
    this.moneyEvents = const <TienLenMoneyEvent>[],
    required this.turnStartedAt,
    required this.turnDeadlineAt,
    required this.turnDurationSeconds,
    required this.autoBotJoinDueAt,
    required this.nextRoundAllowedAt,
  });

  final String roundId;
  final String settlementStatus;
  final String? settlementError;
  final String viewerId;
  final String viewerRole;
  final bool viewerWaitingForNextRound;
  final String hostId;
  final String currentTurnPlayerId;
  final String lastActorId;
  final bool firstPlayPending;
  final int coveredTableCardCount;
  final List<TienLenRealtimeCard> tableCards;
  final TienLenRealtimePlay? lastPlay;
  final Set<String> passedPlayerIds;
  final List<String> finishedOrder;
  final List<String> turnLogs;
  final List<Map<String, dynamic>> chatMessages;
  final List<TienLenRealtimePlayer> players;
  final List<TienLenRealtimePlayer> spectators;
  final List<TienLenMoneyEvent> moneyEvents;
  final DateTime? turnStartedAt;
  final DateTime? turnDeadlineAt;
  final int turnDurationSeconds;
  final DateTime? autoBotJoinDueAt;
  final DateTime? nextRoundAllowedAt;

  bool get isHost => viewerId == hostId;
  bool get isSpectator =>
      viewerRole == 'spectator' || viewerWaitingForNextRound;
  bool get isPlaying => phase == 'playing';
  bool get isWaiting => phase == 'waiting';
  bool get isRoundEnded => phase == 'round-ended';
  bool get isViewerTurn =>
      !isSpectator && currentTurnPlayerId == viewerId && isPlaying;
  bool get isSettlementPending => settlementStatus == 'pending';
  bool get isSettlementSettled => settlementStatus == 'settled';
  bool get isSettlementFailed => settlementStatus == 'failed';
  bool get mustDrainWhenFeatureDisabled =>
      isPlaying || (isRoundEnded && baseBet > 0 && !isSettlementSettled);
  bool get canStartNextRound =>
      isRoundEnded && !isSettlementPending && !isSettlementFailed;

  bool canStartNextRoundAt(DateTime now) =>
      canStartNextRound && remainingNextRoundSeconds(now) == 0;

  TienLenRealtimePlayer? get viewerPlayer {
    for (final player in players) {
      if (player.id == viewerId) return player;
    }
    return null;
  }

  TienLenRealtimePlayer? get viewerSpectator {
    for (final spectator in spectators) {
      if (spectator.id == viewerId) return spectator;
    }
    return null;
  }

  TienLenRealtimePlayer? get viewerParticipant =>
      viewerPlayer ?? viewerSpectator;

  TienLenRealtimePlayer? get currentTurnPlayer {
    for (final player in players) {
      if (player.id == currentTurnPlayerId) return player;
    }
    return null;
  }

  int get viewerRoundCoinDelta {
    return moneyEvents.fold<int>(0, (int total, TienLenMoneyEvent event) {
      final int received = event.toId == viewerId ? event.net : 0;
      final int paid = event.fromId == viewerId ? event.gross : 0;
      return total + received - paid;
    });
  }

  int remainingTurnSeconds(DateTime now) {
    final deadline = turnDeadlineAt;
    if (deadline == null || !isPlaying) return 0;
    final remaining = deadline.difference(now);
    if (remaining <= Duration.zero) return 0;

    // Duration.inSeconds truncates, which used to display 0 and disable the
    // player's controls for almost a full second before the server deadline.
    // Keep any positive fraction visible/actionable until it actually expires.
    final milliseconds = remaining.inMilliseconds;
    if (milliseconds == 0) return 1;
    return (milliseconds + Duration.millisecondsPerSecond - 1) ~/
        Duration.millisecondsPerSecond;
  }

  int remainingAutoMatchSeconds(DateTime now) {
    if (!isWaiting || playerCount > 2) return 0;
    return _remainingSeconds(autoBotJoinDueAt, now);
  }

  int remainingNextRoundSeconds(DateTime now) {
    if (!isRoundEnded) return 0;
    return _remainingSeconds(nextRoundAllowedAt, now);
  }

  static int _remainingSeconds(DateTime? deadline, DateTime now) {
    if (deadline == null) return 0;
    final remaining = deadline.difference(now);
    if (remaining <= Duration.zero) return 0;
    final milliseconds = remaining.inMilliseconds;
    return (milliseconds + Duration.millisecondsPerSecond - 1) ~/
        Duration.millisecondsPerSecond;
  }

  factory TienLenRoomState.fromJson(Map<String, dynamic> json) {
    final rawCards = json['tableCards'] as List<dynamic>? ?? const <dynamic>[];
    final rawPlayers = json['players'] as List<dynamic>? ?? const <dynamic>[];
    final rawSpectators =
        json['spectators'] as List<dynamic>? ?? const <dynamic>[];
    final rawPassed =
        json['passedPlayerIds'] as List<dynamic>? ?? const <dynamic>[];
    final rawFinished =
        json['finishedOrder'] as List<dynamic>? ?? const <dynamic>[];
    final rawLogs = json['turnLogs'] as List<dynamic>? ?? const <dynamic>[];
    final rawChatMessages =
        json['chatMessages'] as List<dynamic>? ?? const <dynamic>[];
    final rawMoneyEvents =
        json['moneyEvents'] as List<dynamic>? ?? const <dynamic>[];
    final rawLastPlay = json['lastPlay'];
    final settlementError = (json['settlementError'] ?? '').toString().trim();
    final players = rawPlayers
        .whereType<Map>()
        .map(
          (item) =>
              TienLenRealtimePlayer.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
    final spectators = rawSpectators
        .whereType<Map>()
        .map(
          (item) =>
              TienLenRealtimePlayer.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();

    return TienLenRoomState(
      roomId: (json['roomId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      phase: (json['phase'] ?? '').toString(),
      baseBet: (json['baseBet'] as num?)?.toInt() ?? 0,
      maxPlayers: (json['maxPlayers'] as num?)?.toInt() ?? 4,
      playerCount: (json['playerCount'] as num?)?.toInt() ?? 0,
      humanCount: (json['humanCount'] as num?)?.toInt() ?? 0,
      botCount: (json['botCount'] as num?)?.toInt() ?? 0,
      roundNumber: (json['roundNumber'] as num?)?.toInt() ?? 0,
      activePlayerCount:
          (json['activePlayerCount'] as num?)?.toInt() ?? rawPlayers.length,
      waitingPlayerCount:
          (json['waitingPlayerCount'] as num?)?.toInt() ?? rawSpectators.length,
      roundId: (json['roundId'] ?? '').toString(),
      settlementStatus: (json['settlementStatus'] ?? 'idle')
          .toString()
          .toLowerCase(),
      settlementError: settlementError.isEmpty ? null : settlementError,
      viewerId: (json['viewerId'] ?? '').toString(),
      viewerRole: (json['viewerRole'] ?? 'player').toString(),
      viewerWaitingForNextRound: json['viewerWaitingForNextRound'] == true,
      hostId: (json['hostId'] ?? '').toString(),
      currentTurnPlayerId: (json['currentTurnPlayerId'] ?? '').toString(),
      lastActorId: (json['lastActorId'] ?? '').toString(),
      firstPlayPending: json['firstPlayPending'] == true,
      coveredTableCardCount:
          (json['coveredTableCardCount'] as num?)?.toInt() ?? 0,
      tableCards: rawCards
          .whereType<Map>()
          .map(
            (item) =>
                TienLenRealtimeCard.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      lastPlay: rawLastPlay is Map
          ? TienLenRealtimePlay.fromJson(Map<String, dynamic>.from(rawLastPlay))
          : null,
      passedPlayerIds: rawPassed.map((item) => item.toString()).toSet(),
      finishedOrder: rawFinished.map((item) => item.toString()).toList(),
      turnLogs: labelSystemOpponentsInLogs(
        rawLogs.map((item) => item.toString()).toList(),
        [...players, ...spectators],
      ),
      chatMessages: rawChatMessages
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
      players: players,
      spectators: spectators,
      moneyEvents: rawMoneyEvents
          .whereType<Map>()
          .map(
            (item) =>
                TienLenMoneyEvent.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      turnStartedAt: DateTime.tryParse(
        (json['turnStartedAt'] ?? '').toString(),
      ),
      turnDeadlineAt: DateTime.tryParse(
        (json['turnDeadlineAt'] ?? '').toString(),
      ),
      turnDurationSeconds: (json['turnDurationSeconds'] as num?)?.toInt() ?? 15,
      autoBotJoinDueAt: DateTime.tryParse(
        (json['autoBotJoinDueAt'] ?? '').toString(),
      ),
      nextRoundAllowedAt: DateTime.tryParse(
        (json['nextRoundAllowedAt'] ?? '').toString(),
      ),
    );
  }
}
