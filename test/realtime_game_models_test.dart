import 'package:flutter_test/flutter_test.dart';
import 'package:social_hub_flutter/src/game_tien_len/features/tien_len/data/game_data.dart';
import 'package:social_hub_flutter/src/game_tien_len/features/tien_len/data/realtime_game_models.dart';

void main() {
  test('parses a four-seat round result and viewer state', () {
    final state = TienLenRoomState.fromJson(<String, dynamic>{
      'roomId': 'NT10001',
      'title': 'Bàn nhanh',
      'phase': 'round-ended',
      'baseBet': 100,
      'maxPlayers': 4,
      'playerCount': 4,
      'humanCount': 1,
      'botCount': 3,
      'roundNumber': 2,
      'roundId': 'round-uuid-2',
      'settlementStatus': 'failed',
      'settlementError': 'wallet-settlement-failed',
      'viewerId': '7',
      'hostId': '7',
      'finishedOrder': <String>['7', 'bot-1', 'bot-2', 'bot-3'],
      'moneyEvents': <Map<String, dynamic>>[
        <String, dynamic>{
          'fromId': 'bot-1',
          'toId': '7',
          'gross': 100,
          'net': 95,
        },
        <String, dynamic>{
          'fromId': '7',
          'toId': 'bot-2',
          'gross': 25,
          'net': 24,
        },
      ],
      'players': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': '7',
          'name': 'Người chơi',
          'coins': 12700,
          'hand': <dynamic>[],
          'handCount': 0,
          'finished': true,
        },
        for (var index = 1; index <= 3; index++)
          <String, dynamic>{
            'id': 'bot-$index',
            'name': 'Đối thủ $index',
            'isSystemOpponent': true,
            'coins': 12400,
            'handCount': index,
          },
      ],
    });

    expect(state.maxPlayers, 4);
    expect(state.players, hasLength(4));
    expect(
      state.players.skip(1).every((player) => player.isSystemOpponent),
      isTrue,
    );
    expect(state.isRoundEnded, isTrue);
    expect(state.isHost, isTrue);
    expect(state.finishedOrder.first, '7');
    expect(state.viewerPlayer?.coins, 12700);
    expect(state.viewerRoundCoinDelta, 70);
    expect(state.roundId, 'round-uuid-2');
    expect(state.isSettlementFailed, isTrue);
    expect(state.settlementError, 'wallet-settlement-failed');
    expect(state.canStartNextRound, isFalse);
    expect(state.mustDrainWhenFeatureDisabled, isTrue);
    expect(state.remainingTurnSeconds(DateTime.now()), 0);
  });

  test(
    'sums every payment in the current round without carrying prior rounds',
    () {
      TienLenRoomState settledRound({
        required int roundNumber,
        required String roundId,
        required List<Map<String, dynamic>> moneyEvents,
      }) {
        return TienLenRoomState.fromJson(<String, dynamic>{
          'roomId': 'NT10001',
          'phase': 'round-ended',
          'roundNumber': roundNumber,
          'roundId': roundId,
          'settlementStatus': 'settled',
          'viewerId': '7',
          'hostId': '8',
          'moneyEvents': moneyEvents,
        });
      }

      final secondRound = settledRound(
        roundNumber: 2,
        roundId: 'round-2',
        moneyEvents: <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'cong',
            'fromId': '7',
            'toId': '8',
            'gross': 200,
            'fee': 20,
            'net': 180,
          },
          <String, dynamic>{
            'type': 'rotten-two',
            'fromId': '7',
            'toId': '8',
            'gross': 300,
            'fee': 30,
            'net': 270,
          },
        ],
      );
      final thirdRound = settledRound(
        roundNumber: 3,
        roundId: 'round-3',
        moneyEvents: <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'rank',
            'fromId': '7',
            'toId': '8',
            'gross': 100,
            'fee': 10,
            'net': 90,
          },
        ],
      );

      // Cóng x2 (-200) and thối hai heo (-300) are separate payments in the
      // same round, so the result card must show their complete wallet delta.
      expect(secondRound.viewerRoundCoinDelta, -500);
      // Each server snapshot owns only its round's events. A subsequent round
      // must never inherit the previous result in the Flutter model/UI.
      expect(thirdRound.viewerRoundCoinDelta, -100);
    },
  );

  test('enforces the server 15-second pause after settlement succeeds', () {
    final now = DateTime.utc(2026, 10, 11, 12);
    final state = TienLenRoomState.fromJson(<String, dynamic>{
      'roomId': 'NT10001',
      'phase': 'round-ended',
      'roundId': 'round-uuid-3',
      'settlementStatus': 'settled',
      'viewerId': '7',
      'hostId': '7',
      'nextRoundAllowedAt': now
          .add(const Duration(seconds: 15))
          .toIso8601String(),
    });

    expect(state.isSettlementSettled, isTrue);
    expect(state.isSettlementPending, isFalse);
    expect(state.canStartNextRound, isTrue);
    expect(state.canStartNextRoundAt(now), isFalse);
    expect(state.remainingNextRoundSeconds(now), 15);
    expect(
      state.canStartNextRoundAt(now.add(const Duration(seconds: 15))),
      isTrue,
    );
    expect(state.mustDrainWhenFeatureDisabled, isFalse);
  });

  test('locks rematch while settlement is pending', () {
    final state = TienLenRoomState.fromJson(<String, dynamic>{
      'roomId': 'NT10001',
      'phase': 'round-ended',
      'baseBet': 100,
      'settlementStatus': 'pending',
      'viewerId': '7',
      'hostId': '7',
    });

    expect(state.isSettlementPending, isTrue);
    expect(state.canStartNextRound, isFalse);
    expect(state.mustDrainWhenFeatureDisabled, isTrue);
  });

  test('feature disable keeps active play but closes a waiting lobby', () {
    final playing = TienLenRoomState.fromJson(<String, dynamic>{
      'roomId': 'NT10001',
      'phase': 'playing',
      'settlementStatus': 'idle',
      'viewerId': '7',
      'hostId': '7',
    });
    final waiting = TienLenRoomState.fromJson(<String, dynamic>{
      'roomId': 'NT10002',
      'phase': 'waiting',
      'settlementStatus': 'idle',
      'viewerId': '7',
      'hostId': '7',
    });
    final completedWager = TienLenRoomState.fromJson(<String, dynamic>{
      'roomId': 'NT10003',
      'phase': 'round-ended',
      'baseBet': 100,
      'settlementStatus': 'settled',
      'viewerId': '7',
      'hostId': '7',
    });

    expect(playing.mustDrainWhenFeatureDisabled, isTrue);
    expect(waiting.mustDrainWhenFeatureDisabled, isFalse);
    expect(completedWager.mustDrainWhenFeatureDisabled, isFalse);
  });

  test('every selectable room is a positive-stake wager room', () {
    expect(demoRooms, isNotEmpty);
    expect(demoRooms.every((room) => room.baseBet > 0), isTrue);
    expect(demoRooms.every((room) => room.stakeLabel.endsWith(' xu')), isTrue);
    expect(demoRooms.any((room) => room.title.contains('Luyện Tập')), isFalse);
  });

  test('turn countdown rounds positive fractions up until the deadline', () {
    final now = DateTime.utc(2026, 10, 11, 12);

    TienLenRoomState playingUntil(Duration remaining) {
      return TienLenRoomState.fromJson(<String, dynamic>{
        'roomId': 'NTTIMER',
        'phase': 'playing',
        'viewerId': '7',
        'hostId': '7',
        'turnDeadlineAt': now.add(remaining).toIso8601String(),
      });
    }

    expect(
      playingUntil(const Duration(microseconds: 1)).remainingTurnSeconds(now),
      1,
    );
    expect(
      playingUntil(const Duration(milliseconds: 999)).remainingTurnSeconds(now),
      1,
    );
    expect(
      playingUntil(
        const Duration(milliseconds: 1000),
      ).remainingTurnSeconds(now),
      1,
    );
    expect(
      playingUntil(
        const Duration(milliseconds: 1001),
      ).remainingTurnSeconds(now),
      2,
    );
    expect(playingUntil(Duration.zero).remainingTurnSeconds(now), 0);
    expect(
      playingUntil(const Duration(milliseconds: -1)).remainingTurnSeconds(now),
      0,
    );
  });

  test('server opponent deadline rounds up and disappears after matching', () {
    final now = DateTime.utc(2026, 10, 11, 12);
    TienLenRoomState waitingUntil(Duration remaining) {
      return TienLenRoomState.fromJson(<String, dynamic>{
        'roomId': 'NTMATCH',
        'phase': 'waiting',
        'playerCount': 1,
        'viewerId': '7',
        'hostId': '7',
        'autoBotJoinDueAt': now.add(remaining).toIso8601String(),
      });
    }

    expect(
      waitingUntil(const Duration(seconds: 15)).remainingAutoMatchSeconds(now),
      15,
    );
    expect(
      waitingUntil(
        const Duration(milliseconds: 1),
      ).remainingAutoMatchSeconds(now),
      1,
    );
    expect(waitingUntil(Duration.zero).remainingAutoMatchSeconds(now), 0);
  });

  test('parses an active-round spectator without exposing a private hand', () {
    final state = TienLenRoomState.fromJson(<String, dynamic>{
      'roomId': 'NTSPECTATE',
      'phase': 'playing',
      'baseBet': 100,
      'maxPlayers': 4,
      'playerCount': 3,
      'activePlayerCount': 2,
      'waitingPlayerCount': 1,
      'viewerId': 'viewer-3',
      'viewerRole': 'spectator',
      'viewerWaitingForNextRound': true,
      'hostId': 'player-1',
      'currentTurnPlayerId': 'player-1',
      'players': const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'player-1',
          'seatIndex': 0,
          'name': 'Minh Khang',
          'handCount': 12,
          'hand': <dynamic>[],
        },
        <String, dynamic>{
          'id': 'player-2',
          'seatIndex': 1,
          'name': 'Lan Anh',
          'handCount': 11,
          'hand': <dynamic>[],
        },
      ],
      'spectators': const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'viewer-3',
          'seatIndex': 2,
          'name': 'Người xem',
          'coins': 6000,
          'handCount': 0,
          'hand': <dynamic>[],
          'waitingForNextRound': true,
          'eligibleForNextRound': true,
        },
      ],
    });

    expect(state.isSpectator, isTrue);
    expect(state.isViewerTurn, isFalse);
    expect(state.viewerPlayer, isNull);
    expect(state.viewerSpectator?.name, 'Người xem');
    expect(state.viewerSpectator?.hand, isEmpty);
    expect(state.viewerParticipant?.coins, 6000);
    expect(state.activePlayerCount, 2);
    expect(state.waitingPlayerCount, 1);
  });

  test('tags automated players as BOT in seats and turn logs', () {
    final state = TienLenRoomState.fromJson(<String, dynamic>{
      'roomId': 'NT10002',
      'phase': 'playing',
      'viewerId': '7',
      'turnLogs': <String>[
        'Minh Anh đánh đôi 5',
        'Lan bỏ lượt · Đến lượt Minh Anh',
        'Thảo Vy (BOT) đã sẵn sàng',
        'Minh Anh Tú vào xem bàn',
      ],
      'players': <Map<String, dynamic>>[
        <String, dynamic>{'id': '7', 'name': 'Lan'},
        <String, dynamic>{
          'id': 'bot-1',
          'name': 'Minh Anh',
          'isSystemOpponent': true,
        },
      ],
      'spectators': <Map<String, dynamic>>[
        <String, dynamic>{'id': '9', 'name': 'Minh Anh Tú'},
        <String, dynamic>{
          'id': 'bot-2',
          'name': 'Thảo Vy (BOT)',
          'isBot': true,
        },
      ],
    });

    expect(state.players.first.name, 'Lan');
    expect(state.players.last.name, 'Minh Anh (BOT)');
    expect(state.spectators.last.name, 'Thảo Vy (BOT)');
    expect(state.turnLogs, <String>[
      'Minh Anh (BOT) đánh đôi 5',
      'Lan bỏ lượt · Đến lượt Minh Anh (BOT)',
      'Thảo Vy (BOT) đã sẵn sàng',
      'Minh Anh Tú vào xem bàn',
    ]);
  });

  test('labels an unnamed automated player as BOT', () {
    expect(labelSystemOpponentName('  '), 'BOT');
    expect(labelSystemOpponentName('Gia Huy'), 'Gia Huy (BOT)');
  });
}
