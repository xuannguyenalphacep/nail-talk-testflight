import 'game_data.dart';

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
    required this.isBot,
    required this.connected,
    required this.ready,
    required this.coins,
    required this.handCount,
    required this.hand,
    required this.finished,
  });

  final String id;
  final int seatIndex;
  final String name;
  final bool isBot;
  final bool connected;
  final bool ready;
  final int coins;
  final int handCount;
  final List<TienLenRealtimeCard> hand;
  final bool finished;

  factory TienLenRealtimePlayer.fromJson(Map<String, dynamic> json) {
    final rawHand = json['hand'] as List<dynamic>? ?? const <dynamic>[];
    return TienLenRealtimePlayer(
      id: (json['id'] ?? '').toString(),
      seatIndex: (json['seatIndex'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '').toString(),
      isBot: json['isBot'] == true,
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

  bool get isFull => playerCount >= maxPlayers;

  factory TienLenRoomSummary.fromJson(Map<String, dynamic> json) {
    return TienLenRoomSummary(
      roomId: (json['roomId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      phase: (json['phase'] ?? '').toString(),
      baseBet: (json['baseBet'] as num?)?.toInt() ?? 0,
      maxPlayers: (json['maxPlayers'] as num?)?.toInt() ?? 3,
      playerCount: (json['playerCount'] as num?)?.toInt() ?? 0,
      humanCount: (json['humanCount'] as num?)?.toInt() ?? 0,
      botCount: (json['botCount'] as num?)?.toInt() ?? 0,
      roundNumber: (json['roundNumber'] as num?)?.toInt() ?? 0,
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
    required this.viewerId,
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
    required this.players,
    required this.turnStartedAt,
    required this.turnDeadlineAt,
    required this.turnDurationSeconds,
  });

  final String viewerId;
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
  final List<TienLenRealtimePlayer> players;
  final DateTime? turnStartedAt;
  final DateTime? turnDeadlineAt;
  final int turnDurationSeconds;

  bool get isHost => viewerId == hostId;
  bool get isPlaying => phase == 'playing';
  bool get isWaiting => phase == 'waiting';
  bool get isRoundEnded => phase == 'round-ended';
  bool get isViewerTurn => currentTurnPlayerId == viewerId && isPlaying;

  TienLenRealtimePlayer? get viewerPlayer {
    for (final player in players) {
      if (player.id == viewerId) return player;
    }
    return null;
  }

  TienLenRealtimePlayer? get currentTurnPlayer {
    for (final player in players) {
      if (player.id == currentTurnPlayerId) return player;
    }
    return null;
  }

  int remainingTurnSeconds(DateTime now) {
    final deadline = turnDeadlineAt;
    if (deadline == null || !isPlaying) return 0;
    final seconds = deadline.difference(now).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  factory TienLenRoomState.fromJson(Map<String, dynamic> json) {
    final rawCards = json['tableCards'] as List<dynamic>? ?? const <dynamic>[];
    final rawPlayers = json['players'] as List<dynamic>? ?? const <dynamic>[];
    final rawPassed =
        json['passedPlayerIds'] as List<dynamic>? ?? const <dynamic>[];
    final rawFinished =
        json['finishedOrder'] as List<dynamic>? ?? const <dynamic>[];
    final rawLogs = json['turnLogs'] as List<dynamic>? ?? const <dynamic>[];
    final rawLastPlay = json['lastPlay'];

    return TienLenRoomState(
      roomId: (json['roomId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      phase: (json['phase'] ?? '').toString(),
      baseBet: (json['baseBet'] as num?)?.toInt() ?? 0,
      maxPlayers: (json['maxPlayers'] as num?)?.toInt() ?? 3,
      playerCount: (json['playerCount'] as num?)?.toInt() ?? 0,
      humanCount: (json['humanCount'] as num?)?.toInt() ?? 0,
      botCount: (json['botCount'] as num?)?.toInt() ?? 0,
      roundNumber: (json['roundNumber'] as num?)?.toInt() ?? 0,
      viewerId: (json['viewerId'] ?? '').toString(),
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
      turnLogs: rawLogs.map((item) => item.toString()).toList(),
      players: rawPlayers
          .whereType<Map>()
          .map(
            (item) =>
                TienLenRealtimePlayer.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      turnStartedAt: DateTime.tryParse(
        (json['turnStartedAt'] ?? '').toString(),
      ),
      turnDeadlineAt: DateTime.tryParse(
        (json['turnDeadlineAt'] ?? '').toString(),
      ),
      turnDurationSeconds: (json['turnDurationSeconds'] as num?)?.toInt() ?? 15,
    );
  }
}
