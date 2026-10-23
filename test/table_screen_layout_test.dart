import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:social_hub_flutter/src/controllers/session_controller.dart';
import 'package:social_hub_flutter/src/game_tien_len/core/widgets/card_view.dart';
import 'package:social_hub_flutter/src/game_tien_len/core/widgets/gpt_button.dart';
import 'package:social_hub_flutter/src/game_tien_len/features/tien_len/data/game_data.dart';
import 'package:social_hub_flutter/src/game_tien_len/features/tien_len/data/realtime_game_models.dart';
import 'package:social_hub_flutter/src/game_tien_len/features/tien_len/presentation/screens/active_tables_screen.dart';
import 'package:social_hub_flutter/src/game_tien_len/features/tien_len/presentation/screens/table_screen.dart';
import 'package:social_hub_flutter/src/services/chat_api_service.dart';
import 'package:social_hub_flutter/src/services/chat_socket_service.dart';
import 'package:social_hub_flutter/src/services/device_identity_service.dart';
import 'package:social_hub_flutter/src/services/push_notification_service.dart';
import 'package:social_hub_flutter/src/services/storage_service.dart';

void main() {
  test('an active table with a free seat remains open for queued entry', () {
    const table = ActiveDemoTable(
      roomId: 'NTACTIVE',
      name: 'Phòng Thường',
      roomIndex: 0,
      currentPlayers: 2,
      activePlayers: 2,
      waitingPlayers: 0,
      maxPlayers: 4,
      wager: '100 xu',
      host: 'Phòng NTACTIVE',
      state: 'Đang chơi · Có thể vào xem',
      phase: 'playing',
    );

    expect(table.isFull, isFalse);
    expect(table.canJoin, isTrue);
    expect(table.joinsAsSpectator, isTrue);
  });

  testWidgets('turn notice stays visible on a 1600x900 landscape table', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: TableScreen(room: demoRooms.first)),
    );
    await tester.pump();

    expect(find.text('GIÂY CÒN LẠI'), findsOneWidget);
    expect(find.byType(TableScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'duplicate realtime state keeps selected cards and play action enabled',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final storageService = StorageService();
      final sessionController = SessionController(
        apiService: ChatApiService(),
        storageService: storageService,
        deviceIdentityService: DeviceIdentityService(storageService),
        pushNotificationService: const PushNotificationService(),
      );
      final socketService = _RealtimeTableSocketService();
      addTearDown(sessionController.dispose);
      addTearDown(socketService.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SessionController>.value(
              value: sessionController,
            ),
            Provider<ChatSocketService>.value(value: socketService),
          ],
          child: MaterialApp(
            home: RealtimeTableScreen(
              room: demoRooms.first,
              initialState: _playingState(),
            ),
          ),
        ),
      );
      await tester.pump();

      final playButton = find.byKey(
        const ValueKey<String>('realtime-play-button'),
      );
      expect(tester.widget<GptButton>(playButton).onPressed, isNull);

      await tester.tap(find.byType(PlayingCardView).first);
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester
            .widget<PlayingCardView>(find.byType(PlayingCardView).first)
            .selected,
        isTrue,
      );
      expect(tester.widget<GptButton>(playButton).onPressed, isNotNull);

      socketService.emitRoomState(_playingState());
      await tester.pump();

      expect(
        tester
            .widget<PlayingCardView>(find.byType(PlayingCardView).first)
            .selected,
        isTrue,
      );
      expect(tester.widget<GptButton>(playButton).onPressed, isNotNull);
      expect(
        find.text('Đã chọn 1 lá · Bấm Đánh bài để gửi lượt'),
        findsOneWidget,
      );

      tester.widget<GptButton>(playButton).onPressed!.call();
      await tester.pump();
      expect(socketService.playedCardCodes, <String>['3D']);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'active-round entrant watches public play and cannot use player actions',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final storageService = StorageService();
      final sessionController = SessionController(
        apiService: ChatApiService(),
        storageService: storageService,
        deviceIdentityService: DeviceIdentityService(storageService),
        pushNotificationService: const PushNotificationService(),
      );
      final socketService = _RealtimeTableSocketService();
      addTearDown(sessionController.dispose);
      addTearDown(socketService.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SessionController>.value(
              value: sessionController,
            ),
            Provider<ChatSocketService>.value(value: socketService),
          ],
          child: MaterialApp(
            home: RealtimeTableScreen(
              room: demoRooms.first,
              initialState: _spectatorState(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('ĐANG XEM VÁN HIỆN TẠI'), findsOneWidget);
      expect(
        find.text('Đang xem ván hiện tại · Bạn sẽ vào từ ván kế tiếp'),
        findsWidgets,
      );
      expect(
        find.byKey(const ValueKey<String>('spectator-waiting-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('waiting-next-round-badge')),
        findsOneWidget,
      );
      expect(find.byType(CardBackView), findsWidgets);
      expect(find.byType(PlayingCardView), findsOneWidget);

      for (final key in <String>[
        'realtime-sort-button',
        'realtime-play-button',
        'realtime-pass-button',
      ]) {
        expect(
          tester.widget<GptButton>(find.byKey(ValueKey<String>(key))).onPressed,
          isNull,
        );
      }
      expect(find.bySemanticsLabel('Mở menu bàn chơi'), findsOneWidget);
      expect(find.textContaining('Đối thủ hệ thống'), findsNothing);
      expect(find.textContaining('BOT'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('round restart errors never expose automation internals', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storageService = StorageService();
    final sessionController = SessionController(
      apiService: ChatApiService(),
      storageService: storageService,
      deviceIdentityService: DeviceIdentityService(storageService),
      pushNotificationService: const PushNotificationService(),
    );
    final socketService = _RealtimeTableSocketService(
      startError: Exception('invalid-bot-bankroll-activation'),
    );
    addTearDown(sessionController.dispose);
    addTearDown(socketService.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionController>.value(
            value: sessionController,
          ),
          Provider<ChatSocketService>.value(value: socketService),
        ],
        child: MaterialApp(
          home: RealtimeTableScreen(
            room: demoRooms.first,
            initialState: _roundEndedState(),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Chia ván mới'));
    await tester.pump();

    expect(
      find.text(
        'Không bắt đầu được ván mới: dịch vụ bàn chơi tạm thời '
        'chưa sẵn sàng, vui lòng thử lại',
      ),
      findsOneWidget,
    );
    // Internal error codes stay hidden; BOT text may only be a seat tag.
    expect(find.textContaining('bot'), findsNothing);
    expect(find.textContaining('bankroll'), findsNothing);
    expect(find.textContaining(RegExp(r'BOT(?!\))')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

TienLenRoomState _roundEndedState() {
  return TienLenRoomState.fromJson(<String, dynamic>{
    'roomId': 'NTROUNDENDED',
    'title': 'Phòng Thường',
    'phase': 'round-ended',
    'baseBet': 100,
    'maxPlayers': 4,
    'playerCount': 2,
    'activePlayerCount': 2,
    'waitingPlayerCount': 0,
    'roundNumber': 1,
    'roundId': 'round-ended-1',
    'settlementStatus': 'idle',
    'viewerId': '7',
    'viewerRole': 'player',
    'viewerWaitingForNextRound': false,
    'hostId': '7',
    'currentTurnPlayerId': '',
    'lastActorId': 'seat-1',
    'firstPlayPending': false,
    'coveredTableCardCount': 0,
    'tableCards': const <dynamic>[],
    'lastPlay': null,
    'passedPlayerIds': const <dynamic>[],
    'finishedOrder': const <dynamic>['7', 'seat-1'],
    'turnLogs': const <dynamic>['Người chơi thắng ván 1'],
    'moneyEvents': const <dynamic>[],
    'nextRoundAllowedAt': DateTime.now()
        .subtract(const Duration(seconds: 1))
        .toIso8601String(),
    'players': const <Map<String, dynamic>>[
      <String, dynamic>{
        'id': '7',
        'seatIndex': 0,
        'name': 'Người chơi',
        'isSystemOpponent': false,
        'connected': true,
        'ready': true,
        'coins': 6100,
        'handCount': 0,
        'hand': <dynamic>[],
        'finished': true,
      },
      <String, dynamic>{
        'id': 'seat-1',
        'seatIndex': 1,
        'name': 'Minh Khang',
        'isSystemOpponent': true,
        'connected': true,
        'ready': true,
        'coins': 12400,
        'handCount': 0,
        'hand': <dynamic>[],
        'finished': true,
      },
    ],
    'spectators': const <dynamic>[],
  });
}

TienLenRoomState _playingState() {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  return TienLenRoomState.fromJson(<String, dynamic>{
    'roomId': 'NTREALTIMEPLAY',
    'title': 'Phòng Thường',
    'phase': 'playing',
    'baseBet': 100,
    'maxPlayers': 4,
    'playerCount': 2,
    'humanCount': 1,
    'botCount': 1,
    'roundNumber': 1,
    'roundId': 'round-1',
    'settlementStatus': 'idle',
    'viewerId': '7',
    'hostId': '7',
    'currentTurnPlayerId': '7',
    'lastActorId': '',
    'firstPlayPending': true,
    'coveredTableCardCount': 0,
    'tableCards': const <dynamic>[],
    'lastPlay': null,
    'passedPlayerIds': const <dynamic>[],
    'finishedOrder': const <dynamic>[],
    'turnLogs': const <dynamic>['Người chơi được mở lượt'],
    'turnStartedAt': DateTime.now().toIso8601String(),
    'turnDeadlineAt': deadline.toIso8601String(),
    'turnDurationSeconds': 30,
    'players': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': '7',
        'seatIndex': 0,
        'name': 'Người chơi',
        'isSystemOpponent': false,
        'connected': true,
        'ready': true,
        'coins': 6000,
        'handCount': 2,
        'hand': const <Map<String, dynamic>>[
          <String, dynamic>{
            'rank': '3',
            'suit': 'diamonds',
            'code': '3D',
            'label': '3♦',
          },
          <String, dynamic>{
            'rank': '4',
            'suit': 'clubs',
            'code': '4C',
            'label': '4♣',
          },
        ],
        'finished': false,
      },
      <String, dynamic>{
        'id': 'seat-1',
        'seatIndex': 1,
        'name': 'Minh Khang',
        'isSystemOpponent': true,
        'connected': true,
        'ready': true,
        'coins': 12500,
        'handCount': 13,
        'hand': const <dynamic>[],
        'finished': false,
      },
    ],
  });
}

TienLenRoomState _spectatorState() {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  return TienLenRoomState.fromJson(<String, dynamic>{
    'roomId': 'NTSPECTATOR',
    'title': 'Phòng Thường',
    'phase': 'playing',
    'baseBet': 100,
    'maxPlayers': 4,
    'playerCount': 3,
    'activePlayerCount': 2,
    'waitingPlayerCount': 1,
    'roundNumber': 2,
    'roundId': 'round-2',
    'settlementStatus': 'idle',
    'viewerId': 'viewer-3',
    'viewerRole': 'spectator',
    'viewerWaitingForNextRound': true,
    'hostId': 'seat-1',
    'currentTurnPlayerId': 'seat-1',
    'lastActorId': 'seat-2',
    'firstPlayPending': false,
    'coveredTableCardCount': 0,
    'tableCards': const <Map<String, dynamic>>[
      <String, dynamic>{
        'rank': '8',
        'suit': 'clubs',
        'code': '8C',
        'label': '8♣',
      },
    ],
    'lastPlay': const <String, dynamic>{
      'type': 'single',
      'rankValue': 8,
      'suitValue': 1,
      'summary': 'một lá',
      'cards': <Map<String, dynamic>>[
        <String, dynamic>{
          'rank': '8',
          'suit': 'clubs',
          'code': '8C',
          'label': '8♣',
        },
      ],
    },
    'turnLogs': const <dynamic>['Lan Anh vừa đánh bài'],
    'turnStartedAt': DateTime.now().toIso8601String(),
    'turnDeadlineAt': deadline.toIso8601String(),
    'players': const <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'seat-1',
        'seatIndex': 0,
        'name': 'Minh Khang',
        'connected': true,
        'ready': true,
        'coins': 5800,
        'handCount': 12,
        'hand': <dynamic>[],
      },
      <String, dynamic>{
        'id': 'seat-2',
        'seatIndex': 1,
        'name': 'Lan Anh',
        'connected': true,
        'ready': true,
        'coins': 6200,
        'handCount': 11,
        'hand': <dynamic>[],
      },
    ],
    'spectators': const <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'viewer-3',
        'seatIndex': 2,
        'name': 'Người xem',
        'connected': true,
        'ready': false,
        'coins': 6000,
        'handCount': 0,
        'hand': <dynamic>[],
        'waitingForNextRound': true,
        'eligibleForNextRound': true,
      },
    ],
  });
}

class _RealtimeTableSocketService extends ChatSocketService {
  _RealtimeTableSocketService({this.startError});

  final Object? startError;
  final StreamController<TienLenRoomState> _states =
      StreamController<TienLenRoomState>.broadcast();

  List<String> playedCardCodes = const <String>[];

  @override
  Stream<TienLenRoomState> get tienLenRoomStateStream => _states.stream;

  void emitRoomState(TienLenRoomState state) => _states.add(state);

  @override
  Future<TienLenRoomState> playTienLenCards(List<String> cardCodes) async {
    playedCardCodes = List<String>.of(cardCodes);
    return _playingState();
  }

  @override
  Future<TienLenRoomState> startTienLenRoom({bool fillBots = false}) async {
    final error = startError;
    if (error != null) throw error;
    return _playingState();
  }

  @override
  Future<void> leaveTienLenRoom() async {}

  @override
  Future<void> dispose() async {
    await _states.close();
    await super.dispose();
  }
}
