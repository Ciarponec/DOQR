import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.91.0';

const $ = (id) => document.getElementById(id);
const qrToken = new URLSearchParams(location.search).get('qr');
const supabaseUrl = document.documentElement.dataset.supabaseUrl;
let supabase;
let config;
let context;
let ring;
let channel;
let peer;
let localStream;
let remoteStream;
let visitorKind = 'guest';
const requestedMode = 'text';
let captchaToken = null;
let muted = false;
let cameraEnabled = true;
let remoteDescriptionSet = false;
let offerHandling = false;
let mediaDeadlineTimer;
let mediaCountdownTimer;
let mediaLimitEnding = false;
const seenMessages = new Set();
const seenIceCandidateIds = new Set();
let queuedRemoteCandidates = [];

function show(id) {
  document.querySelectorAll('.view').forEach((view) => view.classList.remove('active'));
  $(id).classList.add('active');
  scrollTo({top: 0, behavior: 'smooth'});
}

function fail(message) {
  $('errorText').textContent = message || 'Lütfen QR kodunu yeniden tarayın.';
  show('errorView');
}

async function functionCall(name, body) {
  const {data, error} = await supabase.functions.invoke(name, {body});
  if (error) {
    let message = error.message;
    try {
      const payload = await error.context?.json();
      message = payload?.error || message;
    } catch (_) {}
    throw new Error(message);
  }
  return data;
}

function deviceKey() {
  const storageKey = 'doqr_visitor_device_v1';
  let value = localStorage.getItem(storageKey);
  if (!value) {
    value = crypto.randomUUID?.() || `${Date.now()}-${Math.random().toString(36).slice(2)}`;
    localStorage.setItem(storageKey, value);
  }
  return value;
}

function clientInfo() {
  return {
    device_key: deviceKey(),
    language: navigator.language,
    timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
    platform: navigator.userAgentData?.platform || navigator.platform || 'unknown',
    screen: `${screen.width}x${screen.height}x${screen.colorDepth}`,
    hardware_concurrency: navigator.hardwareConcurrency || null,
    device_memory: navigator.deviceMemory || null,
    touch_points: navigator.maxTouchPoints || 0,
  };
}

async function bootstrap() {
  if (!qrToken) return fail('QR bağlantısı eksik veya bozuk. Kapıdaki QR kodunu yeniden tarayın.');
  try {
    const response = await fetch(`${supabaseUrl}/functions/v1/visitor-config`, {cache: 'no-store'});
    config = await response.json();
    if (!response.ok) throw new Error(config.error || 'Yapılandırma alınamadı');
    supabase = createClient(config.supabase_url, config.supabase_publishable_key, {
      auth: {storageKey: 'doqr-visitor-session', persistSession: true, autoRefreshToken: true, detectSessionInUrl: false},
    });
    if (config.turnstile_site_key) renderTurnstile(config.turnstile_site_key);
    show('consentView');
  } catch (error) {
    fail(error.message);
  }
}

function renderTurnstile(sitekey) {
  const wait = setInterval(() => {
    if (!window.turnstile) return;
    clearInterval(wait);
    window.turnstile.render('#turnstile', {sitekey, theme: 'light', callback: (token) => { captchaToken = token; updateContinue(); }, 'expired-callback': () => { captchaToken = null; updateContinue(); }});
  }, 100);
  setTimeout(() => clearInterval(wait), 10000);
}

function updateContinue() {
  $('continueBtn').disabled = Boolean(config?.turnstile_site_key && !captchaToken);
}

$('continueBtn').addEventListener('click', async () => {
  $('continueBtn').disabled = true;
  $('continueBtn').textContent = 'Güvenli oturum açılıyor…';
  try {
    const {data: current} = await supabase.auth.getUser();
    if (current.user && !current.user.is_anonymous) await supabase.auth.signOut();
    if (!current.user || !current.user.is_anonymous) {
      const {error} = await supabase.auth.signInAnonymously({options: captchaToken ? {captchaToken} : {}});
      if (error) throw error;
    }
    context = await functionCall('visitor-door-context', {qr_token: qrToken});
    renderSetup();
    show('setupView');
  } catch (error) {
    fail(error.message);
  } finally {
    $('continueBtn').textContent = 'Devam et →';
    updateContinue();
  }
});

