import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../ui/app_theme.dart';
import 'app_shell.dart';

class ClosedSessionNotice extends StatelessWidget {
  const ClosedSessionNotice({super.key});

  @override
  Widget build(BuildContext context) => ElevCard(
        color: const Color(0xFFF7F9FC),
        child: Row(
          children: [
            const SoftIcon(Icons.lock_outline_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('Görüşme sona erdi', 'Session ended'),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(
                    context.tr(
                        'Mesajlaşma kapatıldı; bu görüşmeye yeni mesaj gönderilemez.',
                        'Messaging is closed; no new messages can be sent in this session.'),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
