import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../ui/app_theme.dart';
import '../widgets/app_shell.dart';

class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  var _step = 0;

  @override
  Widget build(BuildContext context) {
    final content = switch (_step) {
      0 => _DemoStep(
          icon: Icons.qr_code_scanner_rounded,
          title: context.tr('Bir ziyaretçi QR kodunuzu tarar',
              'A visitor scans your QR code'),
          body: context.tr(
              'Uygulama yüklemeden yalnızca zili çalar; arama türünü siz seçersiniz.',
              'Without installing the app, they only ring the bell; you choose how to respond.'),
          action: context.tr('Örnek zili çal', 'Ring the sample bell'),
        ),
      1 => _DemoStep(
          icon: Icons.notifications_active_rounded,
          title: context.tr('Anında bildirim alırsınız',
              'You receive an instant notification'),
          body: context.tr(
              'Kapı yöneticisi; yazılı, sesli veya görüntülü yanıtı tek dokunuşla seçer.',
              'The door manager chooses a text, audio, or video response with one tap.',
              'Управляющий дверью выбирает текстовый, аудио- или видеоответ одним касанием.'),
          action:
              context.tr('Görüşme seçeneğini göster', 'Show response options'),
        ),
      _ => _DemoStep(
          icon: Icons.forum_rounded,
          title: context.tr('Ziyaretçi onaylarsa görüşme başlar',
              'The conversation starts after visitor approval'),
          body: context.tr(
              'Kamera ve mikrofon izni yalnızca sesli veya görüntülü görüşmeyi kabul ettiğinde istenir.',
              'Camera and microphone permission is requested only after they accept an audio or video call.'),
          action: context.tr('Baştan incele', 'Restart demo'),
        ),
    };

    return AppShell(
      title: context.tr('DOQR örneği', 'DOQR demo'),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ElevCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.tr('Kayıt olmadan örnek akış',
                            'Try the flow without an account'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.tr(
                            'Bu bir etkileşimli tanıtımdır; hiçbir veri kaydedilmez.',
                            'This is an interactive preview; no data is saved.'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.muted),
                      ),
                      const SizedBox(height: 28),
                      SoftIcon(content.icon, size: 72),
                      const SizedBox(height: 18),
                      Text(content.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 10),
                      Text(content.body, textAlign: TextAlign.center),
                      const SizedBox(height: 26),
                      FilledButton.icon(
                        onPressed: () =>
                            setState(() => _step = (_step + 1) % 3),
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(content.action),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context)
                            .pushNamedAndRemoveUntil('/', (_) => false),
                        child: Text(context.tr('Kendi zilini oluştur',
                            'Create your own doorbell')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoStep {
  final IconData icon;
  final String title;
  final String body;
  final String action;

  const _DemoStep({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
  });
}
