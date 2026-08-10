import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';
import 'l10n/app_language.dart';
import 'screens/auth_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/doors_manage_screen.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'services/store_purchase_service.dart';
import 'ui/app_theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validate();
  await Supabase.initialize(
      url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseKey);
  runApp(const ProviderScope(child: DoqrApp()));
  unawaited(StorePurchaseService.instance.initialize());
  unawaited(NotificationService.instance.initialize());
}

class DoqrApp extends StatefulWidget {
  const DoqrApp({super.key});

  @override
  State<DoqrApp> createState() => _DoqrAppState();
}

class _DoqrAppState extends State<DoqrApp> {
  late final AppLanguageController _languageController;

  @override
  void initState() {
    super.initState();
    _languageController = AppLanguageController();
    unawaited(_languageController.load());
    NotificationService.instance.attachNavigator(navigatorKey);
  }

  @override
  void dispose() {
    _languageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppLanguageScope(
        controller: _languageController,
        child: AnimatedBuilder(
          animation: _languageController,
          builder: (context, _) => MaterialApp(
            navigatorKey: navigatorKey,
            title: 'DOQR',
            debugShowCheckedModeBanner: false,
            theme: buildDoqrTheme(),
            locale: _languageController.locale,
            supportedLocales: const [Locale('tr'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routes: {
              '/': (_) => const AuthGate(),
              '/home': (_) => const HomeScreen(),
              '/doors': (_) => const DoorsManageScreen(),
            },
            onGenerateRoute: (settings) {
              if (settings.name == '/ring') {
                return MaterialPageRoute(
                    builder: (_) => RingSessionScreen(
                        ringId: settings.arguments as String));
              }
              return null;
            },
          ),
        ),
      );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (Supabase.instance.client.auth.currentSession == null) {
      return const AuthScreen();
    }
    return const HomeScreen();
  }
}