function renderSetup() {
  $('doorLabel').textContent = context.door.label;
  $('welcomeMessage').textContent = context.door.welcome_message || 'Hosta haber vermek için zili çalın.';
  $('nameOptional').textContent = context.door.require_visitor_name ? '(zorunlu)' : '(opsiyonel)';
  const couriers = $('courierSelect');
  context.couriers.forEach(({code, label}) => {
    const option = document.createElement('option');
    option.value = code;
    option.textContent = label;
    couriers.append(option);
  });
}

$('visitorKinds').addEventListener('click', (event) => {
  const button = event.target.closest('button[data-kind]');
  if (!button) return;
  visitorKind = button.dataset.kind;
  $('visitorKinds').querySelectorAll('button').forEach((item) => item.classList.toggle('selected', item === button));
  $('courierFields').classList.toggle('hidden', visitorKind !== 'courier');
});

$('ringBtn').addEventListener('click', async () => {
  const alias = $('visitorAlias').value.trim();
  const courierCode = $('courierSelect').value;
  if (context.door.require_visitor_name && !alias) return $('visitorAlias').focus();
  if (visitorKind === 'courier' && !courierCode) return $('courierSelect').focus();
  $('ringBtn').disabled = true;
  $('ringBtn').textContent = 'Zil çalıyor…';
  try {
    ring = await functionCall('qr-ring-create', {
      qr_token: qrToken,
      visitor_alias: alias || null,
      visitor_kind: visitorKind,
      courier_code: visitorKind === 'courier' ? courierCode : null,
      requested_mode: requestedMode,
      consent_version: config.consent_version,
      client: clientInfo(),
    });
    await startSession();
    show('sessionView');
  } catch (error) {
    releaseLocalMedia();
    const unauthorized = /unauthorized|permissions to (read|write).*channel topic/i.test(error?.message || '');
    alert(unauthorized
      ? 'Güvenli iletişim kanalı kurulamadı. Sayfayı yenileyip tekrar deneyin.'
      : error.message);
  } finally {
    $('ringBtn').disabled = false;
    $('ringBtn').textContent = 'Zili çal →';
  }
});

async function startSession() {
  const {data: sessionData, error: sessionError} = await supabase.auth.getSession();
  if (sessionError || !sessionData.session?.access_token) {
    throw new Error('Güvenli ziyaretçi oturumu doğrulanamadı. Sayfayı yenileyip tekrar deneyin.');
  }
  await supabase.realtime.setAuth(sessionData.session.access_token);
  channel = supabase.channel(`visitor-ring:${ring.ring_id}`);
  await new Promise((resolve, reject) => channel
    .on('postgres_changes', {event: 'INSERT', schema: 'public', table: 'chat_messages', filter: `ring_id=eq.${ring.ring_id}`}, ({new: value}) => appendMessage(value))
    .on('postgres_changes', {event: 'UPDATE', schema: 'public', table: 'rings', filter: `id=eq.${ring.ring_id}`}, ({new: value}) => updateRingState(value))
    .on('postgres_changes', {event: '*', schema: 'public', table: 'webrtc_signals', filter: `ring_id=eq.${ring.ring_id}`}, ({new: value}) => handleSignal(value))
    .on('postgres_changes', {event: 'INSERT', schema: 'public', table: 'webrtc_ice_candidates', filter: `ring_id=eq.${ring.ring_id}`}, ({new: value}) => { void handleIceCandidate(value); })
    .subscribe((status, error) => {
      $('onlineDot').classList.toggle('offline', status !== 'SUBSCRIBED');
      if (status === 'SUBSCRIBED') resolve();
      if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') reject(error || new Error('Güvenli kanal kurulamadı'));
    }));
  const {data: history} = await supabase.from('chat_messages').select('id, sender_type, message_text, created_at').eq('ring_id', ring.ring_id).order('created_at');
  (history || []).forEach(appendMessage);
  const {data: signal} = await supabase.from('webrtc_signals').select('ring_id, offer_type, offer_sdp, answer_type, answer_sdp').eq('ring_id', ring.ring_id).maybeSingle();
  if (signal) await handleSignal(signal);
  const {data: candidates} = await supabase.from('webrtc_ice_candidates')
    .select('id, sender_role, candidate, sdp_mid, sdp_mline_index')
    .eq('ring_id', ring.ring_id).order('id');
  await Promise.all((candidates || []).map(handleIceCandidate));
}

