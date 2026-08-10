import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../models/chat_message_item.dart';
import '../models/ring_item.dart';
import '../services/media_session.dart';
import '../services/providers.dart';
import '../ui/app_theme.dart';
import '../widgets/app_shell.dart';

class RingSessionScreen extends ConsumerStatefulWidget {
  final String ringId;
  const RingSessionScreen({super.key, required this.ringId});

  @override
  ConsumerState<RingSessionScreen> createState() => _RingSessionScreenState();
}

class _RingSessionScreenState extends ConsumerState<RingSessionScreen> {
  final input = TextEditingController();
  RingItem? ring;
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
      if (!mounted) return;
      setState(() => ring = item);
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
    if (item.status != 'accepted' || !item.usesMedia || media != null) return;
    media = MediaSessionController(
      client: ref.read(supabaseProvider),
      api: ref.read(doqrApiProvider),
      ringId: item.id,
      video: item.requestedMode == 'video',
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('1 dakikalık görüntülü görüşme süresi doldu.')));
    await _action('end');
  }

  Future<void> _action(String action) async {
    setState(() => busy = true);
    try {
      final updated = await ref
          .read(doqrApiProvider)
          .ringAction(ringId: widget.ringId, action: action);
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

  Future<void> _shareCourierNote() async {
    setState(() => busy = true);
    try {
      await ref
          .read(doqrApiProvider)
          .ringAction(ringId: widget.ringId, action: 'reveal_note');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Hazır kurye notu bu ziyaretçiyle paylaşıldı.')));
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
              Text('Ziyaretçiyi engelle',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                  'Cihaz engeli önerilir. Ağ engeli aynı Wi-Fi ağındaki başka kişileri de etkileyebilir.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.muted)),
              const SizedBox(height: 18),
              FilledButton.icon(
                  onPressed: () => Navigator.pop(context, 'device'),
                  icon: const Icon(Icons.phonelink_erase_rounded),
                  label: const Text('Bu cihazı kalıcı engelle')),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context, 'network'),
                  icon: const Icon(Icons.wifi_off_rounded),
                  label: const Text('Bu ağı 24 saat engelle')),
              const SizedBox(height: 10),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Vazgeç')),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Engel kaydedildi.')));
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
              Text('Güvenlik bilgileri',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                  'Bu bilgiler ziyaretçiye önceden açıklanır. Kimlik doğrulamaz; kötüye kullanım incelemesine yardımcı olur.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.muted)),
              const SizedBox(height: 16),
              _InfoRow(
                  'Platform', metadata['platform']?.toString() ?? 'Bilinmiyor'),
              _InfoRow('Dil', metadata['language']?.toString() ?? 'Bilinmiyor'),
              _InfoRow('Saat dilimi',
                  metadata['timezone']?.toString() ?? 'Bilinmiyor'),
              _InfoRow('Ekran', metadata['screen']?.toString() ?? 'Bilinmiyor'),
              _InfoRow('İşlemci iş parçacığı',
                  metadata['hardware_concurrency']?.toString() ?? 'Bilinmiyor'),
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
          title: 'Ziyaret', child: Center(child: Text(loadError.toString())));
    }
    final item = ring;
    if (item == null) {
      return const AppShell(
          title: 'Ziyaret', child: Center(child: CircularProgressIndicator()));
    }
    final compact = MediaQuery.viewInsetsOf(context).bottom > 0 ||
        MediaQuery.sizeOf(context).height < 650;
    return AppShell(
      title: item.visitorAlias ??
          (item.visitorKind == 'courier' ? 'Kurye ziyareti' : 'Ziyaretçi'),
      actions: [
        IconButton(
            tooltip: 'Güvenlik bilgileri',
            onPressed: _showSecurityInfo,
            icon: const Icon(Icons.shield_outlined)),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'block') _blockVisitor();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'block', child: Text('Ziyaretçiyi engelle'))
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
                          '${item.courierCode ?? 'Kurye'} seçimi ziyaretçinin kendi beyanıdır.',
                          style: Theme.of(context).textTheme.bodyMedium)),
                  if (item.courierNoteId != null)
                    TextButton(
                        onPressed: busy ? null : _shareCourierNote,
                        child: const Text('Notu paylaş')),
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
                        label: const Text('Reddet'))),
                const SizedBox(width: 10),
                Expanded(
                    child: FilledButton.icon(
                        onPressed: busy ? null : () => _action('accept'),
                        icon: Icon(_modeIcon(item.requestedMode)),
                        label: const Text('Yanıtla'))),
              ],
            ),
          ],
          if (item.status == 'accepted' && item.usesMedia) ...[
            const SizedBox(height: 12),
            _MediaPanel(
                controller: media,
                video: item.requestedMode == 'video',
                compact: compact,
                onEnd: () => _action('end')),
          ],
          SizedBox(height: compact ? 6 : 14),
          Expanded(
              child: _ChatPanel(ringId: item.id, input: input, onSend: _send)),
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
              child: Icon(_modeIcon(ring.requestedMode),
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_modeLabel(ring.requestedMode),
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(_statusLabel(ring.status),
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

  String _modeLabel(String mode) => switch (mode) {
        'video' => 'Görüntülü görüşme',
        'audio' => 'Sesli görüşme',
        _ => 'Yazılı görüşme'
      };
  String _statusLabel(String status) => switch (status) {
        'pending' => 'Yanıtınızı bekliyor',
        'accepted' => 'Görüşme aktif',
        'declined' => 'Reddedildi',
        'missed' => 'Cevapsız ziyaret',
        'cancelled' => 'Ziyaretçi iptal etti',
        _ => 'Görüşme sona erdi',
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
                          _formatRemaining(media.remainingSeconds),
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
                    Text(media.connected ? 'Bağlandı' : 'Bağlanıyor…',
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

  String _formatRemaining(int? value) {
    final seconds = (value ?? 60).clamp(0, 60);
    return 'En fazla 1 dk · 00:${seconds.toString().padLeft(2, '0')}';
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
        child: const Text('Bağlanıyor…',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
                      child: Text('Mesajlaşmayı başlatın',
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
                  decoration: const InputDecoration(
                      hintText: 'Mesaj yazın…',
                      prefixIcon: Icon(Icons.chat_bubble_outline_rounded)),
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
