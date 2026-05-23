import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_config.dart';
import '../models/door_item.dart';
import '../services/providers.dart';
import '../widgets/app_shell.dart';
import 'door_qr_screen.dart';

class DoorsManageScreen extends ConsumerStatefulWidget {
  const DoorsManageScreen({super.key});

  @override
  ConsumerState<DoorsManageScreen> createState() => _DoorsManageScreenState();
}

class _DoorsManageScreenState extends ConsumerState<DoorsManageScreen> {
  final label = TextEditingController();
  final address = TextEditingController();
  bool loading = false;
  int refreshKey = 0;

  Future<void> _editDoor(DoorItem door) async {
    final editLabel = TextEditingController(text: door.label);
    final editAddr = TextEditingController(text: door.addressText ?? '');
    final api = ref.read(doqrApiProvider);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kapi Duzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: editLabel, decoration: const InputDecoration(labelText: 'Kapi Ismi')),
            const SizedBox(height: 8),
            TextField(controller: editAddr, decoration: const InputDecoration(labelText: 'Adres')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Iptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
        ],
      ),
    );

    if (ok == true) {
      await api.updateDoor(
        doorId: door.id,
        label: editLabel.text.trim(),
        addressText: editAddr.text.trim().isEmpty ? null : editAddr.text.trim(),
      );
      if (mounted) {
        refreshKey++;
        setState(() {});
      }
    }
  }

  Future<void> _generateQr(DoorItem door) async {
    final api = ref.read(doqrApiProvider);
    final res = await api.createQrToken(doorId: door.id);
    final qrToken = res['qr_token'] as String;
    final tokenId = res['token_id'] as String;
    final url = '${AppConfig.visitorBaseUrl}?qr=$qrToken';
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => DoorQrScreen(doorLabel: door.label, qrUrl: url, tokenId: tokenId)));
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.read(doqrApiProvider);
    return AppShell(
      title: 'Kapilarim',
      child: Column(
        children: [
          ElevCard(
            child: Column(
              children: [
                TextField(controller: label, decoration: const InputDecoration(labelText: 'Kapi Ismi (zorunlu)')),
                const SizedBox(height: 8),
                TextField(controller: address, decoration: const InputDecoration(labelText: 'Adres (opsiyonel)')),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: loading
                      ? null
                      : () async {
                          if (label.text.trim().isEmpty) return;
                          setState(() => loading = true);
                          try {
                            await api.createDoor(label: label.text.trim(), addressText: address.text.trim().isEmpty ? null : address.text.trim());
                            label.clear();
                            address.clear();
                            refreshKey++;
                            if (mounted) {
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kapi eklendi')));
                            }
                          } catch (e) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kapi eklenemedi: $e')));
                          } finally {
                            if (mounted) setState(() => loading = false);
                          }
                        },
                  child: const Text('Kapi Ekle'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<DoorItem>>(
              key: ValueKey(refreshKey),
              future: api.listDoors(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text('Kapi listesi alinamadi: ${snapshot.error}'));
                final doors = snapshot.data ?? [];
                if (doors.isEmpty) return const Center(child: Text('Henuz kapi yok'));
                return ListView.separated(
                  itemCount: doors.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final d = doors[i];
                    return ElevCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(d.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(d.addressText ?? d.id),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.qr_code_2_rounded), onPressed: () => _generateQr(d)),
                            IconButton(icon: const Icon(Icons.edit_rounded), onPressed: () => _editDoor(d)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
