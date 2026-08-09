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
let visitorKind = 'guest';
let requestedMode = 'text';
let captchaToken = null;
let muted = false;
let cameraEnabled = true;
let remoteDescriptionSet = false;
let mediaDeadlineTimer;
let mediaCountdownTimer;
let mediaLimitEnding = false;
const pendingHostCandidates = [];
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
    alert(error.message);
  } finally {
    $('ringBtn').disabled = false;
    $('ringBtn').textContent = 'Zili çal →';
  }
});

async function startSession() {
  channel = supabase.channel(`ring:${ring.ring_id}`, {config: {private: true, broadcast: {ack: true}}});
  await new Promise((resolve, reject) => channel
    .on('broadcast', {event: 'chat_message'}, ({payload}) => appendMessage(payload))
    .on('broadcast', {event: 'webrtc_offer'}, ({payload}) => handleOffer(payload))
    .on('broadcast', {event: 'webrtc_ice'}, ({payload}) => handleIce(payload))
    .on('broadcast', {event: 'webrtc_hangup'}, () => closeMedia(false))
    .on('postgres_changes', {event: 'UPDATE', schema: 'public', table: 'rings', filter: `id=eq.${ring.ring_id}`}, ({new: value}) => updateRingState(value))
    .subscribe((status, error) => {
      $('onlineDot').classList.toggle('offline', status !== 'SUBSCRIBED');
      if (status === 'SUBSCRIBED') resolve();
      if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') reject(error || new Error('Güvenli kanal kurulamadı'));
    }));
  const {data: history} = await supabase.from('chat_messages').select('id, sender_type, message_text, created_at').eq('ring_id', ring.ring_id).order('created_at');
  (history || []).forEach(appendMessage);
}

function updateRingState(value) {
  ring = {...ring, ...value};
  const accepted = value.status === 'accepted';
  $('pulse').classList.toggle('connected', accepted);
  $('sessionEyebrow').textContent = accepted ? 'Bağlandı' : 'Zil durumu';
  $('sessionTitle').textContent = accepted ? (requestedMode === 'text' ? 'Host yanıtladı' : 'Görüşme başlıyor') : ({declined:'Host şu anda müsait değil', missed:'Zil cevapsız kaldı', cancelled:'Ziyaret iptal edildi', ended:'Görüşme sona erdi'}[value.status] || 'Host bekleniyor');
  $('sessionSubtitle').textContent = accepted ? 'Güvenli oturum aktif.' : 'Bu sayfayı açık tutabilirsiniz.';
  if (['declined','missed','cancelled','ended'].includes(value.status)) {
    $('cancelBtn').classList.add('hidden');
    closeMedia(false);
  }
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

async function handleOffer(offer) {
  if (offer.from !== 'host' || !['audio','video'].includes(requestedMode)) return;
  try {
    if (!peer) await createMediaPeer();
    await peer.setRemoteDescription({type: offer.type || 'offer', sdp: offer.sdp});
    remoteDescriptionSet = true;
    for (const candidate of pendingHostCandidates.splice(0)) await peer.addIceCandidate(candidate);
    const answer = await peer.createAnswer();
    await peer.setLocalDescription(answer);
    await channel.send({type: 'broadcast', event: 'webrtc_answer', payload: {from:'visitor', type:answer.type, sdp:answer.sdp}});
  } catch (error) {
    $('connectionLabel').textContent = 'Medya izni veya bağlantı kurulamadı';
  }
}

async function createMediaPeer() {
  const rtc = await functionCall('rtc-config', {ring_id: ring.ring_id});
  scheduleMediaDeadline(rtc.media_deadline);
  peer = new RTCPeerConnection({iceServers: rtc.ice_servers});
  peer.onicecandidate = ({candidate}) => {
    if (candidate) channel.send({type:'broadcast', event:'webrtc_ice', payload:{from:'visitor', ...candidate.toJSON()}});
  };
  peer.ontrack = ({streams}) => { $('remoteVideo').srcObject = streams[0]; };
  peer.onconnectionstatechange = () => { $('connectionLabel').textContent = peer.connectionState === 'connected' ? 'Bağlandı' : 'Bağlanıyor…'; };
  localStream = await navigator.mediaDevices.getUserMedia({audio:{echoCancellation:true,noiseSuppression:true,autoGainControl:true},video:requestedMode === 'video' ? {facingMode:'user',width:{ideal:1280},height:{ideal:720}} : false});
  localStream.getTracks().forEach((track) => peer.addTrack(track, localStream));
  $('localVideo').srcObject = localStream;
  $('mediaCard').classList.remove('hidden');
  $('audioState').classList.toggle('hidden', requestedMode !== 'audio');
  $('remoteVideo').classList.toggle('hidden', requestedMode !== 'video');
  $('localVideo').classList.toggle('hidden', requestedMode !== 'video');
  $('cameraBtn').classList.toggle('hidden', requestedMode !== 'video');
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

async function handleIce(candidate) {
  if (candidate.from !== 'host' || !candidate.candidate) return;
  const ice = {candidate:candidate.candidate,sdpMid:candidate.sdpMid,sdpMLineIndex:candidate.sdpMLineIndex};
  if (!peer || !remoteDescriptionSet) {
    pendingHostCandidates.push(ice);
    return;
  }
  await peer.addIceCandidate(ice);
}

$('muteBtn').addEventListener('click', () => { muted = !muted; localStream?.getAudioTracks().forEach((track) => track.enabled = !muted); $('muteBtn').textContent = muted ? '×' : '🎙'; });
$('cameraBtn').addEventListener('click', () => { cameraEnabled = !cameraEnabled; localStream?.getVideoTracks().forEach((track) => track.enabled = cameraEnabled); $('cameraBtn').textContent = cameraEnabled ? '▣' : '×'; });
async function closeMedia(notify = true) {
  clearMediaDeadline();
  if (notify && channel) await channel.send({type:'broadcast',event:'webrtc_hangup',payload:{from:'visitor'}});
  localStream?.getTracks().forEach((track) => track.stop());
  peer?.close(); peer = null; localStream = null;
  remoteDescriptionSet = false;
  pendingHostCandidates.splice(0);
  $('mediaCard').classList.add('hidden');
}

addEventListener('beforeunload', () => { localStream?.getTracks().forEach((track) => track.stop()); peer?.close(); });
bootstrap();
