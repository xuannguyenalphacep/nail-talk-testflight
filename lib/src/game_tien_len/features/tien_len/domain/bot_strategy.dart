import '../data/game_data.dart';
import 'play_rules.dart';

class TienLenBot {
  const TienLenBot._();

  static PlayEvaluation? choosePlay({
    required List<PlayingCardData> hand,
    required PlayEvaluation? previous,
    bool firstPlayPending = false,
    bool mustContainThreeSpades = false,
    bool lastActorIsHuman = false,
    int humanCardCount = 13,
  }) {
    final List<PlayEvaluation> candidates = legalCandidates(
      hand: hand,
      previous: previous,
      firstPlayPending: firstPlayPending,
      mustContainThreeSpades: mustContainThreeSpades,
    );
    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((PlayEvaluation a, PlayEvaluation b) {
      final int scoreCompare =
          _score(
            evaluation: a,
            previous: previous,
            hand: hand,
            lastActorIsHuman: lastActorIsHuman,
            humanCardCount: humanCardCount,
          ).compareTo(
            _score(
              evaluation: b,
              previous: previous,
              hand: hand,
              lastActorIsHuman: lastActorIsHuman,
              humanCardCount: humanCardCount,
            ),
          );
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      final int rankCompare = a.rankValue.compareTo(b.rankValue);
      if (rankCompare != 0) {
        return rankCompare;
      }
      return a.suitValue.compareTo(b.suitValue);
    });

    return candidates.first;
  }

  static List<PlayEvaluation> legalCandidates({
    required List<PlayingCardData> hand,
    required PlayEvaluation? previous,
    bool firstPlayPending = false,
    bool mustContainThreeSpades = false,
  }) {
    final List<PlayEvaluation> candidates = <PlayEvaluation>[];
    final int maxMask = 1 << hand.length;

    for (int mask = 1; mask < maxMask; mask++) {
      final List<PlayingCardData> cards = <PlayingCardData>[];
      for (int index = 0; index < hand.length; index++) {
        if ((mask & (1 << index)) != 0) {
          cards.add(hand[index]);
        }
      }

      final PlayEvaluation? evaluation = PlayRules.evaluate(cards);
      if (evaluation == null) {
        continue;
      }
      if (firstPlayPending &&
          mustContainThreeSpades &&
          !_containsThreeSpades(evaluation.cards)) {
        continue;
      }
      if (PlayRules.isValidPlay(candidate: evaluation, previous: previous)) {
        candidates.add(evaluation);
      }
    }

    return candidates;
  }

  static int _score({
    required PlayEvaluation evaluation,
    required PlayEvaluation? previous,
    required List<PlayingCardData> hand,
    required bool lastActorIsHuman,
    required int humanCardCount,
  }) {
    final bool canFinishNow = evaluation.cards.length == hand.length;
    if (canFinishNow) {
      return -30000;
    }

    final bool containsTwo = evaluation.cards.any(
      (PlayingCardData card) =>
          PlayRules.rankValue(card.rank) == PlayRules.twoRank,
    );
    final int twoPenalty = containsTwo ? 1600 : 0;
    final int bombPenalty = evaluation.type == PlayType.bomb ? 2200 : 0;
    final int reserveChopPenalty = evaluation.chopPower > 0 ? 900 : 0;

    if (previous == null) {
      final int comboBonus = switch (evaluation.type) {
        PlayType.straight => -500 * evaluation.cards.length,
        PlayType.triple => -760,
        PlayType.pair => -430,
        PlayType.threePairs => -520,
        PlayType.fourPairs => 900,
        PlayType.fivePairs => 1200,
        PlayType.bomb => 1400,
        PlayType.single => 0,
      };
      return comboBonus +
          twoPenalty +
          bombPenalty +
          reserveChopPenalty +
          evaluation.rankValue * 30 +
          evaluation.suitValue;
    }

    final bool usesChop = evaluation.type != previous.type;
    final bool humanIsDangerous = lastActorIsHuman && humanCardCount <= 3;
    final int pressureBonus = humanIsDangerous ? -2300 : 0;
    final int chopPenalty = usesChop
        ? humanIsDangerous
              ? 260
              : 5600
        : 0;
    final int shedBonus = evaluation.cards.length >= 3 ? -120 : 0;

    return pressureBonus +
        chopPenalty +
        shedBonus +
        twoPenalty +
        bombPenalty +
        reserveChopPenalty +
        evaluation.rankValue * 26 +
        evaluation.suitValue;
  }

  static bool _containsThreeSpades(List<PlayingCardData> cards) {
    return cards.any(
      (PlayingCardData card) =>
          card.rank == '3' && card.suit == CardSuit.spades,
    );
  }
}
