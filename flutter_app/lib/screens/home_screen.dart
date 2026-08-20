import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_language.dart';
import '../models/door_item.dart';
import '../models/ring_item.dart';
import '../services/notification_service.dart';
import '../services/providers.dart';
import '../widgets/app_shell.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late Future<_HomeData> _future;
  Locale? _registeredLocale;
  PlanItem? _accountPlan;
  _HomeData? _lastData;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    if (_registeredLocale?.languageCode == locale.languageCode) return;
    _registeredLocale = locale;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      NotificationService.instance
          .startForUser(ref.read(doqrApiProvider), locale);
    });
  }

  Future<_HomeData> _load() async {
    final api = ref.read(doqrApiProvider);
    final results = await Future.wait([api.listDoors(), api.listRings()]);
    final data =
        _HomeData(results[0] as DoorListResult, results[1] as List<RingItem>);
    if (mounted) {
      setState(() {
        _accountPlan = data.doors.accountPlan;
        _lastData = data;
      });
    } else {
      _accountPlan = data.doors.accountPlan;
      _lastData = data;
    }
    return data;
  }

  String _homeTitle(BuildContext context) {
    final plan = _accountPlan;
    if (plan == null) return 'DOQR';
    if (plan.isTrial) {
      final endsAt = plan.trialEndsAt ?? plan.currentPeriodEnd;
      final days = endsAt == null
          ? 3
          : ((endsAt.difference(DateTime.now()).inHours + 23) ~/ 24)
              .clamp(0, 999);
      return context.isEnglish
          ? 'DOQR (Pro • $days days)'
          : 'DOQR (Pro • $days gün)';
    }
    return plan.isPro ? 'DOQR (Pro)' : 'DOQR (Free)';
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    await next;
  }

  Future<void> _signOut() async {
    await NotificationService.instance.stopForLogout();
    await Supabase.instance.client.auth.signOut();
  }

  Future<void> _deleteAccount() async {
    var accepted = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.delete_forever_rounded,
              color: Color(0xFFE54867), size: 36),
          title: Text(context.tr('DOQR hesabını sil?', 'Delete DOQR account?')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr(
                    'Dijital zillerin, QR bağlantıların, ziyaret geçmişin ve hesapla ilişkili verilerin kalıcı olarak silinir. Bu işlem geri alınamaz. Mağaza aboneliğin varsa ayrıca Google Play veya App Store’dan iptal etmelisin.',
                    'Your digital doorbells, QR links, visit history, and account-related data will be permanently deleted. This cannot be undone. If you have a store subscription, you must also cancel it in Google Play or the App Store.'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: accepted,
                onChanged: (value) =>
                    setDialogState(() => accepted = value == true),
                title: Text(context.tr('Kalıcı silme işlemini anlıyorum.',
                    'I understand this deletion is permanent.')),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.tr('Vazgeç', 'Cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE54867)),
              onPressed:
                  accepted ? () => Navigator.pop(dialogContext, true) : null,
              child: Text(context.tr('Hesabımı kalıcı olarak sil',
                  'Permanently delete my account')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await ref.read(doqrApiProvider).deleteAccount();
      await NotificationService.instance.stopForLogout();
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr('Hesap silinemedi. Lütfen tekrar dene.',
            'Account could not be deleted. Please try again.')),
      ));
    }
  }

  @override
  Widget build(BuildContext context) => AppShell(
        title: _homeTitle(context),
        actions: [
          IconButton(
            tooltip: context.tr('Ayarlar', 'Settings'),
            onPressed: () async {
              final plan = _accountPlan ?? (await _future).doors.accountPlan;
              if (!context.mounted) return;
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute<bool>(
                  builder: (_) => SettingsScreen(
                    plan: plan,
                    onDeleteAccount: _deleteAccount,
                    onSignOut: _signOut,
                  ),
                ),
              );
              if (changed == true && mounted) await _refresh();
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
        child: FutureBuilder<_HomeData>(
          future: _future,
          builder: (context, snapshot) {
            final data = snapshot.data ?? _lastData;
            if (data == null &&
                snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (data == null && snapshot.hasError) {
              return _ErrorState(
                  message: snapshot.error.toString(), retry: _refresh);
            }
            final homeData = data!;
            return Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      FilledButton.icon(
                        onPressed: () async {
                          await Navigator.pushNamed(context, '/doors');
                          if (mounted) _refresh();
                        },
                        icon: const Icon(Icons.door_front_door_rounded),
                        label: Text(context.tr('Dijital zillerim ve QR kodları',
                            'My digital doorbells and QR codes')),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                              child: SectionLabel(context.tr(
                                  'Son ziyaretçiler', 'Recent visitors'))),
                          Text(
                            homeData.doors.accountPlan.isPro
                                ? context.tr('Son 90 gün', 'Last 90 days')
                                : context.tr('Son 3 kayıt', 'Last 3 records'),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      if (homeData.rings.isEmpty)
                        ElevCard(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Column(
                              children: [
                                const Icon(Icons.notifications_none_rounded,
                                    size: 42, color: Color(0xFF94A3B8)),
                                const SizedBox(height: 10),
                                Text(context.tr(
                                    'Henüz ziyaretçi yok', 'No visitors yet')),
                                const SizedBox(height: 4),
                                Text(
                                    context.tr(
                                        'QR kodunuz tarandığında burada görünecek.',
                                        'Visitors will appear here when your QR code is scanned.'),
                                    style: const TextStyle(
                                        color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                        )
                      else
                        ...homeData.rings.map((ring) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _RingCard(
                                ring: ring,
                                doorLabel: homeData.doors.doors
                                    .where((door) => door.id == ring.doorId)
                                    .firstOrNull
                                    ?.label,
                                onTap: () async {
                                  await Navigator.pushNamed(context, '/ring',
                                      arguments: ring.id);
                                  if (mounted) _refresh();
                                },
                              ),
                            )),
                    ],
                  ),
                ),
                if (snapshot.connectionState != ConnectionState.done)
                  const Align(
                    alignment: Alignment.topCenter,
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
              ],
            );
          },
        ),
      );
}

// Retained only to preserve the old widget during the current source transition.
// The home screen no longer renders this plan summary.
// ignore: unused_element
class _PlanHeader extends StatelessWidget {
  final PlanItem plan;
  final VoidCallback onTap;

  const _PlanHeader({required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) => ElevCard(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: plan.isPro
                    ? const Color(0xFFFFF3C4)
                    : const Color(0xFFE0ECFF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(plan.isPro
                  ? Icons.workspace_premium_rounded
                  : Icons.qr_code_2_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      plan.isTrial
                          ? context.tr('Mevcut planın: Pro Deneme',
                              'Current plan: Pro Trial')
                          : context.tr('Mevcut planın: ${plan.displayName}',
                              'Current plan: ${plan.displayName}'),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(
                    plan.isTrial
                        ? context.tr(
                            '3 günlük Pro denemen aktif. Süre sona erdiğinde hesabın otomatik olarak Free plana geçecek.',
                            'Your 3-day Pro trial is active. Your account will automatically switch to Free when it ends.')
                        : plan.isPro
                            ? context.tr(
                                'Pro özelliklerin aktif • yıllık \$14.99',
                                'Pro features active • \$14.99/year')
                            : context.tr(
                                'Free planın aktif • Pro yıllık \$14.99',
                                'Free plan active • Pro \$14.99/year'),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('Free ve Pro planları karşılaştır',
                        'Compare Free and Pro plans'),
                    style: const TextStyle(
                      color: Color(0xFF2F6BFF),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 11),
              child:
                  Icon(Icons.chevron_right_rounded, color: Color(0xFF667085)),
            ),
          ],
        ),
      );
}

class _RingCard extends StatelessWidget {
  final RingItem ring;
  final String? doorLabel;
  final VoidCallback onTap;
  const _RingCard({required this.ring, required this.onTap, this.doorLabel});

  IconData get icon => switch (ring.activeMode) {
        'video' => Icons.videocam_rounded,
        'audio' => Icons.call_rounded,
        _ => Icons.chat_bubble_rounded,
      };

  @override
  Widget build(BuildContext context) => ElevCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: onTap,
          leading: CircleAvatar(child: Icon(icon)),
          title: Text(
              ring.visitorAlias ??
                  (ring.visitorKind == 'courier'
                      ? context.tr('Kurye', 'Courier')
                      : context.tr('Ziyaretçi', 'Visitor')),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${doorLabel ?? context.tr('Dijital zil', 'Doorbell')}'
              ' • ${_status(context, ring.status)} • ${_relative(context, ring.createdAt)}'),
          trailing: ring.status == 'pending'
              ? Chip(label: Text(context.tr('Çalıyor', 'Ringing')))
              : const Icon(Icons.chevron_right_rounded),
        ),
      );

  String _status(BuildContext context, String status) => switch (status) {
        'pending' => context.tr('Bekliyor', 'Pending'),
        'media_requested' => context.tr('Onay bekleniyor', 'Awaiting approval'),
        'accepted' => context.tr('Yanıtlandı', 'Accepted'),
        'declined' => context.tr('Reddedildi', 'Declined'),
        'missed' => context.tr('Cevapsız', 'Missed'),
        'cancelled' => context.tr('İptal edildi', 'Cancelled'),
        _ => context.tr('Sona erdi', 'Ended'),
      };

  String _relative(BuildContext context, DateTime value) {
    final difference = DateTime.now().difference(value.toLocal());
    if (difference.inMinutes < 1) return context.tr('şimdi', 'now');
    if (difference.inHours < 1) {
      return context.tr(
          '${difference.inMinutes} dk önce', '${difference.inMinutes} min ago');
    }
    if (difference.inDays < 1) {
      return context.tr(
          '${difference.inHours} sa önce', '${difference.inHours} hr ago');
    }
    return context.tr(
        '${difference.inDays} gün önce', '${difference.inDays} days ago');
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() retry;
  const _ErrorState({required this.message, required this.retry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 44),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: retry,
                child: Text(context.tr('Tekrar dene', 'Try again'))),
          ],
        ),
      );
}

class _HomeData {
  final DoorListResult doors;
  final List<RingItem> rings;
  const _HomeData(this.doors, this.rings);
}
