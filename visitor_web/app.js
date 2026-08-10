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
let requestedMode = 'text';
let captchaToken = null;
let muted = false;
let cameraEnabled = true;
let remoteDescriptionSet = false;
let offerHandling = false;
let mediaDeadlineTimer;
let mediaCountdownTimer;
let mediaLimitEnding = false;
const seenMessages = new Set();

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
  $('continueBtn').disabled = !$('consentCheck').checked || (config?.turnstile_site_key && !captchaToken);
}

$('consentCheck').addEventListener('change', updateContinue);
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
  $('welcomeMessage').textContent = context.door.welcome_message || 'Host ile bağlantı kurmak için bir görüşme seçeneği seçin.';
  $('nameOptional').textContent = context.door.require_visitor_name ? '(zorunlu)' : '(opsiyonel)';
  const couriers = $('courierSelect');
  context.couriers.forEach(({code, label}) => {
    const option = document.createElement('option');
    option.value = code;
    option.textContent = label;
    couriers.append(option);
  });
  const labels = {text: ['✦', 'Yazılı'], audio: ['◖', 'Sesli'], video: ['▣', 'Görüntülü · 1 dk']};
  const grid = $('modeGrid');
  grid.replaceChildren();
  if (!context.modes[requestedMode]) {
    requestedMode = Object.keys(context.modes).find((mode) => context.modes[mode]);
  }
  Object.entries(context.modes).filter(([, enabled]) => enabled).forEach(([mode]) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = `mode-button${mode === requestedMode ? ' selected' : ''}`;
    button.dataset.mode = mode;
    const icon = document.createElement('b'); icon.textContent = labels[mode][0];
    const text = document.createElement('span'); text.textContent = labels[mode][1];
    button.append(icon, text);
    button.addEventListener('click', () => { requestedMode = mode; grid.querySelectorAll('button').forEach((item) => item.classList.toggle('selected', item === button)); });
    grid.append(button);
  });
  const mediaNote = $('mediaAvailabilityNote');
  const mediaUnavailable = context.media?.available === false &&
    ['monthly_limit', 'analytics_unavailable'].includes(context.media?.reason);
  mediaNote.classList.toggle('hidden', !mediaUnavailable);
  mediaNote.textContent = context.media?.reason === 'monthly_limit'
    ? 'Sesli ve görüntülü görüşme aylık altyapı sınırı nedeniyle geçici olarak kapalı.'
    : 'Sesli ve görüntülü görüşme altyapısı geçici olarak kullanılamıyor.';
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
    if (['audio','video'].includes(requestedMode)) await prepareLocalMedia();
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
    .subscribe((status, error) => {
      $('onlineDot').classList.toggle('offline', status !== 'SUBSCRIBED');
      if (status === 'SUBSCRIBED') resolve();
      if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') reject(error || new Error('Güvenli kanal kurulamadı'));
    }));
  const {data: history} = await supabase.from('chat_messages').select('id, sender_type, message_text, created_at').eq('ring_id', ring.ring_id).order('created_at');
  (history || []).forEach(appendMessage);
  const {data: signal} = await supabase.from('webrtc_signals').select('ring_id, offer_type, offer_sdp, answer_type, answer_sdp').eq('ring_id', ring.ring_id).maybeSingle();
  if (signal) await handleSignal(signal);
}

