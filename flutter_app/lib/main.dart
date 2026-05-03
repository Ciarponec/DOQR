import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';
import 'screens/auth_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/home_screen.dart';
import 'screens/qr_ring_screen.dart';
import 'screens/qr_token_manage_screen.dart';
import 'screens/share_accept_screen.dart';
import 'screens/share_create_screen.dart';
import 'screens/visitor_chat_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validate();
  await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
  runApp(const ProviderScope(child: DoqrApp()));
}

class DoqrApp extends StatelessWidget {
  const DoqrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DOQR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      routes: {
        '/': (_) => const AuthGate(),
        '/home': (_) => const HomeScreen(),
        '/qr-ring': (_) => const QrRingScreen(),
        '/share-accept': (_) => const ShareAcceptScreen(),
        '/share-create': (_) => const ShareCreateScreen(),
        '/qr-token-manage': (_) => const QrTokenManageScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/chat') {
          final ringId = settings.arguments as String;
          return MaterialPageRoute(builder: (_) => ChatScreen(ringId: ringId));
        }
        if (settings.name == '/visitor-chat') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(builder: (_) => VisitorChatScreen(ringId: args['ring_id'] as String, visitorSessionToken: args['visitor_session_token'] as String));
        }
        return null;
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return const AuthScreen();
    return const HomeScreen();
  }
}
