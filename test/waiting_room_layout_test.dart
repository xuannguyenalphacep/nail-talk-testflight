import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:social_hub_flutter/src/controllers/session_controller.dart';
import 'package:social_hub_flutter/src/game_tien_len/core/theme/game_theme.dart';
import 'package:social_hub_flutter/src/game_tien_len/core/widgets/gpt_button.dart';
import 'package:social_hub_flutter/src/game_tien_len/features/tien_len/data/game_data.dart';
import 'package:social_hub_flutter/src/game_tien_len/features/tien_len/data/realtime_game_models.dart';
import 'package:social_hub_flutter/src/game_tien_len/features/tien_len/presentation/screens/waiting_room_screen.dart';
import 'package:social_hub_flutter/src/models/chat_app_model.dart';
import 'package:social_hub_flutter/src/models/session_user.dart';
import 'package:social_hub_flutter/src/services/chat_api_service.dart';
import 'package:social_hub_flutter/src/services/chat_socket_service.dart';
import 'package:social_hub_flutter/src/services/device_identity_service.dart';
import 'package:social_hub_flutter/src/services/push_notification_service.dart';
import 'package:social_hub_flutter/src/services/storage_service.dart';

void main() {
  testWidgets(
    'every room wagers and the server matches one opponent after 15 seconds',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1055, 462);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final storageService = StorageService();
      final sessionController = _TestSessionController(storageService);
      final socketService = _TestChatSocketService();
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
          child: MaterialApp(home: _WaitingRoomHarness(room: demoRooms.first)),
        ),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('open-waiting-room-button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const ValueKey<String>('ready-room-button')), findsOne);
      expect(find.byKey(const ValueKey<String>('leave-room-button')), findsOne);
      expect(find.byKey(const ValueKey<String>('start-room-button')), findsOne);
      expect(find.bySemanticsLabel('Mời bạn'), findsNothing);
      expect(socketService.createdBaseBet, 100);
      expect(find.textContaining('Không tính xu'), findsNothing);
      expect(find.textContaining('BOT'), findsNothing);

      final Rect leaveButtonRect = tester.getRect(
        find.byKey(const ValueKey<String>('leave-room-button')),
      );
      expect(leaveButtonRect.left, greaterThanOrEqualTo(0));
      expect(leaveButtonRect.top, greaterThanOrEqualTo(0));
      expect(leaveButtonRect.right, lessThanOrEqualTo(1055));
      expect(leaveButtonRect.bottom, lessThanOrEqualTo(462));

      expect(
        socketService.createdRoomIds.single,
        matches(RegExp(r'^NT[A-Z2-9]{16}$')),
      );

      // Matching is owned by the server, happens once after 15 seconds, and
      // does not require the player to mark ready first.
      await tester.pump(const Duration(seconds: 14));
      await tester.pump();
      expect(socketService.addBotCalls, 0);
      expect(socketService.currentBotCount, 0);
      expect(socketService.startCalls, 0);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(socketService.addBotCalls, 0);
      expect(socketService.currentBotCount, 1);
      expect(find.text('Minh Khang'), findsOne);
      expect(find.text('Đã sẵn sàng'), findsOne);
      expect(find.text('Bạn · Chủ bàn · Chưa sẵn sàng'), findsOne);
      expect(find.textContaining('2/4 người chơi · Chờ Sẵn sàng'), findsOne);
      expect(
        find.text(
          'Đối thủ đang chờ chủ phòng bấm Sẵn sàng · '
          'Ván chưa bắt đầu, chưa trừ xu',
        ),
        findsOne,
      );
      expect(find.textContaining('BOT'), findsNothing);
      expect(find.byKey(const ValueKey<String>('leave-room-button')), findsOne);
      expect(socketService.readyCalls, 0);
      expect(socketService.startCalls, 0);
      expect(sessionController.user?.gameCoins, 6000);
      expect(
        tester
            .widget<GptButton>(
              find.byKey(const ValueKey<String>('start-room-button')),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const ValueKey<String>('ready-room-button')));
      await tester.pump();
      expect(find.bySemanticsLabel('Hủy sẵn sàng'), findsOne);
      expect(socketService.readyCalls, 1);
      expect(
        find.byKey(const ValueKey<String>('waiting-wager-safety-notice')),
        findsNothing,
      );
      expect(
        tester
            .widget<GptButton>(
              find.byKey(const ValueKey<String>('start-room-button')),
            )
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.byKey(const ValueKey<String>('leave-room-button')));
      await tester.pumpAndSettle();
      expect(socketService.leaveCalls, 1);
      expect(find.byType(WaitingRoomScreen), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('open-waiting-room-button')),
        findsOne,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'ready player still waits for the server 15-second opponent deadline',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1055, 462);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final storageService = StorageService();
      final sessionController = _TestSessionController(storageService);
      final socketService = _TestChatSocketService();
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
          child: MaterialApp(home: _WaitingRoomHarness(room: demoRooms.first)),
        ),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('open-waiting-room-button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(socketService.createdBaseBet, demoRooms.first.baseBet);
      expect(find.byKey(const ValueKey<String>('ready-room-button')), findsOne);
      expect(find.byKey(const ValueKey<String>('leave-room-button')), findsOne);
      expect(find.byKey(const ValueKey<String>('start-room-button')), findsOne);
      expect(find.bySemanticsLabel('Mời bạn'), findsNothing);
      expect(find.textContaining('BOT'), findsNothing);

      await tester.tap(find.byKey(const ValueKey<String>('ready-room-button')));
      await tester.pump();
      expect(find.bySemanticsLabel('Hủy sẵn sàng'), findsOne);
      expect(find.byKey(const ValueKey<String>('leave-room-button')), findsOne);

      await tester.pump(const Duration(seconds: 14));
      await tester.pump();
      expect(socketService.currentBotCount, 0);
      expect(socketService.startCalls, 0);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(socketService.addBotCalls, 0);
      expect(socketService.currentBotCount, 1);
      expect(socketService.startCalls, 0);
      expect(
        tester
            .widget<GptButton>(
              find.byKey(const ValueKey<String>('start-room-button')),
            )
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.byKey(const ValueKey<String>('leave-room-button')));
      await tester.pumpAndSettle();
      expect(socketService.leaveCalls, 1);
      expect(find.byType(WaitingRoomScreen), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'two real players are shown unready from both host and guest snapshots',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1055, 462);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final viewerIsHost in <bool>[true, false]) {
        final storageService = StorageService();
        final sessionController = _TestSessionController(storageService);
        final socketService = _TestChatSocketService(
          includeUnreadyHumanOpponent: true,
          viewerIsHost: viewerIsHost,
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<SessionController>.value(
                value: sessionController,
              ),
              Provider<ChatSocketService>.value(value: socketService),
            ],
            child: MaterialApp(
              home: WaitingRoomScreen(
                room: demoRooms.first,
                roomId: 'NTTWOHUMANS',
                hostName: viewerIsHost ? 'Tây Bích 88' : 'Chủ phòng',
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final expectedDetail = viewerIsHost
            ? 'Đang chuẩn bị'
            : 'Chủ phòng · Chưa sẵn sàng';
        final opponentSeat = find.byKey(
          const ValueKey<String>('waiting-opponent-seat-1'),
        );
        final detailFinder = find.descendant(
          of: opponentSeat,
          matching: find.text(expectedDetail),
        );

        expect(opponentSeat, findsOneWidget);
        expect(detailFinder, findsOneWidget);
        expect(find.text('Chủ phòng · Sẵn sàng'), findsNothing);
        expect(find.text('Đã sẵn sàng'), findsNothing);
        expect(tester.widget<Text>(detailFinder).style?.color, GameTheme.gold);
        expect(
          tester
              .widget<GptButton>(
                find.byKey(const ValueKey<String>('start-room-button')),
              )
              .onPressed,
          isNull,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        sessionController.dispose();
        await socketService.dispose();
      }
    },
  );

  testWidgets('room ID collision retries create and never joins that room', (
    WidgetTester tester,
  ) async {
    final storageService = StorageService();
    final sessionController = _TestSessionController(storageService);
    final socketService = _TestChatSocketService(
      createErrors: <Object>[Exception('room-already-exists')],
    );
    final generatedIds = <String>['NTCOLLISIONONE', 'NTCOLLISIONTWO'];
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
          home: WaitingRoomScreen(
            room: demoRooms.first,
            roomIdGenerator: () => generatedIds.removeAt(0),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(socketService.createdRoomIds, <String>[
      'NTCOLLISIONONE',
      'NTCOLLISIONTWO',
    ]);
    expect(socketService.joinCalls, 0);
    expect(find.textContaining('NTCOLLISIONTWO'), findsOne);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('failed create retries with a fresh ID and never joins', (
    WidgetTester tester,
  ) async {
    final storageService = StorageService();
    final sessionController = _TestSessionController(storageService);
    final socketService = _TestChatSocketService(
      createErrors: <Object>[Exception('ack-timeout')],
    );
    final generatedIds = <String>['NTFAILEDATTEMPT', 'NTFRESHATTEMPT'];
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
          home: WaitingRoomScreen(
            room: demoRooms.first,
            roomIdGenerator: () => generatedIds.removeAt(0),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(socketService.createdRoomIds, <String>['NTFAILEDATTEMPT']);
    expect(socketService.joinCalls, 0);
    expect(socketService.leaveCalls, 1);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 100));

    expect(socketService.createdRoomIds, <String>[
      'NTFAILEDATTEMPT',
      'NTFRESHATTEMPT',
    ]);
    expect(socketService.joinCalls, 0);
    expect(find.textContaining('NTFRESHATTEMPT'), findsOne);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('lost owned room is recreated automatically after reconnect', (
    WidgetTester tester,
  ) async {
    final storageService = StorageService();
    final sessionController = _TestSessionController(storageService);
    final socketService = _TestChatSocketService();
    final generatedIds = <String>['NTBEFORERESTART', 'NTAFTERRESTART'];
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
          home: WaitingRoomScreen(
            room: demoRooms.first,
            roomIdGenerator: () => generatedIds.removeAt(0),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(socketService.createdRoomIds, <String>['NTBEFORERESTART']);

    socketService.emitReconnectFailed('NTBEFORERESTART');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(socketService.createdRoomIds, <String>[
      'NTBEFORERESTART',
      'NTAFTERRESTART',
    ]);
    expect(find.textContaining('NTAFTERRESTART'), findsOne);
    expect(find.textContaining('Mất kết nối'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('matchmaking service errors never expose automation internals', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1055, 462);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storageService = StorageService();
    final sessionController = _TestSessionController(storageService);
    final socketService = _TestChatSocketService(
      startError: Exception('game-bot-bankroll-unavailable'),
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
        child: MaterialApp(home: _WaitingRoomHarness(room: demoRooms.first)),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('open-waiting-room-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.pump(const Duration(seconds: 16));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('ready-room-button')));
    await tester.pump();
    await tester.pump();
    final startButton = tester.widget<GptButton>(
      find.byKey(const ValueKey<String>('start-room-button')),
    );
    expect(startButton.onPressed, isNotNull);
    startButton.onPressed!.call();
    await tester.pump();
    await tester.pump();

    expect(
      find.textContaining('chưa thể ghép đối thủ lúc này'),
      findsOneWidget,
    );
    expect(socketService.startCalls, 1);
    expect(find.textContaining('bot'), findsNothing);
    expect(find.textContaining('BOT'), findsNothing);
    expect(find.textContaining('bankroll'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _WaitingRoomHarness extends StatelessWidget {
  const _WaitingRoomHarness({required this.room});

  final DemoRoom room;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          key: const ValueKey<String>('open-waiting-room-button'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => WaitingRoomScreen(room: room),
            ),
          ),
          child: const Text('Mở phòng chờ'),
        ),
      ),
    );
  }
}

class _TestSessionController extends SessionController {
  _TestSessionController(StorageService storageService)
    : super(
        apiService: ChatApiService(),
        storageService: storageService,
        deviceIdentityService: DeviceIdentityService(storageService),
        pushNotificationService: const PushNotificationService(),
      );

  final SessionUser _testUser = SessionUser(
    id: 7,
    uuid: 'user-7',
    name: 'Người chơi',
    username: 'player7',
    email: '',
    phone: '',
    bio: '',
    companyId: 1,
    avatarUrl: '',
    gameCoins: 6000,
    gameCoinGrantedOn: '',
  );

  final ChatAppModel _testApp = ChatAppModel(
    uuid: 'app-1',
    code: 'social-hub',
    name: 'Social Hub',
    logoUrl: '',
    appUrl: '',
    apiBaseUrl: 'http://127.0.0.1:8010/api',
    socketUrl: 'http://127.0.0.1:3000',
    videoEnabled: true,
    cardGameEnabled: true,
  );

  @override
  SessionUser? get user => _testUser;

  @override
  ChatAppModel? get selectedApp => _testApp;

  @override
  String? get token => 'test-token';
}

class _TestChatSocketService extends ChatSocketService {
  _TestChatSocketService({
    List<Object>? createErrors,
    this.includeUnreadyHumanOpponent = false,
    this.viewerIsHost = true,
    this.startError,
  }) : _createErrors = List<Object>.of(createErrors ?? const <Object>[]);

  final List<Object> _createErrors;
  final bool includeUnreadyHumanOpponent;
  final bool viewerIsHost;
  final Object? startError;
  final StreamController<TienLenRoomState> _roomStates =
      StreamController<TienLenRoomState>.broadcast();
  final StreamController<Map<String, dynamic>> _gameEvents =
      StreamController<Map<String, dynamic>>.broadcast();
  Timer? _serverAutoMatchTimer;
  DateTime? _autoMatchDueAt;
  int addBotCalls = 0;
  int currentBotCount = 0;
  int leaveCalls = 0;
  int joinCalls = 0;
  bool _ready = false;
  String _roomId = 'NT12345';
  final List<String> createdRoomIds = <String>[];
  int? createdBaseBet;
  int startCalls = 0;
  int readyCalls = 0;
  bool? lastStartFillBots;

  @override
  bool get isConnected => true;

  @override
  Stream<TienLenRoomState> get tienLenRoomStateStream => _roomStates.stream;

  @override
  Stream<Map<String, dynamic>> get tienLenEventStream => _gameEvents.stream;

  void emitReconnectFailed(String roomId) {
    _gameEvents.add(<String, dynamic>{
      'event': 'reconnect-failed',
      'roomId': roomId,
      'message': 'Exception: room-not-found',
    });
  }

  void _scheduleServerAutoMatch() {
    _serverAutoMatchTimer?.cancel();
    currentBotCount = 0;
    _autoMatchDueAt = DateTime.now().add(const Duration(seconds: 15));
    _serverAutoMatchTimer = Timer(const Duration(seconds: 15), () {
      currentBotCount = 1;
      _autoMatchDueAt = null;
      _roomStates.add(_state());
    });
  }

  @override
  Future<TienLenRoomState> createTienLenRoom({
    required String roomId,
    required String title,
    required int baseBet,
    required int userId,
    required String name,
    required int coins,
    int maxPlayers = 4,
  }) async {
    createdRoomIds.add(roomId);
    _roomId = roomId;
    createdBaseBet = baseBet;
    if (_createErrors.isNotEmpty) throw _createErrors.removeAt(0);
    _scheduleServerAutoMatch();
    return _state();
  }

  @override
  Future<TienLenRoomState> joinTienLenRoom({
    required String roomId,
    required int userId,
    required String name,
    required int coins,
    String? title,
    int? baseBet,
  }) async {
    joinCalls++;
    _roomId = roomId;
    createdBaseBet = baseBet;
    return _state();
  }

  @override
  Future<TienLenRoomState> addTienLenBot() async {
    addBotCalls++;
    return _state();
  }

  @override
  Future<TienLenRoomState> readyTienLen({bool ready = true}) async {
    readyCalls++;
    _ready = ready;
    return _state();
  }

  @override
  Future<TienLenRoomState> startTienLenRoom({bool fillBots = false}) async {
    startCalls++;
    lastStartFillBots = fillBots;
    final error = startError;
    if (error != null) throw error;
    return _state();
  }

  @override
  Future<void> leaveTienLenRoom() async {
    leaveCalls++;
    _serverAutoMatchTimer?.cancel();
    _serverAutoMatchTimer = null;
    _autoMatchDueAt = null;
  }

  @override
  Future<void> forceLeaveTienLenRoom() async {
    leaveCalls++;
    _serverAutoMatchTimer?.cancel();
    _serverAutoMatchTimer = null;
    _autoMatchDueAt = null;
  }

  TienLenRoomState _state() {
    final botCount = currentBotCount;
    final players = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': '7',
        'seatIndex': 0,
        'name': 'Người chơi',
        'isSystemOpponent': false,
        'connected': true,
        'ready': _ready,
        'coins': 6000,
        'handCount': 0,
        'hand': const <dynamic>[],
        'finished': false,
      },
      if (includeUnreadyHumanOpponent)
        <String, dynamic>{
          'id': '8',
          'seatIndex': 1,
          'name': viewerIsHost ? 'Người chơi 2' : 'Chủ phòng',
          'isSystemOpponent': false,
          'connected': true,
          'ready': false,
          'coins': 6000,
          'handCount': 0,
          'hand': const <dynamic>[],
          'finished': false,
        },
      for (int index = 0; index < botCount; index++)
        <String, dynamic>{
          'id': 'bot-${index + 1}',
          'seatIndex': index + 1,
          'name': index == 0 ? 'Minh Khang' : 'Lan Anh',
          'isSystemOpponent': true,
          'connected': true,
          'ready': true,
          'coins': 0,
          'handCount': 0,
          'hand': const <dynamic>[],
          'finished': false,
        },
    ];
    return TienLenRoomState.fromJson(<String, dynamic>{
      'roomId': _roomId,
      'title': 'Phòng cược',
      'phase': 'waiting',
      'baseBet': createdBaseBet ?? 100,
      'maxPlayers': 4,
      'playerCount': players.length,
      'humanCount': includeUnreadyHumanOpponent ? 2 : 1,
      'botCount': botCount,
      'viewerId': '7',
      'hostId': viewerIsHost ? '7' : '8',
      'players': players,
      if (_autoMatchDueAt != null)
        'autoBotJoinDueAt': _autoMatchDueAt!.toIso8601String(),
    });
  }

  @override
  Future<void> dispose() async {
    _serverAutoMatchTimer?.cancel();
    await _roomStates.close();
    await _gameEvents.close();
    await super.dispose();
  }
}
