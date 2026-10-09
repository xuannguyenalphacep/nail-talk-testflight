import '../data/game_data.dart';

enum PlayType {
  single,
  pair,
  triple,
  straight,
  threePairs,
  fourPairs,
  fivePairs,
  bomb,
}

class PlayEvaluation {
  const PlayEvaluation({
    required this.type,
    required this.rankValue,
    required this.suitValue,
    required this.cards,
  });

  final PlayType type;
  final int rankValue;
  final int suitValue;
  final List<PlayingCardData> cards;

  bool get isTwoCombo {
    return (type == PlayType.single || type == PlayType.pair) &&
        rankValue == PlayRules.twoRank;
  }

  int get chopPower {
    return switch (type) {
      PlayType.threePairs => 1,
      PlayType.bomb => 2,
      PlayType.fourPairs => 3,
      PlayType.fivePairs => 4,
      _ => 0,
    };
  }

  String get name {
    return switch (type) {
      PlayType.single => 'Bài lẻ',
      PlayType.pair => 'Đôi',
      PlayType.triple => 'Sám cô',
      PlayType.straight => 'Sảnh',
      PlayType.threePairs => 'Ba đôi thông',
      PlayType.fourPairs => 'Bốn đôi thông',
      PlayType.fivePairs => 'Năm đôi thông',
      PlayType.bomb => 'Tứ quý',
    };
  }

  String get summary {
    return switch (type) {
      PlayType.single => '1 lá ${cards.first.label}',
      PlayType.pair => 'đôi ${PlayRules.rankLabel(rankValue)}',
      PlayType.triple => 'sám ${PlayRules.rankLabel(rankValue)}',
      PlayType.straight => 'sảnh ${cards.length} lá',
      PlayType.threePairs => 'ba đôi thông',
      PlayType.fourPairs => 'bốn đôi thông',
      PlayType.fivePairs => 'năm đôi thông',
      PlayType.bomb => 'tứ quý ${PlayRules.rankLabel(rankValue)}',
    };
  }
}

class WhiteWinResult {
  const WhiteWinResult(this.reason);

  final String reason;
}

class PlayRules {
  static const List<String> rankOrder = <String>[
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    'J',
    'Q',
    'K',
    'A',
    '2',
  ];

  static const int twoRank = 12;

  static int rankValue(String rank) {
    final int index = rankOrder.indexOf(rank);
    return index == -1 ? 0 : index;
  }

  static String rankLabel(int value) {
    if (value < 0 || value >= rankOrder.length) {
      return '?';
    }
    return rankOrder[value];
  }

  static int suitValue(CardSuit suit) {
    return switch (suit) {
      CardSuit.spades => 0,
      CardSuit.clubs => 1,
      CardSuit.diamonds => 2,
      CardSuit.hearts => 3,
    };
  }

  static int compareCards(PlayingCardData a, PlayingCardData b) {
    final int rankCompare = rankValue(a.rank).compareTo(rankValue(b.rank));
    if (rankCompare != 0) {
      return rankCompare;
    }
    return suitValue(a.suit).compareTo(suitValue(b.suit));
  }

  static PlayEvaluation? evaluate(List<PlayingCardData> selectedCards) {
    if (selectedCards.isEmpty) {
      return null;
    }

    final List<PlayingCardData> cards = List<PlayingCardData>.of(selectedCards)
      ..sort(compareCards);
    final Map<int, List<PlayingCardData>> groups = _groupByRank(cards);

    if (cards.length == 1) {
      return _build(PlayType.single, groups.keys.first, cards);
    }

    if (groups.length == 1) {
      final int count = cards.length;
      final int rank = groups.keys.first;
      return switch (count) {
        2 => _build(PlayType.pair, rank, cards),
        3 => _build(PlayType.triple, rank, cards),
        4 => _build(PlayType.bomb, rank, cards),
        _ => null,
      };
    }

    final List<int> ranks = groups.keys.toList()..sort();
    if (_isStraight(groups, ranks)) {
      return _build(PlayType.straight, ranks.last, cards);
    }

    if (_isConsecutivePairs(groups, ranks)) {
      final int pairCount = ranks.length;
      return switch (pairCount) {
        3 => _build(PlayType.threePairs, ranks.last, cards),
        4 => _build(PlayType.fourPairs, ranks.last, cards),
        _ when pairCount >= 5 => _build(PlayType.fivePairs, ranks.last, cards),
        _ => null,
      };
    }

    return null;
  }

  static bool isValidPlay({
    required PlayEvaluation candidate,
    required PlayEvaluation? previous,
  }) {
    if (previous == null) {
      return true;
    }

    if (_canChop(candidate: candidate, previous: previous)) {
      return true;
    }

    if (candidate.type != previous.type) {
      return false;
    }

    if (candidate.type == PlayType.straight &&
        candidate.cards.length != previous.cards.length) {
      return false;
    }

    return _compareEvaluation(candidate, previous) > 0;
  }

  static String invalidReason({
    required PlayEvaluation? candidate,
    required PlayEvaluation? previous,
  }) {
    if (candidate == null) {
      return 'Bộ bài chưa đúng luật Tiến Lên Miền Nam';
    }
    if (previous == null) {
      return 'Bộ này hợp lệ';
    }
    if (_canChop(candidate: candidate, previous: previous)) {
      return 'Bộ này có thể chặt lượt trước';
    }
    if (candidate.type != previous.type) {
      return 'Phải đánh cùng loại bài hoặc dùng bộ chặt hợp lệ';
    }
    if (candidate.type == PlayType.straight &&
        candidate.cards.length != previous.cards.length) {
      return 'Sảnh phải cùng số lá với sảnh đang chặn';
    }
    return 'Bộ bài phải lớn hơn lượt trước';
  }

