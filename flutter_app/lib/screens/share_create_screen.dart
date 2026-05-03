import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/door_item.dart';
import '../services/providers.dart';

class ShareCreateScreen extends ConsumerStatefulWidget {
  const ShareCreateScreen({super.key});

  @override
  ConsumerState<ShareCreateScreen> createState() => _ShareCreateScreenState();
}

class _ShareCreateScreenState extends ConsumerState<ShareCreateScreen> {
  final pin = TextEditingController();
  String? token;
  DoorItem? selectedDoor;

  @override
  Widget build(BuildContext context) {
    final api = ref.read(doqrApiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Share Token Create')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            FutureBuilder(
              future: api.listDoors(),
              builder: (context, snapshot) {
                final doors = snapshot.data ?? <DoorItem>[];
                if (doors.isEmpty) return const Text('Once Kapi Ekle');
                selectedDoor ??= doors.first;
                return DropdownButtonFormField<DoorItem>(
                  value: selectedDoor,
                  items: doors.map((d) => DropdownMenuItem(value: d, child: Text(d.label))).toList(),
                  onChanged: (v) => setState(() => selectedDoor = v),
                  decoration: const InputDecoration(labelText: 'Kapi Secimi'),
                );
              },
            ),
            const SizedBox(height: 8),
            TextField(controller: pin, decoration: const InputDecoration(labelText: 'PIN (optional)')),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: selectedDoor == null ? null : () async {
                final res = await api.createShareToken(doorId: selectedDoor!.id, pin: pin.text.trim().isEmpty ? null : pin.text.trim());
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
