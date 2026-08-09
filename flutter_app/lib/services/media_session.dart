import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'doqr_api.dart';

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
  RealtimeChannel? _channel;
  final List<RTCIceCandidate> _pendingRemoteCandidates = [];
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
          _error = 'Görüşme bağlantısı kurulamadı.';
        }
        _notify();
      };
      _peer!.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          remoteRenderer.srcObject = event.streams.first;
        }
        _notify();
      };

      final subscribed = Completer<void>();
      _channel = client
          .channel('ring:$ringId',
              opts: const RealtimeChannelConfig(private: true, ack: true))
          .onBroadcast(event: 'webrtc_answer', callback: _onAnswer)
          .onBroadcast(event: 'webrtc_ice', callback: _onIce)
          .onBroadcast(
              event: 'webrtc_hangup',
              callback: (_) => close(notifyPeer: false));
      _channel!.subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed &&
            !subscribed.isCompleted) {
          subscribed.complete();
        } else if ((status == RealtimeSubscribeStatus.channelError ||
                status == RealtimeSubscribeStatus.timedOut) &&
            !subscribed.isCompleted) {
          subscribed.completeError(
              error ?? StateError('Realtime kanalına bağlanılamadı.'));
        }
      });
      await subscribed.future.timeout(const Duration(seconds: 12));

      _peer!.onIceCandidate = (candidate) {
        if (candidate.candidate == null) return;
        unawaited(_sendIce(candidate));
      };

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
      await _channel!.sendBroadcastMessage(event: 'webrtc_offer', payload: {
        'from': 'host',
        'sdp': offer.sdp,
        'type': offer.type,
        'video': video,
      });
      _notify();
    } catch (exception) {
      _error = exception.toString();
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

  Map<String, dynamic> _body(Map<String, dynamic> payload) {
    final nested = payload['payload'];
    return nested is Map ? Map<String, dynamic>.from(nested) : payload;
  }

  void _onAnswer(Map<String, dynamic> payload) {
    final body = _body(payload);
    if (body['from'] != 'visitor' || body['sdp'] is! String) return;
    unawaited(_applyAnswer(body));
  }

  void _onIce(Map<String, dynamic> payload) {
    final body = _body(payload);
    if (body['from'] != 'visitor' || body['candidate'] is! String) return;
    unawaited(_applyIce(body));
  }

  Future<void> _sendIce(RTCIceCandidate candidate) async {
    final channel = _channel;
    if (channel == null) return;
    await channel.sendBroadcastMessage(event: 'webrtc_ice', payload: {
      'from': 'host',
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    });
  }

  Future<void> _applyAnswer(Map<String, dynamic> body) async {
    final peer = _peer;
    if (peer == null) return;
    await peer.setRemoteDescription(
      RTCSessionDescription(
          body['sdp'] as String, body['type'] as String? ?? 'answer'),
    );
    _remoteDescriptionSet = true;
    for (final candidate in _pendingRemoteCandidates) {
      await peer.addCandidate(candidate);
    }
    _pendingRemoteCandidates.clear();
  }

  Future<void> _applyIce(Map<String, dynamic> body) async {
    final peer = _peer;
    if (peer == null) return;
    final candidate = RTCIceCandidate(
      body['candidate'] as String,
      body['sdpMid'] as String?,
      (body['sdpMLineIndex'] as num?)?.toInt(),
    );
    if (!_remoteDescriptionSet) {
      _pendingRemoteCandidates.add(candidate);
      return;
    }
    await peer.addCandidate(candidate);
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
    if (notifyPeer) {
      await _channel?.sendBroadcastMessage(
          event: 'webrtc_hangup', payload: {'from': 'host'});
    }
    for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      track.stop();
    }
    await _localStream?.dispose();
    await _peer?.close();
    await _channel?.unsubscribe();
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    _connected = false;
    _remoteDescriptionSet = false;
    _pendingRemoteCandidates.clear();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(close(notifyPeer: false));
    localRenderer.dispose();
    remoteRenderer.dispose();
    super.dispose();
  }
}
