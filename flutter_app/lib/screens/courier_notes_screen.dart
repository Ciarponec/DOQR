import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/courier_note_item.dart';
import '../models/door_item.dart';
import '../services/providers.dart';
import '../widgets/app_shell.dart';

class CourierNotesScreen extends ConsumerStatefulWidget {
  final DoorItem door;
  const CourierNotesScreen({super.key, required this.door});

  @override
  ConsumerState<CourierNotesScreen> createState() => _CourierNotesScreenState();
}

class _CourierNotesScreenState extends ConsumerState<CourierNotesScreen> {
  late Future<List<CourierNoteItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(doqrApiProvider).listCourierNotes(widget.door.id);
  }

  void _reload() {
    final next = ref.read(doqrApiProvider).listCourierNotes(widget.door.id);
    setState(() {
      _future = next;
    });
  }

  Future<void> _edit([CourierNoteItem? note]) async {
    final code =
        TextEditingController(text: note?.courierCode ?? 'hepsiburada');
    final label =
        TextEditingController(text: note?.courierLabel ?? 'Hepsiburada');
    final title = TextEditingController(text: note?.title ?? 'Teslimat notu');
    final message =
        TextEditingController(text: note?.message ?? 'Lütfen kapıya bırakın.');
    final delivery = TextEditingController(text: note?.deliveryCode ?? '');
    var active = note?.isActive ?? true;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title:
              Text(note == null ? 'Kurye notu ekle' : 'Kurye notunu düzenle'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: label,
                      decoration:
                          const InputDecoration(labelText: 'Kurye şirketi')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: code,
                      decoration: const InputDecoration(
                          labelText: 'Eşleşme kodu (örn. hepsiburada)')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: title,
                      decoration: const InputDecoration(labelText: 'Başlık')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: message,
                      maxLength: 500,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Mesaj')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: delivery,
                      decoration: const InputDecoration(
                          labelText: 'Teslimat kodu (opsiyonel)',
                          helperText: 'Sunucuda şifrelenerek saklanır.')),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: active,
                      onChanged: (value) =>
                          setDialogState(() => active = value),
                      title: const Text('Aktif')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Vazgeç')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Kaydet')),
          ],
        ),
      ),
    );
    if (save != true) return;
    try {
      await ref.read(doqrApiProvider).saveCourierNote(
            doorId: widget.door.id,
            id: note?.id,
            courierCode: code.text
                .trim()
                .toLowerCase()
                .replaceAll(RegExp(r'[^a-z0-9_-]'), '-'),
            courierLabel: label.text.trim(),
            title: title.text.trim(),
            message: message.text.trim(),
            deliveryCode:
                delivery.text.trim().isEmpty ? null : delivery.text.trim(),
            isActive: active,
          );
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AppShell(
        title: 'Kurye notları',
        child: FutureBuilder<List<CourierNoteItem>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }
            final notes = snapshot.data ?? [];
            return Column(
              children: [
                ElevCard(
                  child: Text(
                      'Yalnızca QR’ı tararken bu kurye şirketini seçen ziyaretçi ilgili notu ve teslimat kodunu görür.',
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
                const SizedBox(height: 12),
                Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                        onPressed: _edit,
                        icon: const Icon(Icons.add),
                        label: const Text('Not ekle'))),
                const SizedBox(height: 12),
                Expanded(
                  child: notes.isEmpty
                      ? const Center(child: Text('Henüz kurye notu yok.'))
                      : ListView.separated(
                          itemCount: notes.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final note = notes[index];
                            return ElevCard(
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(note.isActive
                                    ? Icons.local_shipping_rounded
                                    : Icons.local_shipping_outlined),
                                title: Text(note.courierLabel,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                subtitle: Text(
                                    '${note.message}${note.deliveryCode == null ? '' : '\nKod: ${note.deliveryCode}'}'),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (action) async {
                                    if (action == 'edit') return _edit(note);
                                    await ref
                                        .read(doqrApiProvider)
                                        .deleteCourierNote(
                                            widget.door.id, note.id);
                                    _reload();
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                        value: 'edit', child: Text('Düzenle')),
                                    PopupMenuItem(
                                        value: 'delete', child: Text('Sil')),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      );
}
