import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../controllers/chat_controller.dart';
import '../controllers/session_controller.dart';
import '../controllers/social_hub_controller.dart';
import '../core/constants/app_constants.dart';
import '../core/localization/app_localizer.dart';
import '../core/theme/app_theme.dart';
import '../screens/login_screen.dart';
import '../screens/social_hub_shell_screen.dart';
import '../services/chat_api_service.dart';
import '../services/chat_socket_service.dart';
import '../services/device_identity_service.dart';
import '../services/push_notification_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_logo.dart';

class ChatMobileApp extends StatefulWidget {
  const ChatMobileApp({super.key});

  @override
  State<ChatMobileApp> createState() => _ChatMobileAppState();
}

class _ChatMobileAppState extends State<ChatMobileApp>
    with WidgetsBindingObserver {
  late final StorageService _storageService;
  late final ChatApiService _apiService;
  late final ChatSocketService _socketService;
  late final DeviceIdentityService _deviceIdentityService;
  late final PushNotificationService _pushNotificationService;
  late final AppLocaleController _localeController;
  late final SessionController _sessionController;
  late final ChatController _chatController;
  late final SocialHubController _socialHubController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    _storageService = StorageService();
    _apiService = ChatApiService();
    _socketService = ChatSocketService();
    _deviceIdentityService = DeviceIdentityService(_storageService);
    _pushNotificationService = const PushNotificationService();
    _localeController = AppLocaleController(_storageService);
    _sessionController = SessionController(
      apiService: _apiService,
      storageService: _storageService,
      deviceIdentityService: _deviceIdentityService,
      pushNotificationService: _pushNotificationService,
    )..bootstrap();
    _chatController = ChatController(
      sessionController: _sessionController,
      apiService: _apiService,
      socketService: _socketService,
    );
    _socialHubController = SocialHubController(
      sessionController: _sessionController,
      apiService: _apiService,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_sessionController.isLoggedIn) {
      _sessionController.updatePresence(
        state == AppLifecycleState.resumed ||
            state == AppLifecycleState.inactive,
      );
      if (state == AppLifecycleState.resumed) {
        _chatController.syncOfflineNotifications();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _chatController.dispose();
    _socialHubController.dispose();
    _sessionController.dispose();
    _socketService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<StorageService>.value(value: _storageService),
        Provider<ChatApiService>.value(value: _apiService),
        Provider<ChatSocketService>.value(value: _socketService),
        Provider<DeviceIdentityService>.value(value: _deviceIdentityService),
        Provider<PushNotificationService>.value(
          value: _pushNotificationService,
        ),
        ChangeNotifierProvider<AppLocaleController>.value(
          value: _localeController,
        ),
        ChangeNotifierProvider<SessionController>.value(
          value: _sessionController,
        ),
        ChangeNotifierProvider<ChatController>.value(value: _chatController),
        ChangeNotifierProvider<SocialHubController>.value(
          value: _socialHubController,
        ),
      ],
      child: Consumer<AppLocaleController>(
        builder: (context, localeController, _) => MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          locale: localeController.locale,
          supportedLocales: const [Locale('vi'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Consumer<SessionController>(
            builder: (context, session, _) {
              if (session.bootstrapping) {
                return const _SplashScreen();
              }
              if (!session.isLoggedIn) {
                return const LoginScreen();
              }
              return const SocialHubShellScreen();
            },
          ),
        ),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF6F9FF), Color(0xFFEAF2FF)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(size: 94),
              const SizedBox(height: 22),
              const CircularProgressIndicator(),
              const SizedBox(height: 18),
              Text(
                context.tr('Launching {appName}...', {
                  'appName': AppConstants.appName,
                }),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF355077),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
