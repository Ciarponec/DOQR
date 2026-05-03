import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/providers.dart';

class ShareCreateScreen extends ConsumerStatefulWidget {
  const ShareCreateScreen({super.key});

  @override
  ConsumerState<ShareCreateScreen> createState() => _ShareCreateScreenState();
}

class _ShareCreateScreenState extends ConsumerState<ShareCreateScreen> {
  final doorId = TextEditingController();
  final pin = TextEditingController();
  String? token;

  @override
  Widget build(BuildContext context) {
    final api = ref.read(doqrApiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Share Token Create')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: doorId, decoration: const InputDecoration(labelText: 'Door ID')),
            const SizedBox(height: 8),
            TextField(controller: pin, decoration: const InputDecoration(labelText: 'PIN (optional)')),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () async {
                final res = await api.createShareToken(doorId: doorId.text.trim(), pin: pin.text.trim().isEmpty ? null : pin.text.trim());
                setState(() => token = res['share_token'] as String);
              },
              child: const Text('Share Token Uret'),
            ),
            if (token != null) SelectableText('Share Token: $token'),
          ],
        ),
      ),
    );
  }
}