async function prepareLocalMedia() {
  if (localStream) return localStream;
  if (!navigator.mediaDevices?.getUserMedia) {
    throw new Error('Bu tarayıcı sesli veya görüntülü görüşmeyi desteklemiyor.');
  }
  try {
    if (requestedMode === 'video') {
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
    const devices = requestedMode === 'video' ? 'önce kamera, ardından mikrofon' : 'mikrofon';
    throw new Error(`Görüşme için ${devices} izni gerekiyor.`);
  }
}

function releaseLocalMedia() {
  localStream?.getTracks().forEach((track) => track.stop());
  localStream = null;
}

function updateRingState(value) {
  ring = {...ring, ...value};
  const accepted = value.status === 'accepted';
  $('pulse').classList.toggle('connected', accepted);
  $('sessionEyebrow').textContent = accepted ? 'Bağlandı' : 'Zil durumu';
  $('sessionTitle').textContent = accepted ? (requestedMode === 'text' ? 'Host yanıtladı' : 'Görüşme başlıyor') : ({declined:'Host şu anda müsait değil', missed:'Zil cevapsız kaldı', cancelled:'Ziyaret iptal edildi', ended:'Görüşme sona erdi'}[value.status] || 'Host bekleniyor');
  $('sessionSubtitle').textContent = accepted ? 'Güvenli oturum aktif.' : 'Bu sayfayı açık tutabilirsiniz.';
  if (accepted) void loadPersistentOffer();
  if (['declined','missed','cancelled','ended'].includes(value.status)) {
    $('cancelBtn').classList.add('hidden');
    closeMedia(false);
  }
}

async function loadPersistentOffer() {
  if (remoteDescriptionSet || !ring || !['audio','video'].includes(requestedMode)) return;
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
  if (!text || !ring) return;
  $('messageInput').value = '';
  try {
    await functionCall('visitor-chat-send', {ring_id: ring.ring_id, message_text: text, client_message_id: crypto.randomUUID?.()});
  } catch (error) {
    $('messageInput').value = text;
    alert(error.message);
  }
});

$('cancelBtn').addEventListener('click', () => ringAction(ring?.status === 'accepted' ? 'end' : 'cancel'));
$('hangupBtn').addEventListener('click', () => ringAction('end'));
async function ringAction(action) {
  if (!ring) return;
  try { await functionCall('ring-action', {ring_id: ring.ring_id, action}); } catch (error) { alert(error.message); }
}

async function handleSignal(signal) {
  if (offerHandling || remoteDescriptionSet || !signal?.offer_sdp || !['audio','video'].includes(requestedMode)) return;
  offerHandling = true;
  try {
    if (!peer) await createMediaPeer();
    await peer.setRemoteDescription({type: signal.offer_type || 'offer', sdp: signal.offer_sdp});
    remoteDescriptionSet = true;
    const answer = await peer.createAnswer();
    await peer.setLocalDescription(answer);
    await waitForIceGathering(peer);
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
  scheduleMediaDeadline(rtc.media_deadline);
  peer = new RTCPeerConnection({iceServers: rtc.ice_servers});
  peer.ontrack = ({track, streams}) => {
    remoteStream = streams[0] || remoteStream || new MediaStream();
    if (!streams[0] && !remoteStream.getTracks().some((item) => item.id === track.id)) remoteStream.addTrack(track);
    $('remoteVideo').srcObject = remoteStream;
  };
  peer.onconnectionstatechange = () => { $('connectionLabel').textContent = peer.connectionState === 'connected' ? 'Bağlandı' : 'Bağlanıyor…'; };
  await prepareLocalMedia();
  localStream.getTracks().forEach((track) => peer.addTrack(track, localStream));
  $('localVideo').srcObject = localStream;
  $('mediaCard').classList.remove('hidden');
  $('audioState').classList.toggle('hidden', requestedMode !== 'audio');
  $('remoteVideo').classList.toggle('hidden', requestedMode !== 'video');
  $('localVideo').classList.toggle('hidden', requestedMode !== 'video');
  $('cameraBtn').classList.toggle('hidden', requestedMode !== 'video');
}

function waitForIceGathering(connection, timeoutMs = 10000) {
  if (connection.iceGatheringState === 'complete') return Promise.resolve();
  return new Promise((resolve) => {
    const done = () => {
      connection.removeEventListener('icegatheringstatechange', changed);
      clearTimeout(timer);
      resolve();
    };
    const changed = () => {
      if (connection.iceGatheringState === 'complete') done();
    };
    const timer = setTimeout(done, timeoutMs);
    connection.addEventListener('icegatheringstatechange', changed);
  });
}

function scheduleMediaDeadline(value) {
  if (requestedMode !== 'video') return;
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
  $('mediaCard').classList.add('hidden');
}

addEventListener('beforeunload', () => { localStream?.getTracks().forEach((track) => track.stop()); peer?.close(); });
bootstrap();
