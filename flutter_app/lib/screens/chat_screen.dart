import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../l10n/app_language.dart';
import '../models/chat_message_item.dart';
import '../models/door_item.dart';
import '../models/ring_item.dart';
import '../services/media_session.dart';
import '../services/providers.dart';
import '../ui/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/closed_session_notice.dart';

class RingSessionScreen extends ConsumerStatefulWidget {
  final String ringId;
  const RingSessionScreen({super.key, required this.ringId});

  @override
  ConsumerState<RingSessionScreen> createState() => _RingSessionScreenState();
}

class _RingSessionScreenState extends ConsumerState<RingSessionScreen> {
  final input = TextEditingController();
  RingItem? ring;
  PlanItem? _doorPlan;
  Object? loadError;
  bool busy = false;
  StreamSubscription<List<RingItem>>? ringSubscription;
  MediaSessionController? media;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(doqrApiProvider);
      final item = await api.getRing(widget.ringId);
      final doors = await api.listDoors();
      final plan = doors.doors
              .where((door) => door.id == item.doorId)
              .firstOrNull
              ?.plan ??
          doors.accountPlan;
      if (!mounted) return;
      setState(() {
        ring = item;
        _doorPlan = plan;
      });
      _ensureMedia(item);
      ringSubscription = api.watchRing(widget.ringId).listen((items) {
        if (!mounted || items.isEmpty) return;
        setState(() => ring = items.first);
        _ensureMedia(items.first);
      });
    } catch (error) {
      if (mounted) setState(() => loadError = error);
    }
  }

  void _ensureMedia(RingItem item) {
    if (item.status != 'accepted' || !item.usesMedia) {
      final current = media;
      if (current != null) {
        current.removeListener(_mediaChanged);
        media = null;
        current.dispose();
      }
      return;
    }
    if (media != null) return;
    media = MediaSessionController(
      client: ref.read(supabaseProvider),
      api: ref.read(doqrApiProvider),
      ringId: item.id,
      video: item.activeMode == 'video',
      onSessionLimitReached: _endForSessionLimit,
    )..addListener(_mediaChanged);
    media!.startAsHost();
    setState(() {});
  }

  void _mediaChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _endForSessionLimit() async {
    if (!mounted || busy || ring?.status != 'accepted') return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr('1 dakikalık görüntülü görüşme süresi doldu.',
            'The 1-minute video call limit has ended.'))));
    await _action('end');
  }

  Future<void> _action(String action, {String? mode}) async {
    setState(() => busy = true);
    try {
      final updated = await ref
          .read(doqrApiProvider)
          .ringAction(ringId: widget.ringId, action: action, mode: mode);
      if (mounted) {
        setState(() => ring = updated);
        _ensureMedia(updated);
        if (action == 'decline' || action == 'end') Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _send() async {
    if (ring?.isActive != true) return;
    final text = input.text.trim();
    if (text.isEmpty) return;
    input.clear();
    try {
      await ref
          .read(doqrApiProvider)
          .sendHostMessage(ringId: widget.ringId, message: text);
    } catch (error) {
      input.text = text;
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _showAnswerOptions() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.tr('Nasıl yanıtlamak istersiniz?',
                  'How would you like to answer?'),
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                context.tr(
                    'Sesli veya görüntülü görüşmede ziyaretçiden önce onay istenir.',
                    'For voice or video, the visitor is asked for approval first.'),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, 'text'),
                icon: const Icon(Icons.chat_bubble_rounded),
                label: Text(context.tr('Mesajlaşmayla yanıtla', 'Answer by chat')),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, 'audio'),
                icon: const Icon(Icons.call_rounded),
                label: Text(context.tr('Sesli görüşme iste', 'Request voice call')),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, 'video'),
                icon: const Icon(Icons.videocam_rounded),
                label: Text(context.tr('Görüntülü görüşme iste',
                    'Request video call')),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null) return;
    await _action(choice == 'text' ? 'accept' : 'request_media',
        mode: choice == 'text' ? null : choice);
  }

  Future<void> _shareCourierCode() async {
    setState(() => busy = true);
    try {
      await ref
          .read(doqrApiProvider)
          .ringAction(ringId: widget.ringId, action: 'reveal_note');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.tr(
                'Teslimat kodu bu ziyaretçiyle paylaşıldı.',
                'The delivery code was shared with this visitor.'))));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _blockVisitor() async {
    final scope = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.tr('Ziyaretçiyi engelle', 'Block visitor'),
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                  context.tr(
                      'Cihaz engeli önerilir. Ağ engeli aynı Wi-Fi ağındaki başka kişileri de etkileyebilir.',
                      'Device blocking is recommended. Network blocking may also affect other people on the same Wi-Fi network.'),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.muted)),
              const SizedBox(height: 18),
              FilledButton.icon(
                  onPressed: () => Navigator.pop(context, 'device'),
                  icon: const Icon(Icons.phonelink_erase_rounded),
                  label: Text(context.tr('Bu cihazı kalıcı engelle',
                      'Permanently block this device'))),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context, 'network'),
                  icon: const Icon(Icons.wifi_off_rounded),
                  label: Text(context.tr('Bu ağı 24 saat engelle',
                      'Block this network for 24 hours'))),
              const SizedBox(height: 10),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.tr('Vazgeç', 'Cancel'))),
            ],
          ),
        ),
      ),
    );
    if (scope == null) return;
    try {
      await ref
          .read(doqrApiProvider)
          .blockVisitor(ringId: widget.ringId, scope: scope);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.tr('Engel kaydedildi.', 'Block saved.'))));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  void _showSecurityInfo() {
    final metadata = ring?.clientMetadata ?? const {};
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('Güvenlik bilgileri', 'Security information'),
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                  context.tr(
                      'Bu bilgiler ziyaretçiye önceden açıklanır. Kimlik doğrulamaz; kötüye kullanım incelemesine yardımcı olur.',
                      'This information is disclosed to the visitor in advance. It does not verify identity; it helps investigate misuse.'),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.muted)),
              const SizedBox(height: 16),
              _InfoRow(
                  context.tr('Platform', 'Platform'),
                  metadata['platform']?.toString() ??
                      context.tr('Bilinmiyor', 'Unknown')),
              _InfoRow(
                  context.tr('Dil', 'Language'),
                  metadata['language']?.toString() ??
                      context.tr('Bilinmiyor', 'Unknown')),
              _InfoRow(
                  context.tr('Saat dilimi', 'Time zone'),
                  metadata['timezone']?.toString() ??
                      context.tr('Bilinmiyor', 'Unknown')),
              _InfoRow(
                  context.tr('Ekran', 'Screen'),
                  metadata['screen']?.toString() ??
                      context.tr('Bilinmiyor', 'Unknown')),
              _InfoRow(
                  context.tr('İşlemci iş parçacığı', 'Hardware threads'),
                  metadata['hardware_concurrency']?.toString() ??
                      context.tr('Bilinmiyor', 'Unknown')),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    input.dispose();
    ringSubscription?.cancel();
    media?.removeListener(_mediaChanged);
    media?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loadError != null) {
      return AppShell(
          title: context.tr('Ziyaret', 'Visit'),
          child: Center(child: Text(loadError.toString())));
    }
    final item = ring;
    if (item == null) {
      return AppShell(
          title: context.tr('Ziyaret', 'Visit'),
          child: const Center(child: CircularProgressIndicator()));
    }
    final compact = MediaQuery.viewInsetsOf(context).bottom > 0 ||
        MediaQuery.sizeOf(context).height < 650;
    return AppShell(
      title: item.visitorAlias ??
          (item.visitorKind == 'courier'
              ? context.tr('Kurye ziyareti', 'Courier visit')
              : context.tr('Ziyaretçi', 'Visitor')),
      actions: [
        IconButton(
            tooltip: context.tr('Güvenlik bilgileri', 'Security information'),
            onPressed: _showSecurityInfo,
            icon: const Icon(Icons.shield_outlined)),
        if (_doorPlan?.has('visitor_blocking') == true)
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'block') _blockVisitor();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'block',
                  child: Text(
                      context.tr('Ziyaretçiyi engelle', 'Block visitor')))
            ],
          ),
      ],
      child: Column(
        children: [
          if (!compact) _SessionHero(ring: item),
          if (item.visitorKind == 'courier') ...[
            const SizedBox(height: 10),
            ElevCard(
              color: const Color(0xFFF1F5FF),
              child: Row(
                children: [
                  const SoftIcon(Icons.local_shipping_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(
                          context.tr(
                              '${item.courierCode ?? 'Kurye'} seçimi ziyaretçinin kendi beyanıdır.',
                              'The ${item.courierCode ?? 'Courier'} selection is provided by the visitor.'),
                          style: Theme.of(context).textTheme.bodyMedium)),
                  if (item.courierNoteId != null)
                    TextButton(
                        onPressed: busy ? null : _shareCourierCode,
                        child: Text(context.tr('Kodu paylaş', 'Share code'))),
                ],
              ),
            ),
          ],
          if (item.status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: busy ? null : () => _action('decline'),
                        icon: const Icon(Icons.close_rounded),
                        label: Text(context.tr('Reddet', 'Decline')))),
                const SizedBox(width: 10),
                Expanded(
                    child: FilledButton.icon(
                        onPressed: busy ? null : _showAnswerOptions,
                        icon: const Icon(Icons.reply_rounded),
                        label: Text(context.tr('Yanıtla', 'Answer')))),
              ],
            ),
          ],
          if (item.status == 'media_requested') ...[
            const SizedBox(height: 12),
            ElevCard(
              color: const Color(0xFFF1F5FF),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.tr('Ziyaretçi onayı bekleniyor',
                        'Waiting for visitor approval'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    context.tr(
                        'Ziyaretçi ${_modeLabel(context, item.activeMode).toLowerCase()} isteğini kabul ettiğinde görüşme başlar.',
                        'The call starts when the visitor accepts the ${_modeLabel(context, item.activeMode).toLowerCase()} request.'),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => _action('end'),
                    icon: const Icon(Icons.close_rounded),
                    label: Text(context.tr('İsteği iptal et', 'Cancel request')),
                  ),
                ],
              ),
            ),
          ],
          if (item.status == 'accepted' && item.usesMedia) ...[
            const SizedBox(height: 12),
            _MediaPanel(
                controller: media,
                video: item.activeMode == 'video',
                compact: compact,
                onEnd: () => _action('end')),
          ],
          SizedBox(height: compact ? 6 : 14),
          if (item.isActive)
            Expanded(
                child: _ChatPanel(ringId: item.id, input: input, onSend: _send))
          else
            const ClosedSessionNotice(),
        ],
      ),
    );
  }
}

