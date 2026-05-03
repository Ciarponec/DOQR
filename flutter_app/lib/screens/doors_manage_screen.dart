import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/providers.dart';

class DoorsManageScreen extends ConsumerStatefulWidget {
  const DoorsManageScreen({super.key});

  @override
  ConsumerState<DoorsManageScreen> createState() => _DoorsManageScreenState();
}

class _DoorsManageScreenState extends ConsumerState<DoorsManageScreen> {
  final label = TextEditingController();
  final address = TextEditingController();
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    final api = ref.read(doqrApiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kapilarim')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(controller: label, decoration: const InputDecoration(labelText: 'Kapi Ismi (zorunlu)')),
                const SizedBox(height: 8),
                TextField(controller: address, decoration: const InputDecoration(labelText: 'Adres (opsiyonel)')),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: loading ? null : () async {
                    if (label.text.trim().isEmpty) return;
                    setState(() => loading = true);
                    try {
                      await api.createDoor(label: label.text.trim(), addressText: address.text.trim().isEmpty ? null : address.text.trim());
                      label.clear();
                      address.clear();
                      if (mounted) setState(() {});
                    } finally {
                      if (mounted) setState(() => loading = false);
                    }
                  },
                  child: const Text('Kapi Ekle'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: FutureBuilder(
              future: api.listDoors(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                final doors = snapshot.data ?? [];
                if (doors.isEmpty) return const Center(child: Text('Henuz kapi yok'));
                return ListView(
                  children: doors.map((d) => ListTile(title: Text(d.label), subtitle: Text(d.addressText ?? d.id))).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
