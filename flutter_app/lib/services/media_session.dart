import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_language.dart';
import 'doqr_api.dart';

String mediaSessionErrorMessage(Object exception) {
  if (exception is FunctionException) {
    final details = exception.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    if (exception.status >= 500 || exception.status == 0) {
      return appText(
          'Görüşme altyapısına şu anda ulaşılamıyor. Lütfen tekrar deneyin.',
          'The calling service is currently unavailable. Please try again.');
    }
  }
  return appText('Görüşme başlatılamadı. Lütfen tekrar deneyin.',
      'The call could not be started. Please try again.');
}

class MediaSessionController extends ChangeNotifier {
  final SupabaseClient client;
  final DoqrApi api;
  final String ringId;
  final bool video;
  final Future<void> Function()? onSessionLimitReached;

  final localRenderer = RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peer;
  MediaStream? _localStream;
  StreamSubscription<List<Map<String, dynamic>>>? _signalSubscription;
  bool _remoteDescriptionSet = false;
  bool _started = false;
  bool _muted = false;
  bool _cameraEnabled = true;
  bool _connected = false;
  bool _closed = false;
  bool _limitReached = false;
  bool _disposed = false;
  int? _remainingSeconds;
  Timer? _deadlineTimer;
  Timer? _countdownTimer;
  String? _error;

  MediaSessionController(
      {required this.client,
      required this.api,
      required this.ringId,
      required this.video,
      this.onSessionLimitReached});

  bool get muted => _muted;
  bool get cameraEnabled => _cameraEnabled;
  bool get connected => _connected;
  bool get started => _started;
  bool get limitReached => _limitReached;
  int? get remainingSeconds => _remainingSeconds;
  String? get error => _error;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> startAsHost() async {
    if (_started) return;
    _started = true;
    try {
      await localRenderer.initialize();
      await remoteRenderer.initialize();
      final rtcConfig = await api.rtcConfig(ringId);
      if (video) _scheduleDeadline(rtcConfig.mediaDeadline);
      _peer = await createPeerConnection(
          {'iceServers': rtcConfig.iceServers, 'sdpSemantics': 'unified-plan'});
      _peer!.onConnectionState = (state) {
        _connected =
            state == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          _error = appText('Görüşme bağlantısı kurulamadı.',
              'The call connection could not be established.');
        }
        _notify();
      };
      _peer!.onTrack = (event) {
        if (!_disposed && event.streams.isNotEmpty) {
          remoteRenderer.srcObject = event.streams.first;
        }
        _notify();
      };

      _signalSubscription = client
          .from('webrtc_signals')
          .stream(primaryKey: ['ring_id'])
          .eq('ring_id', ringId)
          .listen(_onSignalRows, onError: (Object error) {
            _error = appText(
                'Görüşme sinyali alınamadı. Lütfen tekrar deneyin.',
                'The call signal could not be received. Please try again.');
            _notify();
          });

      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true
        },
        'video': video
            ? {
                'facingMode': 'user',
                'width': {'ideal': 1280},
                'height': {'ideal': 720}
              }
            : false,
      });
      localRenderer.srcObject = _localStream;
      for (final track in _localStream!.getTracks()) {
        await _peer!.addTrack(track, _localStream!);
      }
      final offer = await _peer!.createOffer(
          {'offerToReceiveAudio': true, 'offerToReceiveVideo': video});
      await _peer!.setLocalDescription(offer);
      await _waitForIceGathering(_peer!);
      final completeOffer = await _peer!.getLocalDescription();
      if (completeOffer?.sdp == null || completeOffer!.sdp!.isEmpty) {
        throw StateError(appText('WebRTC teklifi oluşturulamadı.',
            'The WebRTC offer could not be created.'));
      }
      await client.from('webrtc_signals').insert({
        'ring_id': ringId,
        'offer_type': completeOffer.type ?? 'offer',
        'offer_sdp': completeOffer.sdp,
      });
      _notify();
    } catch (exception) {
      _error = mediaSessionErrorMessage(exception);
      _notify();
    }
  }

  void _scheduleDeadline(DateTime? serverDeadline) {
    final deadline = serverDeadline ??
        DateTime.now().toUtc().add(const Duration(seconds: 60));

    void updateRemaining() {
      final milliseconds =
          deadline.difference(DateTime.now().toUtc()).inMilliseconds;
      _remainingSeconds = milliseconds <= 0
          ? 0
          : (milliseconds / Duration.millisecondsPerSecond).ceil();
      _notify();
    }

    updateRemaining();
    final delay = deadline.difference(DateTime.now().toUtc());
    if (delay <= Duration.zero) {
      unawaited(_expireAtLimit());
      return;
    }
    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => updateRemaining());
    _deadlineTimer = Timer(delay, () => unawaited(_expireAtLimit()));
  }

  Future<void> _expireAtLimit() async {
    if (_limitReached || _closed) return;
    _limitReached = true;
    _remainingSeconds = 0;
    _notify();
    await close();
    await onSessionLimitReached?.call();
  }

  void _onSignalRows(List<Map<String, dynamic>> rows) {
    if (_remoteDescriptionSet || _closed || rows.isEmpty) return;
    final row = rows.first;
    if (row['answer_sdp'] is! String) return;
    unawaited(_applyAnswer(row));
  }

  Future<void> _applyAnswer(Map<String, dynamic> body) async {
    final peer = _peer;
    if (peer == null) return;
    await peer.setRemoteDescription(
      RTCSessionDescription(body['answer_sdp'] as String,
          body['answer_type'] as String? ?? 'answer'),
    );
    _remoteDescriptionSet = true;
    _notify();
  }

  Future<void> _waitForIceGathering(RTCPeerConnection peer) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!_closed && DateTime.now().isBefore(deadline)) {
      final state = await peer.getIceGatheringState();
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  void toggleMute() {
    _muted = !_muted;
    for (final track
        in _localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !_muted;
    }
    _notify();
  }

  void toggleCamera() {
    _cameraEnabled = !_cameraEnabled;
    for (final track
        in _localStream?.getVideoTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = _cameraEnabled;
    }
    _notify();
  }

  Future<void> close({bool notifyPeer = true}) async {
    if (_closed) return;
    _closed = true;
    _deadlineTimer?.cancel();
    _countdownTimer?.cancel();
    for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      track.stop();
    }
    await _localStream?.dispose();
    await _peer?.close();
    await _signalSubscription?.cancel();
    if (!_disposed) {
      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;
    }
    _connected = false;
    _remoteDescriptionSet = false;
    _notify();
  }

  @override
  void dispose() {
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    _disposed = true;
    unawaited(close(notifyPeer: false));
    localRenderer.dispose();
    remoteRenderer.dispose();
    super.dispose();
  }
}