async function prepareLocalMedia(mode = activeMediaMode()) {
  if (localStream) return localStream;
  if (!navigator.mediaDevices?.getUserMedia) {
    throw new Error('Bu tarayıcı sesli veya görüntülü görüşmeyi desteklemiyor.');
  }
  try {
    if (mode === 'video') {
      // Safari/iOS may collapse a combined prompt into microphone-only. Ask
      // for the camera first and verify that a real video track was granted.
      const cameraStream = await navigator.mediaDevices.getUserMedia({
        audio: false,
        video: {facingMode:'user',width:{ideal:1280},height:{ideal:720}},
      });
      if (!cameraStream.getVideoTracks().length) {
        cameraStream.getTracks().forEach((track) => track.stop());
        throw new Error('Kamera akışı alınamadı. Safari ayarlarından kamera iznini açın.');
      }
      try {
        const microphoneStream = await navigator.mediaDevices.getUserMedia({
          audio: {echoCancellation:true,noiseSuppression:true,autoGainControl:true},
          video: false,
        });
        if (!microphoneStream.getAudioTracks().length) {
          throw new Error('Mikrofon akışı alınamadı.');
        }
        localStream = new MediaStream([
          ...cameraStream.getVideoTracks(),
          ...microphoneStream.getAudioTracks(),
        ]);
      } catch (error) {
        cameraStream.getTracks().forEach((track) => track.stop());
        throw error;
      }
    } else {
      localStream = await navigator.mediaDevices.getUserMedia({
        audio: {echoCancellation:true,noiseSuppression:true,autoGainControl:true},
        video: false,
      });
    }
    return localStream;
  } catch (error) {
    if (error?.message?.includes('akışı alınamadı')) throw error;
    const devices = mode === 'video' ? 'önce kamera, ardından mikrofon' : 'mikrofon';
    throw new Error(`Görüşme için ${devices} izni gerekiyor.`);
  }
}

function releaseLocalMedia() {
  localStream?.getTracks().forEach((track) => track.stop());
  localStream = null;
}

function activeMediaMode() {
  const mode = ring?.accepted_mode || ring?.requested_mode;
  return ['audio', 'video'].includes(mode) ? mode : null;
}

function mediaModeLabel(mode) {
  return mode === 'video' ? 'görüntülü görüşme' : 'sesli görüşme';
}

function updateRingState(value) {
  ring = {...ring, ...value};
  const accepted = ring.status === 'accepted';
  const mediaRequested = ring.status === 'media_requested';
  const mediaMode = activeMediaMode();
  $('pulse').classList.toggle('connected', accepted);
  $('sessionEyebrow').textContent = accepted ? 'Bağlandı' : mediaRequested ? 'Görüşme isteği' : 'Zil durumu';
  $('sessionTitle').textContent = accepted
    ? (mediaMode ? 'Görüşme başlıyor' : 'Host yanıtladı')
    : mediaRequested
      ? `Host ${mediaModeLabel(mediaMode)} başlatmak istiyor`
      : ({declined:'Host şu anda müsait değil', missed:'Zil cevapsız kaldı', cancelled:'Ziyaret iptal edildi', ended:'Görüşme sona erdi'}[ring.status] || 'Host bekleniyor');
  $('sessionSubtitle').textContent = mediaRequested
    ? 'Kabul etmeden mikrofon veya kamera açılmaz.'
    : accepted ? 'Güvenli oturum aktif.' : 'Bu sayfayı açık tutabilirsiniz.';
  $('mediaRequestCard').classList.toggle('hidden', !mediaRequested);
  $('chatCard').classList.toggle('hidden', !['pending', 'media_requested', 'accepted'].includes(ring.status));
  if (mediaRequested) {
    const label = mediaModeLabel(mediaMode);
    $('mediaRequestTitle').textContent = `Host ${label} başlatmak istiyor`;
    $('mediaRequestText').textContent = mediaMode === 'video'
      ? 'Kabul ettiğinizde kamera ve mikrofon izni istenir.'
      : 'Kabul ettiğinizde mikrofon izni istenir.';
  }
  if (accepted && mediaMode) void loadPersistentOffer();
  if (['declined','missed','cancelled','ended'].includes(ring.status)) {
    $('cancelBtn').classList.add('hidden');
    $('mediaRequestCard').classList.add('hidden');
    closeMedia(false);
  }
}

