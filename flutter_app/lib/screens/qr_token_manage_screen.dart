import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/providers.dart';

class QrTokenManageScreen extends ConsumerStatefulWidget {
  const QrTokenManageScreen({super.key});

  @override
  ConsumerState<QrTokenManageScreen> createState() => _QrTokenManageScreenState();
}

class _QrTokenManageScreenState extends ConsumerState<QrTokenManageScreen> {
  final doorId = TextEditingController();
  final tokenId = TextEditingController();
  String? generatedToken;

  @override
  Widget build(BuildContext context) {
    final api = ref.read(doqrApiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('QR Token Manage')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: doorId, decoration: const InputDecoration(labelText: 'Door ID')),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () async {
                final res = await api.createQrToken(doorId: doorId.text.trim());
                setState(() {
                  generatedToken = res['qr_token'] as String;
                  tokenId.text = res['token_id'] as String;
                });
              },
              child: const Text('QR Token Uret'),
            ),
            if (generatedToken != null) SelectableText('Token: $generatedToken'),
            const Divider(height: 32),
            TextField(controller: tokenId, decoration: const InputDecoration(labelText: 'Token ID (revoke)')),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                await api.revokeQrToken(tokenId: tokenId.text.trim());
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token revoked')));
              },
              child: const Text('Token Iptal Et'),
            ),
          ],
        ),
      ),
    );
  }
}
