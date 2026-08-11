import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_config.dart';
import '../l10n/app_language.dart';
import '../models/door_item.dart';
import '../services/providers.dart';
import '../services/door_qr_cache.dart';
import '../ui/app_theme.dart';
import '../widgets/app_shell.dart';
import 'courier_notes_screen.dart';
import 'door_blocks_screen.dart';
import 'door_qr_screen.dart';
import 'door_share_screen.dart';

class DoorsManageScreen extends ConsumerStatefulWidget {
  const DoorsManageScreen({super.key});

  @override
  ConsumerState<DoorsManageScreen> createState() => _DoorsManageScreenState();
}

class _DoorsManageScreenState extends ConsumerState<DoorsManageScreen> {
  late Future<DoorListResult> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(doqrApiProvider).listDoors();
  }

  void _reload() {
    final next = ref.read(doqrApiProvider).listDoors();
    setState(() {
      _future = next;
    });
  }

  Future<void> _create(PlanItem plan) async {
    final label = TextEditingController();
    final address = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Yeni dijital zil', 'New digital doorbell')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: label,
                autofocus: true,
                decoration: InputDecoration(
                    labelText: context.tr('Zil adı', 'Doorbell name'))),
            const SizedBox(height: 10),
            TextField(
                controller: address,
                decoration: InputDecoration(
                    labelText: context.tr('Adres (yalnızca host görür)',
                        'Address (visible to hosts only)'))),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('Vazgeç', 'Cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.tr('Oluştur', 'Create'))),
        ],
      ),
    );
    if (accepted != true || label.text.trim().isEmpty) return;
    try {
      await ref.read(doqrApiProvider).createDoor(
            label: label.text.trim(),
            addressText:
                address.text.trim().isEmpty ? null : address.text.trim(),
          );
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _edit(DoorItem door) async {
    final label = TextEditingController(text: door.label);
    final address = TextEditingController(text: door.addressText ?? '');
    final welcome =
        TextEditingController(text: door.settings.welcomeMessage ?? '');
    var text = door.settings.textEnabled;
    var audio = door.settings.audioEnabled;
    var video = door.settings.videoEnabled;
    var requireName = door.settings.requireVisitorName;
    var active = door.isActive;
    var timeout = door.settings.ringTimeoutSeconds.toDouble();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
              context.tr('${door.label} ayarları', '${door.label} settings')),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: label,
                      decoration: InputDecoration(
                          labelText: context.tr('Zil adı', 'Doorbell name'))),
                  const SizedBox(height: 10),
                  TextField(
                      controller: address,
                      decoration: InputDecoration(
                          labelText: context.tr('Adres', 'Address'))),
                  const SizedBox(height: 10),
                  TextField(
                      controller: welcome,
                      maxLength: 280,
                      decoration: InputDecoration(
                          labelText: context.tr('Ziyaretçi karşılama mesajı',
                              'Visitor welcome message'))),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: active,
                      onChanged: (value) =>
                          setDialogState(() => active = value),
                      title: Text(context.tr(
                          'Dijital zil aktif', 'Digital doorbell active'))),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: text,
                      onChanged: (value) => setDialogState(() => text = value),
                      title: Text(context.tr('Yazılı görüşme', 'Text chat'))),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: audio,
                    onChanged: door.plan.has('audio_call')
                        ? (value) => setDialogState(() => audio = value)
                        : null,
                    title: Text(context.tr('Sesli görüşme', 'Audio call')),
                    subtitle: door.plan.has('audio_call')
                        ? null
                        : Text(context.tr('Pro özelliği', 'Pro feature')),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: video,
                    onChanged: door.plan.has('video_call')
                        ? (value) => setDialogState(() => video = value)
                        : null,
                    title: Text(context.tr('Görüntülü görüşme', 'Video call')),
                    subtitle: door.plan.has('video_call')
                        ? null
                        : Text(context.tr('Pro özelliği', 'Pro feature')),
                  ),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: requireName,
                      onChanged: (value) =>
                          setDialogState(() => requireName = value),
                      title: Text(context.tr(
                          'Ziyaretçi adı zorunlu', 'Require visitor name'))),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                          context.tr('Zil bekleme süresi', 'Ring timeout'))),
                  Slider(
                    value: timeout,
                    min: 15,
                    max: 120,
                    divisions: 7,
                    label: context.tr(
                        '${timeout.round()} sn', '${timeout.round()} sec'),
                    onChanged: (value) => setDialogState(() => timeout = value),
                  ),
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
    if (saved != true) return;
    try {
      await ref.read(doqrApiProvider).updateDoor(
            door: door,
            label: label.text.trim(),
            addressText:
                address.text.trim().isEmpty ? null : address.text.trim(),
            welcomeMessage:
                welcome.text.trim().isEmpty ? null : welcome.text.trim(),
            textEnabled: text,
            audioEnabled: audio,
            videoEnabled: video,
            requireVisitorName: requireName,
            ringTimeoutSeconds: timeout.round(),
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

  Future<void> _showQr(DoorItem door) async {
    try {
      var token = await DoorQrCache.read(door.id);
      token ??= (await ref.read(doqrApiProvider).createQrToken(doorId: door.id))
          ['qr_token'] as String;
      await DoorQrCache.save(door.id, token);
      if (!mounted) return;
      final url = AppConfig.visitorUrlForToken(
        token,
      ).toString();
      await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => DoorQrScreen(
                doorLabel: door.label,
                qrUrl: url)),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _acceptShareInvite() async {
    final token = TextEditingController();
    final pin = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Kapı davetine katıl', 'Join door invite')),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr(
                    'Kapı sahibinin gönderdiği davet kodunu girin. Katıldığınızda bu kapının bildirimlerini ve ziyaret mesajlarını alırsınız.',
                    'Enter the invite code sent by the door owner. Once joined, you receive this door’s notifications and visitor messages.'),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: token,
                autofocus: true,
                maxLength: 256,
                decoration: InputDecoration(
                    labelText: context.tr('Davet kodu', 'Invite code')),
              ),
              TextField(
                controller: pin,
                keyboardType: TextInputType.number,
                maxLength: 12,
                decoration: InputDecoration(
                    labelText: context.tr('PIN (varsa)', 'PIN (if provided)')),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('Vazgeç', 'Cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.tr('Katıl', 'Join'))),
        ],
      ),
    );
    final shareToken = token.text.trim();
    final sharePin = pin.text.trim();
    token.dispose();
    pin.dispose();
    if (accepted != true || shareToken.isEmpty) return;
    try {
      await ref.read(doqrApiProvider).acceptDoorShareInvite(
            shareToken: shareToken,
            pin: sharePin.isEmpty ? null : sharePin,
          );
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.tr('Kapı eklendi.', 'Door added.'))));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AppShell(
        title: context.tr('Dijital ziller', 'Digital doorbells'),
        child: FutureBuilder<DoorListResult>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }
            final result = snapshot.requireData;
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(
                            context.tr(
                                '${result.doors.length}/${result.accountPlan.maxDoors} zil',
                                '${result.doors.length}/${result.accountPlan.maxDoors} doorbells'),
                            style: Theme.of(context).textTheme.titleMedium)),
                    FilledButton.icon(
                      onPressed:
                          result.doors.length < result.accountPlan.maxDoors
                              ? () => _create(result.accountPlan)
                              : null,
                      icon: const Icon(Icons.add_rounded),
                        label: Text(context.tr('Ekle', 'Add')),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      tooltip: context.tr(
                          'Davet kodunu kullan', 'Use invite code'),
                      onPressed: _acceptShareInvite,
                      icon: const Icon(Icons.group_add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: result.doors.isEmpty
                      ? Center(
                          child: Text(context.tr(
                              'İlk dijital zilini oluşturarak başla.',
                              'Start by creating your first digital doorbell.')))
                      : ListView.separated(
                          itemCount: result.doors.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final door = result.doors[index];
                            final modes = [
                              if (door.settings.textEnabled)
                                context.tr('Yazı', 'Text'),
                              if (door.settings.audioEnabled)
                                context.tr('Ses', 'Audio'),
                              if (door.settings.videoEnabled) 'Video',
                            ].join(' • ');
                            return ElevCard(
                              child: Column(
                                children: [
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(door.isActive
                                        ? Icons.door_front_door_rounded
                                        : Icons.do_not_disturb_on_rounded),
                                    title: Text(door.label,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    subtitle: Text(
                                        '${door.addressText ?? context.tr('Adres eklenmedi', 'No address added')}\n$modes'),
                                    isThreeLine: true,
                                    trailing: door.isOwner
                                        ? IconButton(
                                            onPressed: () => _edit(door),
                                            icon:
                                                const Icon(Icons.tune_rounded))
                                        : null,
                                  ),
                                  if (door.isOwner)
                                    Row(
                                      children: [
                                        Expanded(
                                            child: OutlinedButton.icon(
                                                onPressed: () => _showQr(door),
                                                icon: const Icon(
                                                    Icons.qr_code_2_rounded),
                                                label: Text(context.tr(
                                                    'QR kodu',
                                                    'QR code')))),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: door.plan
                                                    .has('courier_notes')
                                                ? () => Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (_) =>
                                                            CourierNotesScreen(
                                                                door: door)))
                                                : null,
                                            icon: const Icon(
                                                Icons.local_shipping_outlined),
                                            label: Text(
                                                door.plan.has('courier_notes')
                                                    ? context.tr(
                                                        'Kurye notları',
                                                        'Courier notes')
                                                    : context.tr('Kurye (Pro)',
                                                        'Courier (Pro)')),
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (door.isOwner) ...[
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: TextButton.icon(
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  DoorShareScreen(door: door)),
                                        ),
                                        icon: const Icon(Icons.people_alt_rounded),
                                        label: Text(context.tr(
                                            'Host ile paylaş',
                                            'Share with host')),
                                      ),
                                    ),
                                    SizedBox(
                                      width: double.infinity,
                                      child: TextButton.icon(
                                        onPressed: door.plan
                                                .has('visitor_blocking')
                                            ? () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        DoorBlocksScreen(
                                                            door: door),
                                                  ),
                                                )
                                            : null,
                                        icon: const Icon(Icons.shield_outlined),
                                        label: Text(context.tr(
                                            door.plan.has('visitor_blocking')
                                                ? 'Engellenen cihazlar ve ağlar'
                                                : 'Engeller (Pro)',
                                            door.plan.has('visitor_blocking')
                                                ? 'Blocked devices and networks'
                                                : 'Blocking (Pro)')),
                                      ),
                                    ),
                                  ],
                                ],
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
