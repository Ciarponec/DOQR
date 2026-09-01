import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_language.dart';
import '../app_config.dart';
import '../ui/app_theme.dart';
import '../services/user_error.dart';
import '../widgets/app_shell.dart';

abstract class AuthGateway {
  Stream<AuthException> get authErrors;

  Future<bool> signUp({required String email, required String password});

  Future<void> signIn({required String email, required String password});

  Future<void> resendSignupConfirmation({required String email});

  Future<void> sendPasswordReset({required String email});

  Future<void> savePendingConfirmationEmail(String email);

  Future<String?> loadPendingConfirmationEmail();

  Future<void> clearPendingConfirmationEmail();
}

class SupabaseAuthGateway implements AuthGateway {
  const SupabaseAuthGateway();

  static const _pendingEmailKey = 'pending_confirmation_email';

  @override
  Stream<AuthException> get authErrors {
    late final StreamController<AuthException> controller;
    StreamSubscription<AuthState>? subscription;
    controller = StreamController<AuthException>(
      onListen: () {
        subscription = Supabase.instance.client.auth.onAuthStateChange.listen(
          (_) {},
          onError: (Object exception, StackTrace stackTrace) {
            if (exception is AuthException) controller.add(exception);
          },
        );
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<bool> signUp({required String email, required String password}) async {
    final result = await Supabase.instance.client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: kIsWeb ? null : AppConfig.authRedirectUrl,
    );
    return result.session != null;
  }

  @override
  Future<void> signIn({required String email, required String password}) =>
      Supabase.instance.client.auth
          .signInWithPassword(email: email, password: password);

  @override
  Future<void> resendSignupConfirmation({required String email}) =>
      Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: kIsWeb ? null : AppConfig.authRedirectUrl,
      );

  @override
  Future<void> sendPasswordReset({required String email}) =>
      Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb ? Uri.base.toString() : AppConfig.authRedirectUrl,
      );

  @override
  Future<void> savePendingConfirmationEmail(String email) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_pendingEmailKey, email);
  }

  @override
  Future<String?> loadPendingConfirmationEmail() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_pendingEmailKey);
  }

  @override
  Future<void> clearPendingConfirmationEmail() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_pendingEmailKey);
  }
}

class AuthScreen extends StatefulWidget {
  final AuthGateway? authGateway;
  final Duration resendCooldown;

