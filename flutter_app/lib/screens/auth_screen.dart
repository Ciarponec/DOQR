import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/app_shell.dart';

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
      if (mounted) Navigator.of(context).pushReplacementNamed('/home');
    } on AuthException catch (e) {
      setState(() => error = e.message);
    } catch (e) {
      setState(() => error = e.toString());
    }
    if (mounted) setState(() => loading = false);
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
        if (mounted) Navigator.of(context).pushReplacementNamed('/home');
      } else {
        setState(() => info = 'Kayit tamamlandi. Email dogrulamasi yapip giris yapin.');
      }
    } on AuthException catch (e) {
      setState(() => error = e.message);
    } catch (e) {
      setState(() => error = e.toString());
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'DOQR',
      child: ListView(
        children: [
          const SizedBox(height: 24),
          const Text('Akilli QR Kapi Zili', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Giris yapin veya hizli kayit olun', style: TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 18),
          const ElevCard(
            child: SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          ElevCard(
            child: Column(
              children: [
                TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 10),
                TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Sifre')),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: FilledButton(onPressed: loading ? null : signIn, child: Text(loading ? 'Bekleyin...' : 'Giris Yap'))),
                    const SizedBox(width: 10),
                    Expanded(child: OutlinedButton(onPressed: loading ? null : signUp, child: const Text('Kayit Ol'))),
                  ],
                ),
                if (info != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(info!, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