  static String describe(PlayEvaluation? current) {
    if (current == null) {
      return 'Chưa có lượt đánh';
    }
    final PlayingCardData highest = current.cards.reduce(
      (PlayingCardData a, PlayingCardData b) => compareCards(a, b) >= 0 ? a : b,
    );
    return '${current.name} · cao nhất ${highest.label}';
  }

  static WhiteWinResult? whiteWin(List<PlayingCardData> cards) {
    final Map<int, List<PlayingCardData>> groups = _groupByRank(cards);
    final int pairCount = groups.values
        .where((List<PlayingCardData> group) => group.length >= 2)
        .length;
    final int tripleCount = groups.values
        .where((List<PlayingCardData> group) => group.length >= 3)
        .length;

    if (groups[twoRank]?.length == 4) {
      return const WhiteWinResult('Tứ quý 2 tới trắng');
    }
    if (_hasDragonStraight(cards)) {
      return const WhiteWinResult('Sảnh rồng 3 đến A tới trắng');
    }
    if (_longestConsecutivePairs(cards) >= 5) {
      return const WhiteWinResult('Năm đôi thông tới trắng');
    }
    if (pairCount >= 6) {
      return const WhiteWinResult('Sáu đôi tới trắng');
    }
    if (tripleCount >= 4) {
      return const WhiteWinResult('Bốn sám cô tới trắng');
    }
    return null;
  }

  static bool canFinishWith(PlayEvaluation play) {
    return play.cards.isNotEmpty;
  }

  static PlayEvaluation _build(
    PlayType type,
    int rank,
    List<PlayingCardData> cards,
  ) {
    return PlayEvaluation(
      type: type,
      rankValue: rank,
      suitValue: cards
          .where((PlayingCardData card) => rankValue(card.rank) == rank)
          .map((PlayingCardData card) => suitValue(card.suit))
          .fold<int>(0, (int best, int value) => value > best ? value : best),
      cards: List<PlayingCardData>.unmodifiable(cards),
    );
  }

  static Map<int, List<PlayingCardData>> _groupByRank(
    List<PlayingCardData> cards,
  ) {
    final Map<int, List<PlayingCardData>> groups =
        <int, List<PlayingCardData>>{};
    for (final PlayingCardData card in cards) {
      groups
          .putIfAbsent(rankValue(card.rank), () => <PlayingCardData>[])
          .add(card);
    }
    return groups;
  }

  static bool _isStraight(
    Map<int, List<PlayingCardData>> groups,
    List<int> ranks,
  ) {
    final int cardCount = groups.values.fold<int>(
      0,
      (int sum, List<PlayingCardData> group) => sum + group.length,
    );
    return ranks.length >= 3 &&
        ranks.length == cardCount &&
        !ranks.contains(twoRank) &&
        _isConsecutive(ranks);
  }

  static bool _isConsecutivePairs(
    Map<int, List<PlayingCardData>> groups,
    List<int> ranks,
  ) {
    return ranks.length >= 3 &&
        !ranks.contains(twoRank) &&
        ranks.every((int rank) => groups[rank]?.length == 2) &&
        _isConsecutive(ranks);
  }

  static bool _isConsecutive(List<int> ranks) {
    for (int i = 1; i < ranks.length; i++) {
      if (ranks[i] != ranks[i - 1] + 1) {
        return false;
      }
    }
    return true;
  }

  static bool _canChop({
    required PlayEvaluation candidate,
    required PlayEvaluation previous,
  }) {
    if (candidate.chopPower == 0) {
      return false;
    }
    if (previous.isTwoCombo) {
      if (previous.type == PlayType.single) {
        return candidate.chopPower >= 1;
      }
      return candidate.chopPower >= 2;
    }
    if (previous.chopPower == 0) {
      return false;
    }
    if (candidate.chopPower != previous.chopPower) {
      return candidate.chopPower > previous.chopPower;
    }
    return _compareEvaluation(candidate, previous) > 0;
  }

  static int _compareEvaluation(PlayEvaluation a, PlayEvaluation b) {
    final int rankCompare = a.rankValue.compareTo(b.rankValue);
    if (rankCompare != 0) {
      return rankCompare;
    }
    return a.suitValue.compareTo(b.suitValue);
  }

  static bool _hasDragonStraight(List<PlayingCardData> cards) {
    final Set<int> ranks = cards
        .map((PlayingCardData card) => rankValue(card.rank))
        .where((int value) => value < twoRank)
        .toSet();
    for (int value = 0; value < twoRank; value++) {
      if (!ranks.contains(value)) {
        return false;
      }
    }
    return true;
  }

  static int _longestConsecutivePairs(List<PlayingCardData> cards) {
    final List<int> pairRanks =
        _groupByRank(cards).entries
            .where(
              (MapEntry<int, List<PlayingCardData>> entry) =>
                  entry.key < twoRank && entry.value.length >= 2,
            )
            .map((MapEntry<int, List<PlayingCardData>> entry) => entry.key)
            .toList()
          ..sort();

    int best = 0;
    int current = 0;
    int? previous;
    for (final int rank in pairRanks) {
      current = previous == null || rank == previous + 1 ? current + 1 : 1;
      if (current > best) {
        best = current;
      }
      previous = rank;
    }
    return best;
  }
}

extension PlayingCardLabel on PlayingCardData {
  String get label => '$rank${suit.symbol}';
}