  const AuthScreen({
    super.key,
    this.authGateway,
    this.resendCooldown = const Duration(seconds: 60),
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  bool obscure = true;
  bool createMode = false;
  bool resending = false;
  bool resettingPassword = false;
  int resendSeconds = 0;
  String? error;
  String? info;
  String? pendingConfirmationEmail;
  Timer? resendTimer;
  StreamSubscription<AuthException>? authErrorSubscription;
  late final AuthGateway authGateway;

  @override
  void initState() {
    super.initState();
    authGateway = widget.authGateway ?? const SupabaseAuthGateway();
    authErrorSubscription = authGateway.authErrors.listen(_handleAuthError);
  }

  @override
  void dispose() {
    resendTimer?.cancel();
    authErrorSubscription?.cancel();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _handleAuthError(AuthException exception) async {
    final message = exception.message.toLowerCase();
    final expired = exception.code == 'otp_expired' ||
        exception.code == 'access_denied' &&
            (message.contains('expired') || message.contains('invalid'));
    if (!expired) return;

    final savedEmail = await authGateway.loadPendingConfirmationEmail();
    if (!mounted) return;
    if (savedEmail != null && savedEmail.isNotEmpty) {
      email.text = savedEmail;
      _showResendForUnconfirmedAccount(
        savedEmail,
        message: context.tr(
          'Doğrulama bağlantısının süresi geçmiş. Yeni ve 60 dakika geçerli bir bağlantı almak için aşağıdaki düğmeye dokun.',
          'The verification link has expired. Tap the button below to get a new link valid for 60 minutes.',
        ),
      );
    } else {
      setState(() {
        error = context.tr(
          'Doğrulama bağlantısının süresi geçmiş. Kayıt olurken kullandığın e-posta adresini yukarıya yazıp yeniden dene.',
          'The verification link has expired. Enter the email address you used to sign up above and try again.',
        );
      });
    }
  }

  void _startResendCooldown(String mail, String message) {
    resendTimer?.cancel();
    final seconds = widget.resendCooldown.inSeconds.clamp(1, 3600);
    setState(() {
      pendingConfirmationEmail = mail;
      resendSeconds = seconds;
      resending = false;
      error = null;
      info = message;
    });
    resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (resendSeconds <= 1) {
        timer.cancel();
        setState(() => resendSeconds = 0);
      } else {
        setState(() => resendSeconds--);
      }
    });
  }

  void _showResendForUnconfirmedAccount(String mail, {String? message}) {
    resendTimer?.cancel();
    setState(() {
      pendingConfirmationEmail = mail;
      resendSeconds = 0;
      resending = false;
      error = null;
      info = message ??
          context.tr(
            'E-posta adresin henüz doğrulanmamış. Yeni bir bağlantı isteyebilirsin; bağlantı 60 dakika geçerlidir.',
            'Your email address is not verified yet. You can request a new link; the link is valid for 60 minutes.',
          );
    });
  }

  Future<void> _resendConfirmation() async {
    final mail = pendingConfirmationEmail;
    if (mail == null || resendSeconds > 0 || resending) return;
    setState(() {
      resending = true;
      error = null;
    });
    try {
      await authGateway.resendSignupConfirmation(email: mail);
      await authGateway.savePendingConfirmationEmail(mail);
      if (mounted) {
        _startResendCooldown(
          mail,
          context.tr(
            'Doğrulama e-postası yeniden gönderildi. Bağlantı 60 dakika geçerlidir; gelen kutunu ve spam klasörünü kontrol et ve yalnızca en yeni e-postadaki bağlantıyı kullan.',
            'Verification email sent again. The link is valid for 60 minutes; check your inbox and spam folder and use only the link in the newest email.',
          ),
        );
      }
    } on AuthException catch (exception) {
      if (!mounted) return;
      final rateLimited = exception.statusCode == '429' ||
          exception.code == 'over_email_send_rate_limit';
      final emailServiceFailed = exception.code == 'unexpected_failure' ||
          exception.message
              .toLowerCase()
              .contains('error sending confirmation email');
      if (rateLimited) {
        _startResendCooldown(
          mail,
          context.tr(
            'Yeni bir doğrulama e-postası istemeden önce 60 saniye bekle.',
            'Wait 60 seconds before requesting another verification email.',
          ),
        );
      } else if (emailServiceFailed) {
        setState(() => error = context.tr(
              'Doğrulama e-postası şu anda gönderilemedi. Lütfen biraz sonra tekrar dene.',
              'The verification email could not be sent right now. Please try again shortly.',
            ));
      } else {
        setState(() => error = userErrorMessage(exception));
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = context.tr(
            'Doğrulama e-postası gönderilemedi. Lütfen tekrar dene.',
            'Unable to send the verification email. Please try again.'));
      }
    } finally {
      if (mounted) setState(() => resending = false);
    }
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
        final hasSession =
            await authGateway.signUp(email: mail, password: secret);
        if (!hasSession) {
          await authGateway.savePendingConfirmationEmail(mail);
          if (mounted) {
            _startResendCooldown(
              mail,
              context.tr(
                'Doğrulama bağlantısını $mail adresine gönderdik. Bağlantı 60 dakika geçerlidir; gelen kutunu ve spam klasörünü kontrol et.',
                'We sent a verification link to $mail. The link is valid for 60 minutes; check your inbox and spam folder.',
                'Ссылка для подтверждения отправлена на $mail и действует 60 минут. Проверьте входящие и папку «Спам».',
              ),
            );
          }
          return;
        }
      } else {
        await authGateway.signIn(email: mail, password: secret);
      }
      await authGateway.clearPendingConfirmationEmail();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
      }
    } on AuthException catch (exception) {
      if (!mounted) return;
      if (!create && exception.code == 'email_not_confirmed') {
        await authGateway.savePendingConfirmationEmail(mail);
        _showResendForUnconfirmedAccount(mail);
      } else {
        setState(() => error = userErrorMessage(exception));
      }
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

  Future<void> _requestPasswordReset() async {
    final mail = email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(mail)) {
      return setState(() => error = context.tr(
          'Önce geçerli e-posta adresinizi girin.',
          'Enter your valid email address first.',
          'Сначала введите действительный адрес электронной почты.'));
    }
    setState(() {
      resettingPassword = true;
      error = null;
      info = null;
    });
    try {
      await authGateway.sendPasswordReset(email: mail);
      if (mounted) {
        setState(() => info = context.tr(
            'Parola sıfırlama bağlantısını $mail adresine gönderdik. Gelen kutunuzu ve spam klasörünü kontrol edin.',
            'We sent a password reset link to $mail. Check your inbox and spam folder.',
            'Ссылка для сброса пароля отправлена на $mail. Проверьте входящие и папку «Спам».'));
      }
    } on AuthException catch (exception) {
      if (mounted) setState(() => error = userErrorMessage(exception));
    } catch (exception) {
      if (mounted) setState(() => error = userErrorMessage(exception));
    } finally {
      if (mounted) setState(() => resettingPassword = false);
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
                                  : context.tr(
                                      'Kapı yöneticisi hesabına giriş yap',
                                      'Sign in to your door manager account',
                                      'Войдите в учётную запись управляющего дверью'),
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 5),
                          Text(
                              context.tr(
                                  createMode
                                      ? 'Dijital zilini oluştur, ilk 3 gün Pro özelliklerini dene.'
                                      : 'Dijital zilini ve gelen ziyaretçileri yönet.',
                                  createMode
                                      ? 'Create your doorbell and try Pro features for the first 3 days.'
                                      : 'Manage your doorbell and incoming visitors.',
                                  createMode
                                      ? 'Создайте дверной звонок и пользуйтесь Pro первые 3 дня.'
                                      : 'Управляйте дверным звонком и входящими посетителями.'),
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
                                if (!createMode)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: loading || resettingPassword
                                          ? null
                                          : _requestPasswordReset,
                                      child: resettingPassword
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2),
                                            )
                                          : Text(context.tr(
                                              'Şifremi unuttum',
                                              'Forgot password',
                                              'Забыли пароль?')),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (info != null)
                            _Message(text: info!, color: AppColors.success),
                          if (error != null)
                            _Message(text: error!, color: AppColors.danger),
                          if (pendingConfirmationEmail != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: TextButton.icon(
                                onPressed:
                                    loading || resending || resendSeconds > 0
                                        ? null
                                        : _resendConfirmation,
                                icon: resending
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(
                                        Icons.mark_email_unread_outlined),
                                label: Text(resendSeconds > 0
                                    ? context.tr(
                                        '$resendSeconds sn sonra yeniden gönder',
                                        'Resend in $resendSeconds sec',
                                        'Повторить через $resendSeconds сек.')
                                    : context.tr(
                                        'Doğrulama e-postasını yeniden gönder',
                                        'Resend verification email')),
                              ),
                            ),
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
                        Flexible(
                          child: Text(
                              context.tr('Güvenlik odaklı dijital zil',
                                  'Security-first digital doorbell'),
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: const Color(0xFF9FB0E6))),
                        ),
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

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool obscure = true;
  bool loading = false;
  String? error;

  @override
  void dispose() {
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (password.text.length < 8) {
      return setState(() => error = context.tr(
          'Yeni şifre en az 8 karakter olmalı.',
          'The new password must be at least 8 characters.',
          'Новый пароль должен содержать не менее 8 символов.'));
    }
    if (password.text != confirmation.text) {
      return setState(() => error = context.tr('Şifreler eşleşmiyor.',
          'The passwords do not match.', 'Пароли не совпадают.'));
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password.text),
      );
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
      }
    } catch (exception) {
      if (mounted) setState(() => error = userErrorMessage(exception));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 36),
                  const SoftIcon(Icons.lock_reset_rounded, size: 72),
                  const SizedBox(height: 22),
                  Text(
                    context.tr('Yeni şifre belirleyin', 'Set a new password',
                        'Задайте новый пароль'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                        'Hesabınızı korumak için başka yerde kullanmadığınız güçlü bir şifre seçin.',
                        'Choose a strong password that you do not use elsewhere.',
                        'Выберите надёжный пароль, который вы не используете в других сервисах.'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: password,
                    obscureText: obscure,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: context.tr(
                          'Yeni şifre', 'New password', 'Новый пароль'),
                      helperText: context.tr('En az 8 karakter.',
                          'At least 8 characters.', 'Не менее 8 символов.'),
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => obscure = !obscure),
                        icon: Icon(obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmation,
                    obscureText: obscure,
                    onSubmitted: (_) => loading ? null : _save(),
                    decoration: InputDecoration(
                      labelText: context.tr('Yeni şifreyi doğrulayın',
                          'Confirm new password', 'Повторите новый пароль'),
                      prefixIcon: const Icon(Icons.verified_user_outlined),
                    ),
                  ),
                  if (error != null)
                    _Message(text: error!, color: AppColors.danger),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: loading ? null : _save,
                    child: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          )
                        : Text(context.tr('Şifreyi güncelle', 'Update password',
                            'Обновить пароль')),
                  ),
                ],
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
