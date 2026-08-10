import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/door_item.dart';
import '../models/ring_item.dart';
import '../services/notification_service.dart';
import '../services/providers.dart';
import '../widgets/app_shell.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late Future<_HomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.startForUser(
          ref.read(doqrApiProvider), Localizations.localeOf(context));
    });
  }

  Future<_HomeData> _load() async {
    final api = ref.read(doqrApiProvider);
    final results = await Future.wait([api.listDoors(), api.listRings()]);
    return _HomeData(
        results[0] as DoorListResult, results[1] as List<RingItem>);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    await next;
  }

  @override
  Widget build(BuildContext context) => AppShell(
        title: 'DOQR',
        actions: [
          IconButton(
            tooltip: 'Çıkış yap',
            onPressed: () async {
              await NotificationService.instance.stopForLogout();
              await Supabase.instance.client.auth.signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
        child: FutureBuilder<_HomeData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorState(
                  message: snapshot.error.toString(), retry: _refresh);
            }
            final data = snapshot.requireData;
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _PlanHeader(plan: data.doors.accountPlan),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () async {
                      await Navigator.pushNamed(context, '/doors');
                      if (mounted) _refresh();
                    },
                    icon: const Icon(Icons.door_front_door_rounded),
                    label: const Text('Dijital zillerim ve QR kodları'),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Expanded(child: SectionLabel('Son ziyaretçiler')),
                      Text(
                        data.doors.accountPlan.isPro
                            ? 'Son 90 gün'
                            : 'Son 3 kayıt',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  if (data.rings.isEmpty)
                    const ElevCard(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            Icon(Icons.notifications_none_rounded,
                                size: 42, color: Color(0xFF94A3B8)),
                            SizedBox(height: 10),
                            Text('Henüz ziyaretçi yok'),
                            SizedBox(height: 4),
                            Text('QR kodunuz tarandığında burada görünecek.',
                                style: TextStyle(color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    )
                  else
                    ...data.rings.map((ring) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _RingCard(
                            ring: ring,
                            doorLabel: data.doors.doors
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
            );
          },
        ),
      );
}

class _PlanHeader extends StatelessWidget {
  final PlanItem plan;
  const _PlanHeader({required this.plan});

  @override
  Widget build(BuildContext context) => ElevCard(
        child: Row(
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
                  Text('${plan.displayName} plan',
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    plan.isTrial
                        ? '3 günlük Pro denemesi • ses, görüntü ve kurye notları açık'
                        : plan.isPro
                            ? 'Ses, görüntü, kurye notları ve 90 günlük geçmiş'
                            : 'FCM + yazı ücretsiz • Pro yıllık \$9.99: ses, video ve 90 gün',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: const Color(0xFF64748B)),
                  ),
                ],
              ),
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

  IconData get icon => switch (ring.requestedMode) {
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
                  (ring.visitorKind == 'courier' ? 'Kurye' : 'Ziyaretçi'),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
              '${doorLabel ?? 'Dijital zil'} • ${ring.status} • ${_relative(ring.createdAt)}'),
          trailing: ring.status == 'pending'
              ? const Chip(label: Text('Çalıyor'))
              : const Icon(Icons.chevron_right_rounded),
        ),
      );

  String _relative(DateTime value) {
    final difference = DateTime.now().difference(value.toLocal());
    if (difference.inMinutes < 1) return 'şimdi';
    if (difference.inHours < 1) return '${difference.inMinutes} dk önce';
    if (difference.inDays < 1) return '${difference.inHours} sa önce';
    return '${difference.inDays} gün önce';
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
            OutlinedButton(onPressed: retry, child: const Text('Tekrar dene')),
          ],
        ),
      );
}

class _HomeData {
  final DoorListResult doors;
  final List<RingItem> rings;
  const _HomeData(this.doors, this.rings);
}
