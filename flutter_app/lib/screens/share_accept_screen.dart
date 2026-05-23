import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/providers.dart';
import '../widgets/app_shell.dart';

class ShareAcceptScreen extends ConsumerStatefulWidget {
  const ShareAcceptScreen({super.key});

  @override
  ConsumerState<ShareAcceptScreen> createState() => _ShareAcceptScreenState();
}

class _ShareAcceptScreenState extends ConsumerState<ShareAcceptScreen> {
  final token = TextEditingController();
  final pin = TextEditingController();
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    final api = ref.read(doqrApiProvider);
    return AppShell(
      title: 'Share Token Kabul',
      child: ElevCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: token, decoration: const InputDecoration(labelText: 'Share Token')),
            const SizedBox(height: 8),
            TextField(controller: pin, decoration: const InputDecoration(labelText: 'PIN (opsiyonel)')),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      setState(() => loading = true);
                      try {
                        await api.acceptShareToken(token: token.text.trim(), pin: pin.text.trim().isEmpty ? null : pin.text.trim());
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paylasim kabul edildi')));
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                      } finally {
                        if (mounted) setState(() => loading = false);
                      }
                    },
              child: Text(loading ? 'Bekleyin...' : 'Kabul Et'),
            ),
          ],
        ),
      ),
    );
  }
}
