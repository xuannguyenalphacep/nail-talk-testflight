import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:social_hub_flutter/src/controllers/session_controller.dart';
import 'package:social_hub_flutter/src/game_tien_len/core/widgets/gpt_button.dart';
import 'package:social_hub_flutter/src/game_tien_len/features/tien_len/data/realtime_game_models.dart';
import 'package:social_hub_flutter/src/game_tien_len/features/tien_len/presentation/screens/active_tables_screen.dart';
import 'package:social_hub_flutter/src/game_tien_len/features/tien_len/presentation/screens/table_screen.dart';
import 'package:social_hub_flutter/src/game_tien_len/features/tien_len/presentation/screens/waiting_room_screen.dart';
import 'package:social_hub_flutter/src/models/chat_app_model.dart';
import 'package:social_hub_flutter/src/models/session_user.dart';
import 'package:social_hub_flutter/src/screens/tien_len_game_screen.dart';
import 'package:social_hub_flutter/src/services/chat_api_service.dart';
import 'package:social_hub_flutter/src/services/chat_socket_service.dart';
import 'package:social_hub_flutter/src/services/device_identity_service.dart';
import 'package:social_hub_flutter/src/services/push_notification_service.dart';
import 'package:social_hub_flutter/src/services/storage_service.dart';

void main() {
  testWidgets(
    'nested game navigator can enter an active table without deactivating inherited providers',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final storage = StorageService();
      final session = _ActiveTableSessionController(storage);
      final socket = _ActiveTableSocketService();
      addTearDown(session.dispose);
      addTearDown(socket.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SessionController>.value(value: session),
            Provider<ChatSocketService>.value(value: socket),
          ],
          child: const MaterialApp(home: TienLenGameScreen()),
        ),
      );
      await tester.pump();

      expect(find.byType(Navigator), findsNWidgets(2));
      await tester.tap(
        find.text('BÀN ĐANG CHƠI', findRichText: true).first,
        warnIfMissed: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final enterButton = find.byWidgetPredicate(
        (widget) =>
            widget is GptButton &&
            widget.semanticLabel == 'Xem bàn Phòng Thường và chờ ván sau',
      );
      expect(enterButton, findsOneWidget);
      tester.widget<GptButton>(enterButton).onPressed!.call();
      await tester.pump();
      tester.view.physicalSize = const Size(900, 1600);
      session.completeDailyClaim();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(socket.joinCalls, 1);
      expect(find.byType(WaitingRoomScreen), findsNothing);
      expect(find.byType(RealtimeTableScreen), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('spectator-waiting-panel')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'active table opens spectator table directly without replacing a lobby route',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final storage = StorageService();
      final session = _ActiveTableSessionController(storage);
      final socket = _ActiveTableSocketService();
      addTearDown(session.dispose);
      addTearDown(socket.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SessionController>.value(value: session),
            Provider<ChatSocketService>.value(value: socket),
          ],
          child: const MaterialApp(home: ActiveTablesScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('XEM · CHỜ VÁN SAU'), findsOneWidget);
      final enterButton = find.byWidgetPredicate(
        (widget) =>
            widget is GptButton &&
            widget.semanticLabel == 'Xem bàn Phòng Thường và chờ ván sau',
      );
      expect(enterButton, findsOneWidget);
      tester.widget<GptButton>(enterButton).onPressed!.call();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(socket.joinCalls, 1);
      expect(find.byType(WaitingRoomScreen), findsNothing);
      expect(find.byType(RealtimeTableScreen), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('spectator-waiting-panel')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}

class _ActiveTableSessionController extends SessionController {
  _ActiveTableSessionController(StorageService storage)
    : super(
        apiService: ChatApiService(),
        storageService: storage,
        deviceIdentityService: DeviceIdentityService(storage),
        pushNotificationService: const PushNotificationService(),
      );

  final Completer<int> _dailyClaim = Completer<int>();

  final SessionUser _user = SessionUser(
    id: 7,
    uuid: 'viewer-7',
    name: 'Người xem',
    username: 'viewer7',
    email: '',
    phone: '',
    bio: '',
    companyId: 1,
    avatarUrl: '',
    gameCoins: 6000,
    gameCoinGrantedOn: '',
  );

  final ChatAppModel _app = ChatAppModel(
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
  SessionUser? get user => _user;

  @override
  ChatAppModel? get selectedApp => _app;

  @override
  String? get token => 'test-token';

  @override
  bool get isLoggedIn => true;

  @override
  bool get cardGameFeatureEnabled => true;

  @override
  Future<int> claimGameDailyCoin() => _dailyClaim.future;

  void completeDailyClaim() {
    if (_dailyClaim.isCompleted) return;
    notifyListeners();
    _dailyClaim.complete(0);
  }

  @override
  Future<SessionUser?> refreshCurrentUser({bool notify = true}) async => _user;
}

class _ActiveTableSocketService extends ChatSocketService {
  final StreamController<TienLenRoomState> _states =
      StreamController<TienLenRoomState>.broadcast();
  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();

  int joinCalls = 0;

  @override
  bool get isConnected => true;

  @override
  Stream<TienLenRoomState> get tienLenRoomStateStream => _states.stream;

  @override
  Stream<Map<String, dynamic>> get tienLenEventStream => _events.stream;

  @override
  Future<List<TienLenRoomSummary>> listTienLenRooms() async {
    return <TienLenRoomSummary>[
      TienLenRoomSummary.fromJson(const <String, dynamic>{
        'roomId': 'NTACTIVE',
        'title': 'Phòng Thường',
        'phase': 'playing',
        'baseBet': 100,
        'maxPlayers': 4,
        'playerCount': 2,
        'activePlayerCount': 2,
        'waitingPlayerCount': 0,
        'roundNumber': 1,
      }),
    ];
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
    return _spectatorState();
  }

  TienLenRoomState _spectatorState() {
    return TienLenRoomState.fromJson(<String, dynamic>{
      'roomId': 'NTACTIVE',
      'title': 'Phòng Thường',
      'phase': 'playing',
      'baseBet': 100,
      'maxPlayers': 4,
      'playerCount': 3,
      'activePlayerCount': 2,
      'waitingPlayerCount': 1,
      'roundNumber': 1,
      'roundId': 'round-1',
      'viewerId': '7',
      'viewerRole': 'spectator',
      'viewerWaitingForNextRound': true,
      'hostId': '1',
      'currentTurnPlayerId': '1',
      'turnDeadlineAt': DateTime.now()
          .add(const Duration(seconds: 20))
          .toIso8601String(),
      'players': const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': '1',
          'seatIndex': 0,
          'name': 'Minh Khang',
          'coins': 6000,
          'handCount': 13,
          'hand': <dynamic>[],
        },
        <String, dynamic>{
          'id': '2',
          'seatIndex': 1,
          'name': 'Lan Anh',
          'coins': 6000,
          'handCount': 13,
          'hand': <dynamic>[],
        },
      ],
      'spectators': const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': '7',
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
  }

  @override
  Future<void> leaveTienLenRoom() async {}

  @override
  Future<void> dispose() async {
    await _states.close();
    await _events.close();
    await super.dispose();
  }
}
