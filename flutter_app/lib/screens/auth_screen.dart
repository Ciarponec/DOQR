import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  String? error;

  Future<void> signInOrSignUp() async {
    setState(() { loading = true; error = null; });
    try {
      final client = Supabase.instance.client;
      await client.auth.signInWithPassword(email: email.text.trim(), password: password.text);
    } catch (_) {
      try {
        await Supabase.instance.client.auth.signUp(email: email.text.trim(), password: password.text);
      } catch (e) {
        error = e.toString();
      }
    }
    if (mounted) {
      setState(() => loading = false);
      if (Supabase.instance.client.auth.currentSession != null) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DOQR Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 12),
            TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
            const SizedBox(height: 16),
            FilledButton(onPressed: loading ? null : signInOrSignUp, child: Text(loading ? 'Bekleyin...' : 'Giris / Kayit')),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }
}
