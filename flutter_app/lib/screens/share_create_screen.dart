import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/door_item.dart';
import '../services/providers.dart';
import '../widgets/app_shell.dart';

class ShareCreateScreen extends ConsumerStatefulWidget {
  const ShareCreateScreen({super.key});

  @override
  ConsumerState<ShareCreateScreen> createState() => _ShareCreateScreenState();
}

class _ShareCreateScreenState extends ConsumerState<ShareCreateScreen> {
  final pin = TextEditingController();
  String? token;
  String? selectedDoorId;

  @override
  Widget build(BuildContext context) {
    final api = ref.read(doqrApiProvider);
    return AppShell(
      title: 'Share Token Uret',
      child: ListView(
        children: [
          ElevCard(
            child: Column(
              children: [
                FutureBuilder<List<DoorItem>>(
                  future: api.listDoors(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) return const CircularProgressIndicator();
                    if (snapshot.hasError) return Text('Kapilar alinamadi: ${snapshot.error}');
                    final doors = snapshot.data ?? <DoorItem>[];
                    if (doors.isEmpty) return const Text('Once Kapi Ekle');
                    selectedDoorId ??= doors.first.id;
                    if (!doors.any((d) => d.id == selectedDoorId)) selectedDoorId = doors.first.id;
                    return DropdownButtonFormField<String>(
                      initialValue: selectedDoorId,
                      items: doors.map((d) => DropdownMenuItem(value: d.id, child: Text(d.label))).toList(),
                      onChanged: (v) => setState(() => selectedDoorId = v),
                      decoration: const InputDecoration(labelText: 'Kapi Secimi'),
                    );
                  },
                ),
                const SizedBox(height: 8),
                TextField(controller: pin, decoration: const InputDecoration(labelText: 'PIN (opsiyonel)')),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: selectedDoorId == null
                      ? null
                      : () async {
                          final res = await api.createShareToken(doorId: selectedDoorId!, pin: pin.text.trim().isEmpty ? null : pin.text.trim());
                          setState(() => token = res['share_token'] as String);
                        },
                  child: const Text('Share Token Uret'),
                ),
                if (token != null) ...[
                  const SizedBox(height: 10),
                  const Align(alignment: Alignment.centerLeft, child: Text('Paylasim Tokeni')),
                  SelectableText(token!),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}

