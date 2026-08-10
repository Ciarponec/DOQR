import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_language.dart';
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
    final title = TextEditingController(
        text: note?.title ?? context.tr('Teslimat notu', 'Delivery note'));
    final message = TextEditingController(
        text: note?.message ??
            context.tr(
                'Lütfen kapıya bırakın.', 'Please leave it at the door.'));
    final delivery = TextEditingController(text: note?.deliveryCode ?? '');
    var active = note?.isActive ?? true;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(note == null
              ? context.tr('Kurye notu ekle', 'Add courier note')
              : context.tr('Kurye notunu düzenle', 'Edit courier note')),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: label,
                      decoration: InputDecoration(
                          labelText:
                              context.tr('Kurye şirketi', 'Courier company'))),
                  const SizedBox(height: 10),
                  TextField(
                      controller: code,
                      decoration: InputDecoration(
                          labelText: context.tr(
                              'Eşleşme kodu (örn. hepsiburada)',
                              'Matching code (e.g. hepsiburada)'))),
                  const SizedBox(height: 10),
                  TextField(
                      controller: title,
                      decoration: InputDecoration(
                          labelText: context.tr('Başlık', 'Title'))),
                  const SizedBox(height: 10),
                  TextField(
                      controller: message,
                      maxLength: 500,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                          labelText: context.tr('Mesaj', 'Message'))),
                  const SizedBox(height: 10),
                  TextField(
                      controller: delivery,
                      decoration: InputDecoration(
                          labelText: context.tr('Teslimat kodu (opsiyonel)',
                              'Delivery code (optional)'),
                          helperText: context.tr(
                              'Sunucuda şifrelenerek saklanır.',
                              'Stored encrypted on the server.'))),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: active,
                      onChanged: (value) =>
                          setDialogState(() => active = value),
                      title: Text(context.tr('Aktif', 'Active'))),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.tr('Vazgeç', 'Cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.tr('Kaydet', 'Save'))),
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
        title: context.tr('Kurye notları', 'Courier notes'),
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
                      context.tr(
                          'Yalnızca QR’ı tararken bu kurye şirketini seçen ziyaretçi ilgili notu ve teslimat kodunu görür.',
                          'Only visitors who select this courier company while scanning the QR code will see the related note and delivery code.'),
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
                const SizedBox(height: 12),
                Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                        onPressed: _edit,
                        icon: const Icon(Icons.add),
                        label: Text(context.tr('Not ekle', 'Add note')))),
                const SizedBox(height: 12),
                Expanded(
                  child: notes.isEmpty
                      ? Center(
                          child: Text(context.tr('Henüz kurye notu yok.',
                              'No courier notes yet.')))
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
                                    '${note.message}${note.deliveryCode == null ? '' : context.tr('\nKod: ${note.deliveryCode}', '\nCode: ${note.deliveryCode}')}'),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (action) async {
                                    if (action == 'edit') return _edit(note);
                                    await ref
                                        .read(doqrApiProvider)
                                        .deleteCourierNote(
                                            widget.door.id, note.id);
                                    _reload();
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                        value: 'edit',
                                        child: Text(
                                            context.tr('Düzenle', 'Edit'))),
                                    PopupMenuItem(
                                        value: 'delete',
                                        child:
                                            Text(context.tr('Sil', 'Delete'))),
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