async function loadPersistentOffer() {
  if (remoteDescriptionSet || !ring || !activeMediaMode()) return;
  const {data, error} = await supabase.from('webrtc_signals')
    .select('ring_id, offer_type, offer_sdp, answer_type, answer_sdp')
    .eq('ring_id', ring.ring_id)
    .maybeSingle();
  if (!error && data) await handleSignal(data);
}

function appendMessage(message) {
  if (!message?.id || seenMessages.has(message.id)) return;
  seenMessages.add(message.id);
  $('messages').querySelector('.empty-chat')?.remove();
  const node = document.createElement('div');
  node.className = `message ${message.sender_type}`;
  node.textContent = message.message_text;
  $('messages').append(node);
  $('messages').scrollTop = $('messages').scrollHeight;
}

$('messageForm').addEventListener('submit', async (event) => {
  event.preventDefault();
  const text = $('messageInput').value.trim();
  if (!text || !ring || !['pending', 'media_requested', 'accepted'].includes(ring.status)) return;
  $('messageInput').value = '';
  try {
    await functionCall('visitor-chat-send', {ring_id: ring.ring_id, message_text: text, client_message_id: crypto.randomUUID?.()});
  } catch (error) {
    $('messageInput').value = text;
    alert(error.message);
  }
});

$('cancelBtn').addEventListener('click', () => {
  const action = ring?.status === 'accepted'
    ? 'end'
    : ring?.status === 'media_requested'
      ? 'decline_media'
      : 'cancel';
  void ringAction(action);
});
$('hangupBtn').addEventListener('click', () => ringAction('end'));
$('acceptMediaBtn').addEventListener('click', () => ringAction('accept_media'));
$('declineMediaBtn').addEventListener('click', () => ringAction('decline_media'));
async function ringAction(action, mode = null) {
  if (!ring) return;
  try { await functionCall('ring-action', {ring_id: ring.ring_id, action, mode}); } catch (error) { alert(error.message); }
}

async function handleSignal(signal) {
  if (offerHandling || remoteDescriptionSet || !signal?.offer_sdp || !activeMediaMode()) return;
  offerHandling = true;
  try {
    if (!peer) await createMediaPeer();
    await peer.setRemoteDescription({type: signal.offer_type || 'offer', sdp: signal.offer_sdp});
    remoteDescriptionSet = true;
    await flushQueuedRemoteCandidates();
    const answer = await peer.createAnswer();
    await peer.setLocalDescription(answer);
    const completeAnswer = peer.localDescription;
    const {error} = await supabase.from('webrtc_signals').update({
      answer_type: completeAnswer.type || 'answer',
      answer_sdp: completeAnswer.sdp,
      answer_created_at: new Date().toISOString(),
    }).eq('ring_id', ring.ring_id);
    if (error) throw error;
  } catch (error) {
    $('connectionLabel').textContent = 'Medya izni veya bağlantı kurulamadı';
  } finally {
    offerHandling = false;
  }
}