IconData _modeIcon(String mode) => switch (mode) {
      'video' => Icons.videocam_rounded,
      'audio' => Icons.call_rounded,
      _ => Icons.chat_bubble_rounded,
    };

String _modeLabel(BuildContext context, String mode) => switch (mode) {
      'video' => context.tr('Görüntülü görüşme', 'Video call'),
      'audio' => context.tr('Sesli görüşme', 'Voice call'),
      _ => context.tr('Yazılı görüşme', 'Text chat'),
    };

class _SessionHero extends StatelessWidget {
  final RingItem ring;
  const _SessionHero({required this.ring});

  @override
  Widget build(BuildContext context) => ElevCard(
        gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.navy, Color(0xFF213B82)]),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(19)),
              child: Icon(_modeIcon(ring.activeMode),
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_modeLabel(context, ring.activeMode),
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(_statusLabel(context, ring.status),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: const Color(0xFFC7D5FF))),
                ],
              ),
            ),
            if (ring.status == 'pending')
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: AppColors.cyan,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: AppColors.cyan, blurRadius: 14)
                    ]),
              ),
          ],
        ),
      );

  String _modeLabel(BuildContext context, String mode) => switch (mode) {
        'video' => context.tr('Görüntülü görüşme', 'Video call'),
        'audio' => context.tr('Sesli görüşme', 'Audio call'),
        _ => context.tr('Yazılı görüşme', 'Text chat')
      };
  String _statusLabel(BuildContext context, String status) => switch (status) {
        'pending' => context.tr('Zil çalıyor…', 'Ringing…'),
        'media_requested' =>
          context.tr('Ziyaretçi onayı bekleniyor', 'Waiting for visitor approval'),
        'accepted' => context.tr('Görüşme aktif', 'Call active'),
        'declined' => context.tr('Reddedildi', 'Declined'),
        'missed' => context.tr('Cevapsız ziyaret', 'Missed visit'),
        'cancelled' => context.tr('Ziyaretçi iptal etti', 'Visitor cancelled'),
        _ => context.tr('Görüşme sona erdi', 'Call ended'),
      };
}

