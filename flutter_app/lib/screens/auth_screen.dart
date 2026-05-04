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
  String? info;

  Future<void> signIn() async {
    final e = email.text.trim();
    final p = password.text;
    if (e.isEmpty || p.isEmpty) {
      setState(() => error = 'Email ve sifre zorunlu.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
      info = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(email: e, password: p);
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } on AuthException catch (e) {
      setState(() => error = e.message);
    } catch (e) {
      setState(() => error = e.toString());
    }
    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> signUp() async {
    final e = email.text.trim();
    final p = password.text;
    if (e.isEmpty || p.isEmpty) {
      setState(() => error = 'Email ve sifre zorunlu.');
      return;
    }
    if (p.length < 6) {
      setState(() => error = 'Sifre en az 6 karakter olmali.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
      info = null;
    });
    try {
      final res = await Supabase.instance.client.auth.signUp(email: e, password: p);
      final hasSession = res.session != null || Supabase.instance.client.auth.currentSession != null;
      if (hasSession) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        setState(() => info = 'Kayit alindi. Lutfen email kutundan dogrulama yapip giris yap.');
      }
    } on AuthException catch (e) {
      setState(() => error = e.message);
    } catch (e) {
      setState(() => error = e.toString());
    }
    if (mounted) {
      setState(() => loading = false);
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
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: loading ? null : signIn,
                    child: Text(loading ? 'Bekleyin...' : 'Giris Yap'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: loading ? null : signUp,
                    child: const Text('Kayit Ol'),
                  ),
                ),
              ],
            ),
            if (info != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(info!, style: const TextStyle(color: Colors.green)),
              ),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }
}
