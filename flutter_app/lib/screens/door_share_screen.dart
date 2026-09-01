import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_language.dart';
import '../models/door_item.dart';
import '../services/providers.dart';
import '../services/user_error.dart';
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
  late Future<Map<String, dynamic>> _accessFuture;

  @override
  void initState() {
    super.initState();
    _accessFuture = ref.read(doqrApiProvider).getDoorAccess(widget.door.id);
  }

  void _reloadAccess() => setState(() {
        _accessFuture = ref.read(doqrApiProvider).getDoorAccess(widget.door.id);
      });

  int get _additionalHosts => widget.door.plan.maxHostsPerDoor - 1;

  Future<void> _createInvite() async {
    final pin = TextEditingController();
    var expiresMinutes = 1440;
    var usePin = false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.tr('Kapı yöneticisi daveti oluştur',
              'Create door manager invite', 'Пригласить управляющего дверью')),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr(
                      'Daveti yalnızca güvendiğiniz kişiyle paylaşın. Kabul eden kişi bu kapının bildirimlerini ve ziyaret mesajlarını alabilir.',
                      'Only share this invite with someone you trust. Whoever accepts it can receive alerts and visitor messages for this door.',
                      'Отправляйте приглашение только доверенному человеку. Он сможет получать уведомления и сообщения посетителей этой двери.'),
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
                        value: 60, child: Text(context.tr('1 saat', '1 hour'))),
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
                  title: Text(
                      context.tr('PIN koruması ekle', 'Add PIN protection')),
                ),
                if (usePin)
                  TextField(
                    controller: pin,
                    keyboardType: TextInputType.number,
                    maxLength: 12,
                    decoration: InputDecoration(
                      labelText:
                          context.tr('4–12 haneli PIN', '4–12 digit PIN'),
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
      _reloadAccess();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userErrorMessage(error))));
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
      text:
          '${context.tr('DOQR kapı yöneticisi daveti', 'DOQR door manager invite', 'Приглашение управляющего дверью DOQR')}\n'
          '${context.tr('Kapı', 'Door')}: ${widget.door.label}\n'
          '${context.tr('Davet kodu', 'Invite code')}: $token$expires\n\n'
          '${context.tr('DOQR uygulamasında Dijital ziller > Davet kodunu kullan bölümünden katılın.', 'In the DOQR app, go to Digital doorbells > Use invite code to join.')}',
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(context.tr('Davet kodu kopyalandı.', 'Invite copied.'))));
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    final label = member['email']?.toString() ?? member['user_id'].toString();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr(
            'Erişim kaldırılsın mı?', 'Remove access?', 'Удалить доступ?')),
        content: Text(context.tr(
            '$label artık bu kapının bildirimlerini ve mesajlarını alamayacak.',
            '$label will no longer receive this door’s notifications or messages.',
            '$label больше не будет получать уведомления и сообщения этой двери.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('Vazgeç', 'Cancel', 'Отмена'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.tr(
                  'Erişimi kaldır', 'Remove access', 'Удалить доступ'))),
        ],
      ),
    );
    if (accepted != true) return;
    try {
      await ref.read(doqrApiProvider).removeDoorMember(
          doorId: widget.door.id, memberUserId: member['user_id'].toString());
      _reloadAccess();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userErrorMessage(error))));
      }
    }
  }

  Future<void> _revokeInvite(Map<String, dynamic> invite) async {
    try {
      await ref.read(doqrApiProvider).revokeDoorInvite(invite['id'].toString());
      _reloadAccess();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userErrorMessage(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canInvite = _additionalHosts > 0;
    return AppShell(
      title: context.tr('Kapı erişimi', 'Door access', 'Доступ к двери'),
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
                                'Bu kapı en fazla ${widget.door.plan.maxHostsPerDoor} kişi tarafından yönetilebilir.',
                                'This door can be managed by up to ${widget.door.plan.maxHostsPerDoor} people.',
                                'Этой дверью могут управлять до ${widget.door.plan.maxHostsPerDoor} человек.'),
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
                          'Davet edilen kişi kendi hesabıyla katılır ve bu kapı çaldığında bildirim alır. Davet tek kullanımlıktır.',
                          'An invited person joins with their own account and receives notifications when this door rings. Each invite can be used once.',
                          'Приглашённый пользователь присоединяется со своей учётной записью и получает уведомления о звонках. Приглашение одноразовое.')
                      : context.tr(
                          'Free plan kapıyı yalnızca sahibinin yönetmesini destekler. Eşinizle veya başka bir kişiyle paylaşmak için Pro gerekir.',
                          'The Free plan allows only the owner to manage the door. Pro is required to share it with a spouse or another person.',
                          'В Free дверью может управлять только владелец. Для совместного доступа требуется Pro.'),
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
                        'Bu kodu birlikte yöneteceğiniz kişiye güvenli bir kanaldan iletin.',
                        'Send this code to the person who will manage the door with you through a trusted channel.',
                        'Отправьте код доверенным способом человеку, который будет управлять дверью вместе с вами.'),
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
          const SizedBox(height: 14),
          FutureBuilder<Map<String, dynamic>>(
            future: _accessFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const ElevCard(
                    child: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return ElevCard(
                  child: Column(
                    children: [
                      Text(userErrorMessage(snapshot.error)),
                      TextButton(
                          onPressed: _reloadAccess,
                          child: Text(context.tr(
                              'Tekrar dene', 'Try again', 'Повторить'))),
                    ],
                  ),
                );
              }
              final members = (snapshot.data?['members'] as List? ?? const [])
                  .cast<Map<String, dynamic>>();
              final invites = (snapshot.data?['invites'] as List? ?? const [])
                  .cast<Map<String, dynamic>>();
              return ElevCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.tr('Erişimi olan kişiler', 'People with access',
                          'Пользователи с доступом'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    if (members.isEmpty)
                      Text(context.tr(
                          'Kapı sahibi dışında erişimi olan kimse yok.',
                          'No one except the door owner has access.',
                          'Доступ есть только у владельца двери.')),
                    for (final member in members)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                            child: Icon(Icons.person_outline_rounded)),
                        title: Text(member['email']?.toString() ??
                            context.tr('Paylaşılan kullanıcı', 'Shared user',
                                'Пользователь с доступом')),
                        subtitle: Text(context.tr(
                            'Bildirim ve mesaj erişimi',
                            'Notification and message access',
                            'Доступ к уведомлениям и сообщениям')),
                        trailing: IconButton(
                          tooltip: context.tr('Erişimi kaldır', 'Remove access',
                              'Удалить доступ'),
                          onPressed: () => _removeMember(member),
                          icon: const Icon(Icons.person_remove_outlined),
                        ),
                      ),
                    if (invites.isNotEmpty) ...[
                      const Divider(height: 28),
                      Text(
                        context.tr('Bekleyen davetler', 'Pending invites',
                            'Ожидающие приглашения'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      for (final invite in invites)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.mark_email_unread_outlined),
                          title: Text(context.tr('Kullanılmamış davet',
                              'Unused invite', 'Неиспользованное приглашение')),
                          subtitle: Text(_formatDate(
                              DateTime.parse(invite['expires_at'].toString()))),
                          trailing: IconButton(
                            tooltip: context.tr('Daveti iptal et',
                                'Revoke invite', 'Отозвать приглашение'),
                            onPressed: () => _revokeInvite(invite),
                            icon: const Icon(Icons.link_off_rounded),
                          ),
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
