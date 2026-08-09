import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/door_item.dart';
import '../services/providers.dart';
import '../ui/app_theme.dart';
import '../widgets/app_shell.dart';

class DoorBlocksScreen extends ConsumerStatefulWidget {
  final DoorItem door;
  const DoorBlocksScreen({super.key, required this.door});

  @override
  ConsumerState<DoorBlocksScreen> createState() => _DoorBlocksScreenState();
}

class _DoorBlocksScreenState extends ConsumerState<DoorBlocksScreen> {
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = ref.read(doqrApiProvider).listDoorBlocks(widget.door.id);
  }

  void reload() => setState(() {
        future = ref.read(doqrApiProvider).listDoorBlocks(widget.door.id);
      });

  Future<void> remove(Map<String, dynamic> block) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Engel kaldırılsın mı?'),
        content:
            const Text('Bu cihaz veya ağ yeniden dijital zili çalabilecek.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Engeli kaldır')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(doqrApiProvider)
          .removeDoorBlock(widget.door.id, block['id'] as String);
      if (mounted) reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AppShell(
        title: 'Engellenenler',
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }
            final blocks = snapshot.data ?? const [];
            if (blocks.isEmpty) {
              return const Center(
                  child: Text('Aktif cihaz veya ağ engeli yok.'));
            }
            return ListView.separated(
              itemCount: blocks.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final block = blocks[index];
                final network = block['block_type'] == 'network';
                final expires =
                    DateTime.tryParse(block['expires_at']?.toString() ?? '');
                return ElevCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: network
                          ? const Color(0xFFFFF3D8)
                          : const Color(0xFFE7EEFF),
                      child: Icon(network
                          ? Icons.wifi_off_rounded
                          : Icons.phonelink_erase_rounded),
                    ),
                    title: Text(network ? 'Ağ engeli' : 'Cihaz engeli',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      expires == null
                          ? 'Kalıcı • ${block['reason'] ?? ''}'
                          : '${expires.toLocal()} tarihine kadar • ${block['reason'] ?? ''}',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    trailing: IconButton(
                      tooltip: 'Engeli kaldır',
                      onPressed: () => remove(block),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
}
