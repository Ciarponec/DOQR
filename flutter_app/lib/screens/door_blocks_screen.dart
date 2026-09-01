import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_language.dart';
import '../models/door_item.dart';
import '../services/providers.dart';
import '../services/user_error.dart';
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
        title: Text(context.tr('Engel kaldırılsın mı?', 'Remove this block?')),
        content: Text(context.tr(
            'Bu cihaz veya ağ yeniden dijital zili çalabilecek.',
            'This device or network will be able to ring the digital doorbell again.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('Vazgeç', 'Cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.tr('Engeli kaldır', 'Remove block'))),
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
            .showSnackBar(SnackBar(content: Text(userErrorMessage(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AppShell(
        title: context.tr('Engellenenler', 'Blocked visitors'),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text(userErrorMessage(snapshot.error)));
            }
            final blocks = snapshot.data ?? const [];
            if (blocks.isEmpty) {
              return Center(
                  child: Text(context.tr('Aktif cihaz veya ağ engeli yok.',
                      'There are no active device or network blocks.')));
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
                    title: Text(
                        network
                            ? context.tr('Ağ engeli', 'Network block')
                            : context.tr('Cihaz engeli', 'Device block'),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      expires == null
                          ? context.tr(
                              'Kalıcı • ${block['reason'] ?? ''}',
                              'Permanent • ${block['reason'] ?? ''}',
                              'Постоянно • ${block['reason'] ?? ''}')
                          : context.tr(
                              '${expires.toLocal()} tarihine kadar • ${block['reason'] ?? ''}',
                              'Until ${expires.toLocal()} • ${block['reason'] ?? ''}',
                              'До ${expires.toLocal()} • ${block['reason'] ?? ''}'),
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    trailing: IconButton(
                      tooltip: context.tr('Engeli kaldır', 'Remove block'),
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