async function createMediaPeer() {
  const rtc = await functionCall('rtc-config', {ring_id: ring.ring_id});
  const mode = activeMediaMode();
  scheduleMediaDeadline(rtc.media_deadline);
  peer = new RTCPeerConnection({iceServers: rtc.ice_servers});
  peer.onicecandidate = ({candidate}) => {
    if (!candidate?.candidate) return;
    void supabase.from('webrtc_ice_candidates').insert({
      ring_id: ring.ring_id,
      sender_role: 'visitor',
      candidate: candidate.candidate,
      sdp_mid: candidate.sdpMid,
      sdp_mline_index: candidate.sdpMLineIndex,
    });
  };
  peer.ontrack = ({track, streams}) => {
    remoteStream = streams[0] || remoteStream || new MediaStream();
    if (!streams[0] && !remoteStream.getTracks().some((item) => item.id === track.id)) remoteStream.addTrack(track);
    $('remoteVideo').srcObject = remoteStream;
  };
  peer.onconnectionstatechange = () => { $('connectionLabel').textContent = peer.connectionState === 'connected' ? 'Bağlandı' : 'Bağlanıyor…'; };
  await prepareLocalMedia(mode);
  localStream.getTracks().forEach((track) => peer.addTrack(track, localStream));
  $('localVideo').srcObject = localStream;
  $('mediaCard').classList.remove('hidden');
  $('audioState').classList.toggle('hidden', mode !== 'audio');
  $('remoteVideo').classList.toggle('hidden', mode !== 'video');
  $('localVideo').classList.toggle('hidden', mode !== 'video');
  $('cameraBtn').classList.toggle('hidden', mode !== 'video');
}

async function handleIceCandidate(value) {
  if (value?.sender_role !== 'host' || !value?.candidate) return;
  const id = Number(value.id);
  if (!Number.isFinite(id) || seenIceCandidateIds.has(id)) return;
  seenIceCandidateIds.add(id);
  const candidate = {
    candidate: value.candidate,
    sdpMid: value.sdp_mid ?? null,
    sdpMLineIndex: value.sdp_mline_index ?? null,
  };
  if (!peer || !remoteDescriptionSet) {
    queuedRemoteCandidates.push(candidate);
    return;
  }
  await peer.addIceCandidate(candidate);
}

async function flushQueuedRemoteCandidates() {
  const candidates = queuedRemoteCandidates;
  queuedRemoteCandidates = [];
  for (const candidate of candidates) await peer.addIceCandidate(candidate);
}

function scheduleMediaDeadline(value) {
  if (activeMediaMode() !== 'video') return;
  clearMediaDeadline();
  const parsed = Date.parse(value);
  const deadline = Number.isFinite(parsed) ? parsed : Date.now() + 60000;
  const label = $('mediaLimitLabel');
  label.classList.remove('hidden');

  const update = () => {
    const seconds = Math.max(0, Math.ceil((deadline - Date.now()) / 1000));
    label.textContent = `En fazla 1 dk · 00:${String(seconds).padStart(2, '0')}`;
  };
  update();
  mediaCountdownTimer = setInterval(update, 1000);
  mediaDeadlineTimer = setTimeout(() => void expireVideoSession(), Math.max(0, deadline - Date.now()));
}

function clearMediaDeadline() {
  clearTimeout(mediaDeadlineTimer);
  clearInterval(mediaCountdownTimer);
  mediaDeadlineTimer = undefined;
  mediaCountdownTimer = undefined;
  $('mediaLimitLabel').classList.add('hidden');
}

async function expireVideoSession() {
  if (mediaLimitEnding) return;
  mediaLimitEnding = true;
  $('mediaLimitLabel').textContent = '1 dakikalık süre doldu';
  await closeMedia(true);
  await ringAction('end');
}

$('muteBtn').addEventListener('click', () => { muted = !muted; localStream?.getAudioTracks().forEach((track) => track.enabled = !muted); $('muteBtn').textContent = muted ? '×' : '🎙'; });
$('cameraBtn').addEventListener('click', () => { cameraEnabled = !cameraEnabled; localStream?.getVideoTracks().forEach((track) => track.enabled = cameraEnabled); $('cameraBtn').textContent = cameraEnabled ? '▣' : '×'; });
async function closeMedia(notify = true) {
  clearMediaDeadline();
  releaseLocalMedia();
  peer?.close(); peer = null;
  remoteStream = null;
  remoteDescriptionSet = false;
  offerHandling = false;
  queuedRemoteCandidates = [];
  seenIceCandidateIds.clear();
  $('mediaCard').classList.add('hidden');
}

addEventListener('beforeunload', () => { localStream?.getTracks().forEach((track) => track.stop()); peer?.close(); });
bootstrap();
