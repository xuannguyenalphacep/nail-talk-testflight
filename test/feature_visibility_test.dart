import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_hub_flutter/src/controllers/chat_controller.dart';
import 'package:social_hub_flutter/src/controllers/session_controller.dart';
import 'package:social_hub_flutter/src/controllers/social_hub_controller.dart';
import 'package:social_hub_flutter/src/core/localization/app_localizer.dart';
import 'package:social_hub_flutter/src/models/movie_item.dart';
import 'package:social_hub_flutter/src/screens/dashboard_screen.dart';
import 'package:social_hub_flutter/src/screens/more_menu_screen.dart';
import 'package:social_hub_flutter/src/screens/social_hub_shell_screen.dart';
import 'package:social_hub_flutter/src/services/chat_api_service.dart';
import 'package:social_hub_flutter/src/services/chat_socket_service.dart';
import 'package:social_hub_flutter/src/services/device_identity_service.dart';
import 'package:social_hub_flutter/src/services/push_notification_service.dart';
import 'package:social_hub_flutter/src/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  testWidgets('disabled features are omitted from home, menu, and navigation', (
    tester,
  ) async {
    await _setLargeSurface(tester);
    final harness = _FeatureHarness(videoEnabled: false, gameEnabled: false);
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.wrap(_dashboard()));
    await tester.pump();
    expect(find.byKey(const ValueKey('home-feature-card-video')), findsNothing);
    expect(find.byKey(const ValueKey('home-feature-card-game')), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'review only video');
    await tester.pump();
    expect(find.text('Review Only Video'), findsNothing);

    await tester.pumpWidget(harness.wrap(_moreMenu()));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('more-menu-feature-Videos')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('more-menu-feature-Game bài')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('more-menu-utility-Feedback')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('more-menu-utility-Privacy policy')),
      findsOneWidget,
    );

    await tester.pumpWidget(
      harness.wrap(const SocialHubShellScreen(), includeControllers: true),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('bottom-navigation-video')), findsNothing);
  });

  testWidgets('enabled features appear in home, menu, and navigation', (
    tester,
  ) async {
    await _setLargeSurface(tester);
    final harness = _FeatureHarness(videoEnabled: true, gameEnabled: true);
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.wrap(_dashboard()));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('home-feature-card-video')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-feature-card-game')),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField).first, 'review only video');
    await tester.pump();
    expect(find.text('Review Only Video'), findsOneWidget);

    await tester.pumpWidget(harness.wrap(_moreMenu()));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('more-menu-feature-Videos')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('more-menu-feature-Game bài')),
      findsOneWidget,
    );

    await tester.pumpWidget(
      harness.wrap(const SocialHubShellScreen(), includeControllers: true),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('bottom-navigation-video')),
      findsOneWidget,
    );
  });
}

Future<void> _setLargeSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1080, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

DashboardScreen _dashboard() {
  return DashboardScreen(
    onNavigate: (_) {},
    onOpenJobs: (_) async {},
    onOpenHousing: (_) async {},
    onOpenServices: () async {},
    onOpenSaved: () {},
  );
}

MoreMenuScreen _moreMenu() {
  return MoreMenuScreen(
    onNavigate: (_) {},
    onOpenJobs: (_) async {},
    onOpenHousing: (_) async {},
    onOpenServices: () async {},
    onOpenSaved: () {},
  );
}

class _FeatureHarness {
  _FeatureHarness({required bool videoEnabled, required bool gameEnabled})
    : storage = StorageService(),
      api = ChatApiService(),
      socket = ChatSocketService() {
    session = _FeatureSessionController(
      videoEnabled: videoEnabled,
      gameEnabled: gameEnabled,
      apiService: api,
      storageService: storage,
    );
    locale = AppLocaleController(storage);
    chat = ChatController(
      sessionController: session,
      apiService: api,
      socketService: socket,
    );
    social = _FeatureSocialHubController(
      sessionController: session,
      apiService: api,
    );
  }

  final StorageService storage;
  final ChatApiService api;
  final ChatSocketService socket;
  late final _FeatureSessionController session;
  late final AppLocaleController locale;
  late final ChatController chat;
  late final SocialHubController social;

  Widget wrap(Widget child, {bool includeControllers = true}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppLocaleController>.value(value: locale),
        ChangeNotifierProvider<SessionController>.value(value: session),
        if (includeControllers) ...[
          ChangeNotifierProvider<ChatController>.value(value: chat),
          ChangeNotifierProvider<SocialHubController>.value(value: social),
        ],
      ],
      child: MaterialApp(home: child),
    );
  }

  void dispose() {
    social.dispose();
    chat.dispose();
    session.dispose();
    locale.dispose();
    socket.dispose();
  }
}

class _FeatureSocialHubController extends SocialHubController {
  _FeatureSocialHubController({
    required super.sessionController,
    required super.apiService,
  });

  @override
  List<MovieItem> get movies => <MovieItem>[
    MovieItem.fromJson(<String, dynamic>{
      'id': 9001,
      'uuid': 'review-only-video',
      'title': 'Review Only Video',
      'slug': 'review-only-video',
      'summary': 'Feature visibility search fixture',
      'source_type': 'youtube',
      'youtube_video_id': 'YE7VzlLtp-4',
      'access_type': 'free',
      'is_published': true,
    }),
  ];
}

class _FeatureSessionController extends SessionController {
  _FeatureSessionController({
    required this.videoEnabled,
    required this.gameEnabled,
    required super.apiService,
    required super.storageService,
  }) : super(
         deviceIdentityService: DeviceIdentityService(storageService),
         pushNotificationService: const PushNotificationService(),
       );

  final bool videoEnabled;
  final bool gameEnabled;

  @override
  bool get videoFeatureEnabled => videoEnabled;

  @override
  bool get hideVideoFeature => !videoEnabled;

  @override
  bool get cardGameFeatureEnabled => gameEnabled;

  @override
  Future<void> refreshFeatureFlags({bool notify = true}) async {}
}
