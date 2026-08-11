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
  bool createMode = false;
  String? error;
  String? info;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final create = createMode;
    final mail = email.text.trim();
    final secret = password.text;
    if (mail.isEmpty || secret.isEmpty) {
      return setState(() => error = context.tr(
          'E-posta ve şifre gerekli.', 'Email and password are required.'));
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(mail)) {
      return setState(() => error = context.tr(
          'Geçerli bir e-posta adresi gir.', 'Enter a valid email address.'));
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
                    const SizedBox(height: 18),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          selected: !createMode,
                          label: Text(context.tr('Giriş yap', 'Sign in')),
                          onSelected: loading
                              ? null
                              : (_) => setState(() {
                                    createMode = false;
                                    error = null;
                                    info = null;
                                  }),
                        ),
                        ChoiceChip(
                          selected: createMode,
                          label: Text(
                              context.tr('Hesap oluştur', 'Create account')),
                          onSelected: loading
                              ? null
                              : (_) => setState(() {
                                    createMode = true;
                                    error = null;
                                    info = null;
                                  }),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.white),
                          onPressed: loading
                              ? null
                              : () => Navigator.of(context).pushNamed('/demo'),
                          icon: const Icon(Icons.play_circle_outline_rounded),
                          label: Text(context.tr(
                              'Kayıt olmadan dene', 'Try without an account')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevCard(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                              createMode
                                  ? context.tr('Ücretsiz hesap oluştur',
                                      'Create a free account')
                                  : context.tr('Host hesabına giriş yap',
                                      'Sign in to your host account'),
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 5),
                          Text(
                              context.tr(
                                  createMode
                                      ? 'Dijital zilini oluştur, ilk 3 gün Pro özelliklerini dene.'
                                      : 'Dijital zilini ve gelen ziyaretçileri yönet.',
                                  createMode
                                      ? 'Create your doorbell and try Pro features for the first 3 days.'
                                      : 'Manage your doorbell and incoming visitors.'),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.muted)),
                          const SizedBox(height: 20),
                          AutofillGroup(
                            child: Column(
                              children: [
                                TextField(
                                  controller: email,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.email],
                                  decoration: InputDecoration(
                                      labelText: context.tr('E-posta', 'Email'),
                                      prefixIcon: const Icon(
                                          Icons.alternate_email_rounded)),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: password,
                                  obscureText: obscure,
                                  autofillHints: [
                                    createMode
                                        ? AutofillHints.newPassword
                                        : AutofillHints.password,
                                  ],
                                  onSubmitted: (_) =>
                                      loading ? null : _submit(),
                                  decoration: InputDecoration(
                                    labelText: context.tr('Şifre', 'Password'),
                                    helperText: createMode
                                        ? context.tr('En az 8 karakter.',
                                            'At least 8 characters.')
                                        : null,
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
                              ],
                            ),
                          ),
                          if (info != null)
                            _Message(text: info!, color: AppColors.success),
                          if (error != null)
                            _Message(text: error!, color: AppColors.danger),
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed: loading ? null : _submit,
                            child: loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5, color: Colors.white))
                                : Text(createMode
                                    ? context.tr(
                                        'Hesabı oluştur', 'Create account')
                                    : context.tr('Giriş yap', 'Sign in')),
                          ),
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
