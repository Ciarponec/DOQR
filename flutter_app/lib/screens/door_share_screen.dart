import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_language.dart';
import '../models/door_item.dart';
import '../services/providers.dart';
import '../ui/app_theme.dart';
import '../widgets/app_shell.dart';

class DoorShareScreen extends ConsumerStatefulWidget {
  final DoorItem door;

  const DoorShareScreen({super.key, required this.door});

  @override
  ConsumerState<DoorShareScreen> createState() => _DoorShareScreenState();
}

class _DoorShareScreenState extends ConsumerState<DoorShareScreen> {
  String? _inviteToken;
  DateTime? _inviteExpiresAt;
  bool _busy = false;

  int get _additionalHosts => widget.door.plan.maxHostsPerDoor - 1;

  Future<void> _createInvite() async {
    final pin = TextEditingController();
    var expiresMinutes = 1440;
    var usePin = false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.tr('Host daveti oluştur', 'Create host invite')),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr(
                      'Daveti yalnızca güvendiğiniz kişiyle paylaşın. Daveti kabul eden kişi bu kapıdan gelen bildirimleri ve ziyaret mesajlarını alabilir.',
                      'Only share this invite with someone you trust. Whoever accepts it can receive alerts and visitor messages for this door.'),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: expiresMinutes,
                  decoration: InputDecoration(
                      labelText: context.tr('Geçerlilik süresi', 'Expiry')),
                  items: [
                    DropdownMenuItem(
                        value: 60,
                        child: Text(context.tr('1 saat', '1 hour'))),
                    DropdownMenuItem(
                        value: 1440,
                        child: Text(context.tr('24 saat', '24 hours'))),
                    DropdownMenuItem(
                        value: 10080,
                        child: Text(context.tr('7 gün', '7 days'))),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => expiresMinutes = value ?? 1440),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: usePin,
                  onChanged: (value) => setDialogState(() => usePin = value),
                  title: Text(context.tr('PIN koruması ekle', 'Add PIN protection')),
                ),
                if (usePin)
                  TextField(
                    controller: pin,
                    keyboardType: TextInputType.number,
                    maxLength: 12,
                    decoration: InputDecoration(
                      labelText: context.tr('4–12 haneli PIN', '4–12 digit PIN'),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.tr('Vazgeç', 'Cancel'))),
            FilledButton(
              onPressed: () {
                if (usePin && !RegExp(r'^\d{4,12}$').hasMatch(pin.text)) {
                  return;
                }
                Navigator.pop(context, true);
              },
              child: Text(context.tr('Daveti oluştur', 'Create invite')),
            ),
          ],
        ),
      ),
    );
    final pinValue = pin.text.trim();
    pin.dispose();
    if (accepted != true) return;

    setState(() => _busy = true);
    try {
      final invite = await ref.read(doqrApiProvider).createDoorShareInvite(
            doorId: widget.door.id,
            expiresMinutes: expiresMinutes,
            pin: pinValue.isEmpty ? null : pinValue,
          );
      if (!mounted) return;
      setState(() {
        _inviteToken = invite['share_token'] as String;
        _inviteExpiresAt = DateTime.tryParse(invite['expires_at'].toString());
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyInvite() async {
    final token = _inviteToken;
    if (token == null) return;
    final expires = _inviteExpiresAt == null
        ? ''
        : '\n${context.tr('Geçerlilik', 'Expires')}: ${_formatDate(_inviteExpiresAt!)}';
    await Clipboard.setData(ClipboardData(
      text: '${context.tr('DOQR host daveti', 'DOQR host invite')}\n'
          '${context.tr('Kapı', 'Door')}: ${widget.door.label}\n'
          '${context.tr('Davet kodu', 'Invite code')}: $token$expires\n\n'
          '${context.tr('DOQR uygulamasında Dijital ziller > Davet kodunu kullan bölümünden katılın.', 'In the DOQR app, go to Digital doorbells > Use invite code to join.')}',
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr('Davet kodu kopyalandı.', 'Invite copied.'))));
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final canInvite = _additionalHosts > 0;
    return AppShell(
      title: context.tr('Host paylaşımı', 'Host sharing'),
      child: ListView(
        children: [
          ElevCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const SoftIcon(Icons.people_alt_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.door.label,
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 3),
                          Text(
                            context.tr(
                                'Bu kapı en fazla ${widget.door.plan.maxHostsPerDoor} host tarafından kullanılabilir.',
                                'This door can be used by up to ${widget.door.plan.maxHostsPerDoor} hosts.'),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  canInvite
                      ? context.tr(
                          'Davet edilen host, kendi hesabıyla katılır ve bu kapı çaldığında bildirim alır. Davet tek kullanımlıktır.',
                          'An invited host joins with their own account and receives notifications when this door rings. Each invite can be used once.')
                      : context.tr(
                          'Free plan yalnızca kapı sahibi olmak üzere 1 host destekler. Aynı kapıyı eşinizle veya başka bir kişiyle paylaşmak için Pro gerekir.',
                          'The Free plan supports just 1 host—the door owner. Pro is required to share this door with a spouse or another person.'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: canInvite && !_busy ? _createInvite : null,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: Text(context.tr('Davet oluştur', 'Create invite')),
                ),
              ],
            ),
          ),
          if (_inviteToken != null) ...[
            const SizedBox(height: 14),
            ElevCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(context.tr('Hazır davet', 'Ready invite'),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    context.tr(
                        'Bu kodu eşinize veya ortak hosta güvenli bir kanaldan iletin.',
                        'Send this code to your spouse or co-host through a trusted channel.'),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 16),
                  SelectableText(_inviteToken!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontFamily: 'monospace', letterSpacing: 1.1)),
                  if (_inviteExpiresAt != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      '${context.tr('Geçerlilik', 'Expires')}: ${_formatDate(_inviteExpiresAt!)}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.muted),
                    ),
                  ],
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _copyInvite,
                    icon: const Icon(Icons.copy_rounded),
                    label: Text(context.tr('Daveti kopyala', 'Copy invite')),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