class _MediaPanel extends StatelessWidget {
  final MediaSessionController? controller;
  final bool video;
  final bool compact;
  final VoidCallback onEnd;
  const _MediaPanel(
      {required this.controller,
      required this.video,
      required this.compact,
      required this.onEnd});

  @override
  Widget build(BuildContext context) {
    final media = controller;
    if (media == null || !media.started) {
      return const ElevCard(child: Center(child: CircularProgressIndicator()));
    }
    if (media.error != null) {
      return ElevCard(
          child: Text(media.error!,
              style: const TextStyle(color: AppColors.danger)));
    }
    return ElevCard(
      padding: const EdgeInsets.all(10),
      color: AppColors.ink,
      child: Column(
        children: [
          if (video)
            SizedBox(
              height: compact ? 150 : 245,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RTCVideoView(media.remoteRenderer,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                    Positioned(
                      right: 10,
                      top: 10,
                      width: compact ? 62 : 88,
                      height: compact ? 82 : 118,
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: RTCVideoView(media.localRenderer,
                              mirror: true,
                              objectFit: RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitCover)),
                    ),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                            color: AppColors.ink.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(99)),
                        child: Text(
                          _formatRemaining(context, media.remainingSeconds),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontFeatures: [FontFeature.tabularFigures()]),
                        ),
                      ),
                    ),
                    if (!media.connected)
                      const Center(child: _ConnectingLabel()),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: compact ? 86 : 132,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.graphic_eq_rounded,
                        color: AppColors.cyan, size: 50),
                    const SizedBox(height: 8),
                    Text(
                        media.connected
                            ? context.tr('Bağlandı', 'Connected')
                            : context.tr('Bağlanıyor…', 'Connecting…'),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: Colors.white)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RoundControl(
                  icon: media.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  onTap: media.toggleMute),
              if (video) ...[
                const SizedBox(width: 12),
                _RoundControl(
                    icon: media.cameraEnabled
                        ? Icons.videocam_rounded
                        : Icons.videocam_off_rounded,
                    onTap: media.toggleCamera),
              ],
              const SizedBox(width: 12),
              _RoundControl(
                  icon: Icons.call_end_rounded,
                  color: AppColors.danger,
                  onTap: onEnd),
            ],
          ),
        ],
      ),
    );
  }

  String _formatRemaining(BuildContext context, int? value) {
    final seconds = (value ?? 60).clamp(0, 60);
    return context.tr(
        'En fazla 1 dk · 00:${seconds.toString().padLeft(2, '0')}',
        'Up to 1 min · 00:${seconds.toString().padLeft(2, '0')}');
  }
}

