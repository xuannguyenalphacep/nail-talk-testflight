import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:social_hub_flutter/src/controllers/session_controller.dart';
import 'package:social_hub_flutter/src/game_tien_len/features/tien_len/data/game_data.dart';
import 'package:social_hub_flutter/src/game_tien_len/features/tien_len/data/realtime_game_models.dart';
import 'package:social_hub_flutter/src/game_tien_len/features/tien_len/presentation/screens/table_screen.dart';
import 'package:social_hub_flutter/src/models/session_user.dart';
import 'package:social_hub_flutter/src/screens/tien_len_game_screen.dart';
import 'package:social_hub_flutter/src/services/chat_api_service.dart';
import 'package:social_hub_flutter/src/services/chat_socket_service.dart';
import 'package:social_hub_flutter/src/services/device_identity_service.dart';
import 'package:social_hub_flutter/src/services/push_notification_service.dart';
import 'package:social_hub_flutter/src/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'landscape game shell reserves a side rail for the close button',
    (WidgetTester tester) async {
      final harness = _GameShellHarness();
      addTearDown(harness.dispose);
      await _setSurface(tester, const Size(1024, 600));

      await tester.pumpWidget(harness.buildApp());
      await tester.pump();

      final Rect slot = tester.getRect(
        find.byKey(const ValueKey<String>('tien-len-close-slot')),
      );
      final Rect viewport = tester.getRect(
        find.byKey(const ValueKey<String>('tien-len-game-viewport')),
      );
      final Size closeTarget = tester.getSize(
        find.byKey(const ValueKey<String>('tien-len-close-button')),
      );

      expect(slot.right, lessThanOrEqualTo(viewport.left));
      expect(closeTarget.width, greaterThanOrEqualTo(48));
      expect(closeTarget.height, greaterThanOrEqualTo(48));
      expect(find.byTooltip('Đóng game'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('tien-len-close-button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Màn hình chính'), findsOneWidget);
    },
  );

  testWidgets('game home explains virtual coin stakes before joining', (
    WidgetTester tester,
  ) async {
    final harness = _GameShellHarness(gameEnabled: true);
    addTearDown(harness.dispose);
    await _setSurface(tester, const Size(1024, 600));

    await tester.pumpWidget(harness.buildApp());
    await tester.pump();

    expect(find.text('CHỈ DÙNG XU ẢO MIỄN PHÍ'), findsOneWidget);
    expect(find.textContaining('Thắng/thua cộng trừ xu ảo'), findsOneWidget);
    expect(find.textContaining('Không nạp, rút hoặc đổi xu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('portrait and windowed game shell reserves a top bar for close', (
    WidgetTester tester,
  ) async {
    final harness = _GameShellHarness();
    addTearDown(harness.dispose);
    await _setSurface(tester, const Size(600, 900));

    await tester.pumpWidget(harness.buildApp());
    await tester.pump();

    final Rect slot = tester.getRect(
      find.byKey(const ValueKey<String>('tien-len-close-slot')),
    );
    final Rect viewport = tester.getRect(
      find.byKey(const ValueKey<String>('tien-len-game-viewport')),
    );
    final Rect closeTarget = tester.getRect(
      find.byKey(const ValueKey<String>('tien-len-close-button')),
    );

    expect(slot.bottom, lessThanOrEqualTo(viewport.top));
    expect(closeTarget.width, greaterThanOrEqualTo(48));
    expect(closeTarget.height, greaterThanOrEqualTo(48));
    expect(slot.contains(closeTarget.topLeft), isTrue);
    expect(slot.contains(closeTarget.bottomRight), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'close button stays above a realtime round result and closes the game',
    (WidgetTester tester) async {
      final harness = _GameShellHarness(gameEnabled: true);
      addTearDown(harness.dispose);
      await _setSurface(tester, const Size(1024, 600));

      await tester.pumpWidget(harness.buildApp());
      await tester.pump();

      final innerNavigator = find.descendant(
        of: find.byKey(const ValueKey<String>('tien-len-game-viewport')),
        matching: find.byType(Navigator),
      );
      expect(innerNavigator, findsOneWidget);
      final NavigatorState gameNavigator = tester.state<NavigatorState>(
        innerNavigator,
      );
      gameNavigator.push(
        MaterialPageRoute<void>(
          builder: (_) => RealtimeTableScreen(
            room: demoRooms.first,
            initialState: _roundEndedState(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('BẠN ĐÃ CHIẾN THẮNG'), findsOneWidget);
      expect(find.text('VÁN MỚI SAU'), findsNothing);
      expect(find.text('GIÂY'), findsNothing);
      expect(find.textContaining('Ván mới sau'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('tien-len-close-button')),
        findsOneWidget,
      );

      final Rect closeTarget = tester.getRect(
        find.byKey(const ValueKey<String>('tien-len-close-button')),
      );
      final Rect viewport = tester.getRect(
        find.byKey(const ValueKey<String>('tien-len-game-viewport')),
      );
      expect(closeTarget.right, lessThanOrEqualTo(viewport.left));

      await tester.tap(
        find.byKey(const ValueKey<String>('tien-len-close-button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Màn hình chính'), findsOneWidget);
    },
  );

  testWidgets(
    'active realtime route survives a shell resize and session notification',
    (WidgetTester tester) async {
      final harness = _GameShellHarness(gameEnabled: true);
      addTearDown(harness.dispose);
      await _setSurface(tester, const Size(1024, 600));

      await tester.pumpWidget(harness.buildApp());
      await tester.pump();

      final NavigatorState gameNavigator = tester.state<NavigatorState>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('tien-len-game-viewport')),
          matching: find.byType(Navigator),
        ),
      );
      gameNavigator.push(
        MaterialPageRoute<void>(
          builder: (_) => RealtimeTableScreen(
            room: demoRooms.first,
            initialState: _roundEndedState(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('BẠN ĐÃ CHIẾN THẮNG'), findsOneWidget);

      await tester.binding.setSurfaceSize(const Size(600, 900));
      (harness.sessionController as _GameEnabledSessionController)
          .emitUnrelatedSessionUpdate();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('BẠN ĐÃ CHIẾN THẮNG'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('tien-len-close-button')),
        findsOneWidget,
      );
    },
  );
}

TienLenRoomState _roundEndedState() {
  final nextRoundAt = DateTime.now().add(const Duration(seconds: 15));
  return TienLenRoomState.fromJson(<String, dynamic>{
    'roomId': 'NTRESULTCLOSE',
    'title': 'Phòng Thường',
    'phase': 'round-ended',
    'baseBet': 100,
    'maxPlayers': 4,
    'playerCount': 2,
    'humanCount': 1,
    'botCount': 1,
    'roundNumber': 1,
    'roundId': 'round-result-1',
    'settlementStatus': 'idle',
    'viewerId': '7',
    'hostId': '7',
    'currentTurnPlayerId': '',
    'lastActorId': '7',
    'firstPlayPending': false,
    'coveredTableCardCount': 0,
    'tableCards': const <dynamic>[],
    'lastPlay': null,
    'passedPlayerIds': const <dynamic>[],
    'finishedOrder': const <dynamic>['7', 'seat-1'],
    'turnLogs': const <dynamic>['Người chơi về nhất'],
    'nextRoundAllowedAt': nextRoundAt.toIso8601String(),
    'players': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': '7',
        'seatIndex': 0,
        'name': 'Người chơi',
        'isSystemOpponent': false,
        'connected': true,
        'ready': true,
        'coins': 6090,
        'handCount': 0,
        'hand': const <dynamic>[],
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
        'handCount': 5,
        'hand': const <dynamic>[],
        'finished': true,
      },
    ],
    'moneyEvents': const <Map<String, dynamic>>[
      <String, dynamic>{
        'fromId': 'seat-1',
        'toId': '7',
        'gross': 100,
        'fee': 10,
        'net': 90,
      },
    ],
  });
}

Future<void> _setSurface(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

class _GameShellHarness {
  _GameShellHarness({this.gameEnabled = false})
    : storageService = StorageService(),
      socketService = _GameShellSocketService() {
    sessionController = gameEnabled
        ? _GameEnabledSessionController(
            apiService: ChatApiService(),
            storageService: storageService,
            deviceIdentityService: DeviceIdentityService(storageService),
            pushNotificationService: const PushNotificationService(),
          )
        : SessionController(
            apiService: ChatApiService(),
            storageService: storageService,
            deviceIdentityService: DeviceIdentityService(storageService),
            pushNotificationService: const PushNotificationService(),
          );
  }

  final bool gameEnabled;
  final StorageService storageService;
  final _GameShellSocketService socketService;
  late final SessionController sessionController;

  Widget buildApp() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionController>.value(
          value: sessionController,
        ),
        Provider<ChatSocketService>.value(value: socketService),
      ],
      child: MaterialApp(
        initialRoute: '/game',
        routes: <String, WidgetBuilder>{
          '/': (_) => const Scaffold(body: Text('Màn hình chính')),
          '/game': (_) => const TienLenGameScreen(),
        },
      ),
    );
  }

  Future<void> dispose() async {
    sessionController.dispose();
    await socketService.dispose();
  }
}

class _GameShellSocketService extends ChatSocketService {
  @override
  Future<void> leaveTienLenRoom() async {}
}

class _GameEnabledSessionController extends SessionController {
  _GameEnabledSessionController({
    required super.apiService,
    required super.storageService,
    required super.deviceIdentityService,
    required super.pushNotificationService,
  });

  @override
  bool get isLoggedIn => true;

  @override
  bool get cardGameFeatureEnabled => true;

  @override
  Future<int> claimGameDailyCoin() async => 0;

  @override
  Future<SessionUser?> refreshCurrentUser({bool notify = true}) async => null;

  void emitUnrelatedSessionUpdate() => notifyListeners();
}
