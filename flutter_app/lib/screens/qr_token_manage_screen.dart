import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/door_item.dart';
import '../services/providers.dart';

class QrTokenManageScreen extends ConsumerStatefulWidget {
  const QrTokenManageScreen({super.key});

  @override
  ConsumerState<QrTokenManageScreen> createState() => _QrTokenManageScreenState();
}

class _QrTokenManageScreenState extends ConsumerState<QrTokenManageScreen> {
  final tokenId = TextEditingController();
  String? generatedToken;
  String? selectedDoorId;

  @override
  Widget build(BuildContext context) {
    final api = ref.read(doqrApiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('QR Token Manage')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            FutureBuilder<List<DoorItem>>(
              future: api.listDoors(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const CircularProgressIndicator();
                }
                if (snapshot.hasError) {
                  return Text('Kapilar alinamadi: ${snapshot.error}');
                }
                final doors = snapshot.data ?? <DoorItem>[];
                if (doors.isEmpty) return const Text('Once Kapi Ekle');
                selectedDoorId ??= doors.first.id;
                if (!doors.any((d) => d.id == selectedDoorId)) {
                  selectedDoorId = doors.first.id;
                }
                return DropdownButtonFormField<String>(
                  value: selectedDoorId,
                  items: doors.map((d) => DropdownMenuItem(value: d.id, child: Text(d.label))).toList(),
                  onChanged: (v) => setState(() => selectedDoorId = v),
                  decoration: const InputDecoration(labelText: 'Kapi Secimi'),
                );
              },
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: selectedDoorId == null ? null : () async {
                final res = await api.createQrToken(doorId: selectedDoorId!);
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
