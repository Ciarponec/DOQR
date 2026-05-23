import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/providers.dart';
import '../widgets/app_shell.dart';

class QrRingScreen extends ConsumerStatefulWidget {
  const QrRingScreen({super.key});

  @override
  ConsumerState<QrRingScreen> createState() => _QrRingScreenState();
}

class _QrRingScreenState extends ConsumerState<QrRingScreen> {
  final qrToken = TextEditingController();
  final alias = TextEditingController();
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    final api = ref.read(doqrApiProvider);
    return AppShell(
      title: 'QR ile Ring',
      child: ElevCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: qrToken, decoration: const InputDecoration(labelText: 'QR Token')),
            const SizedBox(height: 8),
            TextField(controller: alias, decoration: const InputDecoration(labelText: 'Ziyaretci Ismi (opsiyonel)')),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      setState(() => loading = true);
                      try {
                        final res = await api.ringFromQr(qrToken: qrToken.text.trim(), visitorAlias: alias.text.trim().isEmpty ? null : alias.text.trim());
                        if (!mounted) return;
                        Navigator.pushNamed(context, '/visitor-chat', arguments: {
                          'ring_id': res['ring_id'],
                          'visitor_session_token': res['visitor_session_token'],
                        });
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                      } finally {
                        if (mounted) setState(() => loading = false);
                      }
                    },
              child: Text(loading ? 'Bekleyin...' : 'Ring Olustur'),
            ),
          ],
        ),
      ),
    );
  }
}
