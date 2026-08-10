import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_language.dart';
import '../ui/app_theme.dart';
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
  bool obscure = true;
  String? error;
  String? info;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool create}) async {
    final mail = email.text.trim();
    final secret = password.text;
    if (mail.isEmpty || secret.isEmpty) {
      return setState(() => error = context.tr(
          'E-posta ve şifre gerekli.', 'Email and password are required.'));
    }
    if (create && secret.length < 8) {
      return setState(() => error = context.tr('Şifre en az 8 karakter olmalı.',
          'Password must be at least 8 characters.'));
    }
    setState(() {
      loading = true;
      error = null;
      info = null;
    });
    try {
      if (create) {
        final result = await Supabase.instance.client.auth
            .signUp(email: mail, password: secret);
        if (result.session == null) {
          if (mounted) {
            setState(() => info = context.tr(
                'Hesap oluşturuldu. E-postandaki doğrulama bağlantısını aç.',
                'Account created. Open the verification link in your email.'));
          }
          return;
        }
      } else {
        await Supabase.instance.client.auth
            .signInWithPassword(email: mail, password: secret);
      }
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
      }
    } on AuthException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = context.tr(
            'Şu anda giriş yapılamıyor. Lütfen tekrar dene.',
            'Unable to sign in right now. Please try again.'));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0B1230), Color(0xFF172554), Color(0xFF10213E)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 34, 22, 24),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset('assets/doqr_icon.png',
                              width: 82, height: 82, fit: BoxFit.cover),
                        ),
                        const LanguagePickerButton(
                            foregroundColor: Colors.white),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      context.tr('Kapınız, tek taramayla ulaşılabilir.',
                          'Your door is one scan away.'),
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.tr(
                          'Ziyaretçiler uygulama kurmadan QR’ı tarar. Siz anında haberdar olur, güvenle yanıt verirsiniz.',
                          'Visitors scan the QR code without installing an app. You are notified instantly and respond securely.'),
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: const Color(0xFFBFCBF1)),
                    ),
                    const SizedBox(height: 32),
                    ElevCard(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(context.tr('Host hesabı', 'Host account'),
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 5),
                          Text(
                              context.tr(
                                  'Dijital zilini yönetmek için devam et.',
                                  'Continue to manage your digital doorbell.'),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.muted)),
                          const SizedBox(height: 20),
                          TextField(
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: InputDecoration(
                                labelText: context.tr('E-posta', 'Email'),
                                prefixIcon:
                                    const Icon(Icons.alternate_email_rounded)),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: password,
                            obscureText: obscure,
                            autofillHints: const [AutofillHints.password],
                            onSubmitted: (_) =>
                                loading ? null : _submit(create: false),
                            decoration: InputDecoration(
                              labelText: context.tr('Şifre', 'Password'),
                              prefixIcon:
                                  const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => obscure = !obscure),
                                icon: Icon(obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                              ),
                            ),
                          ),
                          if (info != null)
                            _Message(text: info!, color: AppColors.success),
                          if (error != null)
                            _Message(text: error!, color: AppColors.danger),
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed:
                                loading ? null : () => _submit(create: false),
                            child: loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5, color: Colors.white))
                                : Text(context.tr('Giriş yap', 'Sign in')),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                              onPressed:
                                  loading ? null : () => _submit(create: true),
                              child: Text(context.tr('Ücretsiz hesap oluştur',
                                  'Create a free account'))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shield_outlined,
                            size: 17, color: Color(0xFF9FB0E6)),
                        const SizedBox(width: 7),
                        Text(
                            context.tr('Güvenlik odaklı dijital zil',
                                'Security-first digital doorbell'),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: const Color(0xFF9FB0E6))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _Message extends StatelessWidget {
  final String text;
  final Color color;
  const _Message({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(14)),
        child: Text(text,
            style: TextStyle(color: color, fontWeight: FontWeight.w700)),
      );
}