class _ConnectingLabel extends StatelessWidget {
  const _ConnectingLabel();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
            color: AppColors.ink.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(99)),
        child: Text(context.tr('Bağlanıyor…', 'Connecting…'),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
      );
}

class _RoundControl extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  const _RoundControl(
      {required this.icon,
      required this.onTap,
      this.color = const Color(0xFF2A3553)});
  @override
  Widget build(BuildContext context) => IconButton.filled(
      onPressed: onTap,
      style: IconButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          fixedSize: const Size(48, 48)),
      icon: Icon(icon));
}

class _ChatPanel extends ConsumerWidget {
  final String ringId;
  final TextEditingController input;
  final Future<void> Function() onSend;
  const _ChatPanel(
      {required this.ringId, required this.input, required this.onSend});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessageItem>>(
              stream: ref.read(doqrApiProvider).watchChat(ringId),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? const <ChatMessageItem>[];
                if (messages.isEmpty) {
                  return Center(
                      child: Text(
                          context.tr('Mesajlaşmayı başlatın',
                              'Start the conversation'),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.muted)));
                }
                return ListView.separated(
                  reverse: true,
                  itemCount: messages.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, reverseIndex) {
                    final message =
                        messages[messages.length - reverseIndex - 1];
                    final host = message.senderType == 'host';
                    final system = message.senderType == 'system';
                    return Align(
                      alignment: system
                          ? Alignment.center
                          : (host
                              ? Alignment.centerRight
                              : Alignment.centerLeft),
                      child: Container(
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.76),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 15, vertical: 11),
                        decoration: BoxDecoration(
                          color: system
                              ? const Color(0xFFEAF0FF)
                              : (host ? AppColors.blue : Colors.white),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: Radius.circular(host ? 18 : 5),
                            bottomRight: Radius.circular(host ? 5 : 18),
                          ),
                          border:
                              host ? null : Border.all(color: AppColors.line),
                        ),
                        child: Text(message.text,
                            style: TextStyle(
                                color: host ? Colors.white : AppColors.ink,
                                fontWeight: FontWeight.w600)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: input,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                      hintText: context.tr('Mesaj yazın…', 'Write a message…'),
                      prefixIcon:
                          const Icon(Icons.chat_bubble_outline_rounded)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                  onPressed: onSend,
                  style: IconButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      foregroundColor: Colors.white,
                      fixedSize: const Size(54, 54)),
                  icon: const Icon(Icons.arrow_upward_rounded)),
            ],
          ),
        ],
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Expanded(
              child:
                  Text(label, style: const TextStyle(color: AppColors.muted))),
          Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w700)))
        ]),
      );
}
