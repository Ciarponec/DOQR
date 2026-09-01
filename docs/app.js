import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.91.0';
import { languageCode, setLanguage, t, translateDocument } from './i18n.js?v=20260901-2';

const $ = (id) => document.getElementById(id);
const qrToken = new URLSearchParams(location.search).get('qr');
const supabaseUrl = document.documentElement.dataset.supabaseUrl;
const requestedMode = 'text';
const seenMessages = new Set();
const seenIceCandidateIds = new Set();
let queuedRemoteCandidates = [];
let supabase;
let config;
let context;
let ring;
let channel;
let peer;
let localStream;
let remoteStream;
let visitorAccessToken;
let visitorKind = 'guest';
let captchaToken = null;
let muted = false;
let cameraEnabled = true;
let remoteDescriptionSet = false;
let offerHandling = false;
let mediaDeadlineTimer;
let mediaCountdownTimer;
let mediaLimitEnding = false;
let unloadSent = false;

class UiError extends Error {
  constructor(code, message) {
    super(message || code);
    this.code = code;
  }
}

const errorKeys = {
  QR_TOKEN_INVALID: 'errorInvalidQr', QR_TOKEN_EXPIRED: 'errorInvalidQr', QR_TOKEN_REVOKED: 'errorInvalidQr',
  QR_NOT_FOUND: 'errorInvalidQr', DOOR_NOT_FOUND: 'errorInvalidQr', DOOR_INACTIVE: 'errorInactiveDoor',
  RATE_LIMITED: 'errorRateLimit', TOO_MANY_REQUESTS: 'errorRateLimit', VISITOR_BLOCKED: 'errorBlocked',
  BLOCKED: 'errorBlocked', UNAUTHORIZED: 'errorSession', INVALID_JWT: 'errorSession', SESSION_EXPIRED: 'errorSession',
  MEDIA_PERMISSION: 'errorMediaPermission', MEDIA_UNSUPPORTED: 'errorBrowserMedia',
};

function friendlyError(error) {
  const key = errorKeys[error?.code];
  if (key) return t(key);
  const message = String(error?.message || '').toLowerCase();
  if (error instanceof TypeError || /failed to fetch|networkerror|load failed/.test(message)) return t('errorNetwork');
  if (/permissions to (read|write).*channel topic|channel_error|timed_out/.test(message)) return t('errorChannel');
  if (/notallowederror|permission|microphone|camera/.test(message)) return t('errorMediaPermission');
  return t('errorGeneric');
}

function show(id) {
  document.querySelectorAll('.view').forEach((view) => view.classList.remove('active'));
  $(id).classList.add('active');
  const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
  scrollTo({ top: 0, behavior: reduced ? 'auto' : 'smooth' });
  $(id).focus?.({ preventScroll: true });
}

function fail(error) {
  $('errorText').textContent = typeof error === 'string' ? error : friendlyError(error);
  show('errorView');
}

function inlineError(id, error) {
  const node = $(id);
  node.textContent = friendlyError(error);
  node.classList.remove('hidden');
}

function clearInlineError(id) {
  const node = $(id);
  node.textContent = '';
  node.classList.add('hidden');
}

function setButtonLabel(id, key, suffix = '') {
  const label = $(id).querySelector('span');
  if (label) label.textContent = t(key);
  else $(id).textContent = `${t(key)}${suffix}`;
}

async function functionCall(name, body) {
  const { data, error } = await supabase.functions.invoke(name, { body });
  if (!error) return data;
  let payload;
  try { payload = await error.context?.json(); } catch (_) { payload = null; }
  throw new UiError(payload?.code || error.code || 'REQUEST_FAILED', payload?.error || error.message);
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
    device_key: deviceKey(), language: navigator.language,
    timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
    platform: navigator.userAgentData?.platform || navigator.platform || 'unknown',
    screen: `${screen.width}x${screen.height}x${screen.colorDepth}`,
    hardware_concurrency: navigator.hardwareConcurrency || null,
    device_memory: navigator.deviceMemory || null, touch_points: navigator.maxTouchPoints || 0,
  };
}

function privacyHref() {
  return languageCode() === 'tr' ? './privacy.html' : `./privacy-${languageCode()}.html`;
}

function refreshLocalizedState() {
  translateDocument();
  $('languageSelect').value = languageCode();
  $('privacyLink').href = privacyHref();
  if (context) renderSetup(false);
  if (ring) updateRingState(ring);
  updateMediaControls();
  updateContinue();
}

$('languageSelect').addEventListener('change', (event) => {
  setLanguage(event.target.value);
  refreshLocalizedState();
});
$('retryBtn').addEventListener('click', () => location.reload());
$('consentCheck').addEventListener('change', updateContinue);

async function bootstrap() {
  refreshLocalizedState();
  if (!qrToken) return fail(t('errorMissingQr'));
  try {
    const response = await fetch(`${supabaseUrl}/functions/v1/visitor-config`, { cache: 'no-store' });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) throw new UiError(payload.code || 'CONFIG_FAILED', payload.error);
    config = payload;
    supabase = createClient(config.supabase_url, config.supabase_publishable_key, {
      auth: { storageKey: 'doqr-visitor-session', persistSession: true, autoRefreshToken: true, detectSessionInUrl: false },
    });
    if (config.turnstile_site_key) loadTurnstile(config.turnstile_site_key);
    show('consentView');
    updateContinue();
  } catch (error) {
    fail(error);
  }
}

function loadTurnstile(sitekey) {
  const render = () => window.turnstile?.render('#turnstile', {
    sitekey, theme: 'light',
    callback: (token) => { captchaToken = token; updateContinue(); },
    'expired-callback': () => { captchaToken = null; updateContinue(); },
    'error-callback': () => { captchaToken = null; updateContinue(); },
  });
  if (window.turnstile) return render();
  let script = document.querySelector('script[data-doqr-turnstile]');
  if (!script) {
    script = document.createElement('script');
    script.src = 'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';
    script.async = true;
    script.defer = true;
    script.dataset.doqrTurnstile = 'true';
    document.head.append(script);
  }
  script.addEventListener('load', render, { once: true });
}

function updateContinue() {
  $('continueBtn').disabled = !$('consentCheck').checked || Boolean(config?.turnstile_site_key && !captchaToken);
}

$('continueBtn').addEventListener('click', async () => {
  $('continueBtn').disabled = true;
  setButtonLabel('continueBtn', 'openingSession');
  try {
    const { data: current } = await supabase.auth.getUser();
    if (current.user && !current.user.is_anonymous) await supabase.auth.signOut();
    if (!current.user || !current.user.is_anonymous) {
      const { error } = await supabase.auth.signInAnonymously({ options: captchaToken ? { captchaToken } : {} });
      if (error) throw error;
    }
    const { data: sessionData, error: sessionError } = await supabase.auth.getSession();
    if (sessionError || !sessionData.session?.access_token) throw new UiError('UNAUTHORIZED');
    visitorAccessToken = sessionData.session.access_token;
    context = await functionCall('visitor-door-context', { qr_token: qrToken });
    renderSetup();
    show('setupView');
  } catch (error) {
    fail(error);
  } finally {
    setButtonLabel('continueBtn', 'continue');
    updateContinue();
  }
});

function renderSetup(resetCouriers = true) {
  $('doorLabel').textContent = context?.door?.label || t('doorDefault');
  $('welcomeMessage').textContent = context?.door?.welcome_message || t('defaultWelcome');
  $('nameOptional').textContent = context?.door?.require_visitor_name ? t('required') : t('optional');
  if (!resetCouriers) return;
  const couriers = $('courierSelect');
  couriers.replaceChildren();
  const placeholder = document.createElement('option');
  placeholder.value = '';
  placeholder.textContent = t('selectCompany');
  couriers.append(placeholder);
  (context?.couriers || []).forEach(({ code, label }) => {
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
  $('visitorKinds').querySelectorAll('button').forEach((item) => {
    const selected = item === button;
    item.classList.toggle('selected', selected);
    item.setAttribute('aria-pressed', String(selected));
  });
  $('courierFields').classList.toggle('hidden', visitorKind !== 'courier');
});

$('ringBtn').addEventListener('click', async () => {
  const alias = $('visitorAlias').value.trim();
  const courierCode = $('courierSelect').value;
  if (context.door.require_visitor_name && !alias) return $('visitorAlias').focus();
  if (visitorKind === 'courier' && !courierCode) return $('courierSelect').focus();
  clearInlineError('setupError');
  $('ringBtn').disabled = true;
  setButtonLabel('ringBtn', 'ringing');
  try {
    ring = await functionCall('qr-ring-create', {
      qr_token: qrToken, visitor_alias: alias || null, visitor_kind: visitorKind,
      courier_code: visitorKind === 'courier' ? courierCode : null,
      requested_mode: requestedMode, consent_version: config.consent_version, client: clientInfo(),
    });
    await startSession();
    show('sessionView');
  } catch (error) {
    releaseLocalMedia();
    inlineError('setupError', error);
  } finally {
    $('ringBtn').disabled = false;
    setButtonLabel('ringBtn', 'ring');
  }
});

async function startSession() {
  const { data: sessionData, error: sessionError } = await supabase.auth.getSession();
  if (sessionError || !sessionData.session?.access_token) throw new UiError('UNAUTHORIZED');
  visitorAccessToken = sessionData.session.access_token;
  await supabase.realtime.setAuth(visitorAccessToken);
  channel = supabase.channel(`visitor-ring:${ring.ring_id}`);
  await new Promise((resolve, reject) => channel
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'chat_messages', filter: `ring_id=eq.${ring.ring_id}` }, ({ new: value }) => appendMessage(value))
    .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'rings', filter: `id=eq.${ring.ring_id}` }, ({ new: value }) => updateRingState(value))
    .on('postgres_changes', { event: '*', schema: 'public', table: 'webrtc_signals', filter: `ring_id=eq.${ring.ring_id}` }, ({ new: value }) => handleSignal(value))
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'webrtc_ice_candidates', filter: `ring_id=eq.${ring.ring_id}` }, ({ new: value }) => { void handleIceCandidate(value); })
    .subscribe((status, error) => {
      $('onlineDot').classList.toggle('offline', status !== 'SUBSCRIBED');
      if (status === 'SUBSCRIBED') resolve();
      if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') reject(error || new UiError('CHANNEL_ERROR'));
    }));
  const { data: history } = await supabase.from('chat_messages').select('id, sender_type, message_text, created_at').eq('ring_id', ring.ring_id).order('created_at');
  (history || []).forEach(appendMessage);
  const { data: signal } = await supabase.from('webrtc_signals').select('ring_id, offer_type, offer_sdp, answer_type, answer_sdp').eq('ring_id', ring.ring_id).maybeSingle();
  if (signal) await handleSignal(signal);
  const { data: candidates } = await supabase.from('webrtc_ice_candidates').select('id, sender_role, candidate, sdp_mid, sdp_mline_index').eq('ring_id', ring.ring_id).order('id');
  for (const candidate of candidates || []) await handleIceCandidate(candidate);
}

function activeMediaMode() {
  const mode = ring?.accepted_mode || ring?.requested_mode;
  return ['audio', 'video'].includes(mode) ? mode : null;
}

async function prepareLocalMedia(mode = activeMediaMode()) {
  if (localStream) return localStream;
  if (!navigator.mediaDevices?.getUserMedia) throw new UiError('MEDIA_UNSUPPORTED');
  try {
    if (mode === 'video') {
      const cameraStream = await navigator.mediaDevices.getUserMedia({ audio: false, video: { facingMode: 'user', width: { ideal: 1280 }, height: { ideal: 720 } } });
      if (!cameraStream.getVideoTracks().length) throw new UiError('MEDIA_PERMISSION');
      try {
        const microphoneStream = await navigator.mediaDevices.getUserMedia({ audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true }, video: false });
        localStream = new MediaStream([...cameraStream.getVideoTracks(), ...microphoneStream.getAudioTracks()]);
      } catch (error) {
        cameraStream.getTracks().forEach((track) => track.stop());
        throw error;
      }
    } else {
      localStream = await navigator.mediaDevices.getUserMedia({ audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true }, video: false });
    }
    return localStream;
  } catch (error) {
    throw error instanceof UiError ? error : new UiError('MEDIA_PERMISSION', error?.message);
  }
}

function releaseLocalMedia() {
  localStream?.getTracks().forEach((track) => track.stop());
  localStream = null;
}

function updateRingState(value) {
  ring = { ...ring, ...value };
  const accepted = ring.status === 'accepted';
  const mediaRequested = ring.status === 'media_requested';
  const mediaMode = activeMediaMode();
  $('pulse').classList.toggle('connected', accepted);
  $('sessionEyebrow').textContent = t(accepted ? 'connected' : mediaRequested ? 'callRequest' : 'ringStatus');
  const terminalTitles = { declined: 'statusDeclined', missed: 'statusMissed', cancelled: 'statusCancelled', ended: 'statusEnded' };
  $('sessionTitle').textContent = accepted ? t(mediaMode ? 'callStarting' : 'ownerAnswered') : mediaRequested ? t(mediaMode === 'video' ? 'ownerRequestsVideo' : 'ownerRequestsAudio') : t(terminalTitles[ring.status] || 'ownerWaiting');
  $('sessionSubtitle').textContent = t(mediaRequested ? 'approvalBeforeMedia' : accepted ? 'secureSessionActive' : 'keepOpen');
  $('mediaRequestCard').classList.toggle('hidden', !mediaRequested);
  $('chatCard').classList.toggle('hidden', !['pending', 'media_requested', 'accepted'].includes(ring.status));
  if (mediaRequested) {
    $('mediaRequestTitle').textContent = t(mediaMode === 'video' ? 'ownerRequestsVideo' : 'ownerRequestsAudio');
    $('mediaRequestText').textContent = t(mediaMode === 'video' ? 'videoPermission' : 'audioPermission');
  }
  if (accepted && mediaMode) void loadPersistentOffer();
  if (['declined', 'missed', 'cancelled', 'ended'].includes(ring.status)) {
    $('cancelBtn').classList.add('hidden');
    $('mediaRequestCard').classList.add('hidden');
    closeMedia();
  }
  $('ringAgainBtn').classList.toggle('hidden', ring.status !== 'missed');
}

$('ringAgainBtn').addEventListener('click', async () => {
  if (channel) await supabase.removeChannel(channel);
  channel = null;
  closeMedia();
  ring = null;
  unloadSent = false;
  mediaLimitEnding = false;
  seenMessages.clear();
  $('messages').innerHTML = `<p class="empty-chat" data-i18n="noMessages">${t('noMessages')}</p>`;
  $('ringAgainBtn').classList.add('hidden');
  $('cancelBtn').classList.remove('hidden');
  $('onlineDot').classList.add('offline');
  clearInlineError('sessionNotice');
  show('setupView');
});

async function loadPersistentOffer() {
  if (remoteDescriptionSet || !ring || !activeMediaMode()) return;
  const { data, error } = await supabase.from('webrtc_signals').select('ring_id, offer_type, offer_sdp, answer_type, answer_sdp').eq('ring_id', ring.ring_id).maybeSingle();
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
    await functionCall('visitor-chat-send', { ring_id: ring.ring_id, message_text: text, client_message_id: crypto.randomUUID?.() });
  } catch (error) {
    $('messageInput').value = text;
    inlineError('sessionNotice', error);
  }
});

$('cancelBtn').addEventListener('click', () => void ringAction(ring?.status === 'accepted' ? 'end' : ring?.status === 'media_requested' ? 'decline_media' : 'cancel'));
$('hangupBtn').addEventListener('click', () => void ringAction('end'));
$('acceptMediaBtn').addEventListener('click', () => void ringAction('accept_media'));
$('declineMediaBtn').addEventListener('click', () => void ringAction('decline_media'));

async function ringAction(action) {
  if (!ring) return;
  clearInlineError('sessionNotice');
  try {
    const updated = await functionCall('ring-action', { ring_id: ring.ring_id, action });
    if (updated?.status) updateRingState(updated);
  } catch (error) {
    inlineError('sessionNotice', error);
  }
}

async function handleSignal(signal) {
  if (offerHandling || remoteDescriptionSet || !signal?.offer_sdp || !activeMediaMode()) return;
  offerHandling = true;
  try {
    if (!peer) await createMediaPeer();
    await peer.setRemoteDescription({ type: signal.offer_type || 'offer', sdp: signal.offer_sdp });
    remoteDescriptionSet = true;
    await flushQueuedRemoteCandidates();
    const answer = await peer.createAnswer();
    await peer.setLocalDescription(answer);
    const completeAnswer = peer.localDescription;
    const { error } = await supabase.from('webrtc_signals').update({ answer_type: completeAnswer.type || 'answer', answer_sdp: completeAnswer.sdp, answer_created_at: new Date().toISOString() }).eq('ring_id', ring.ring_id);
    if (error) throw error;
  } catch (error) {
    $('connectionLabel').textContent = t('connectionFailed');
    inlineError('sessionNotice', error);
  } finally {
    offerHandling = false;
  }
}

async function createMediaPeer() {
  const rtc = await functionCall('rtc-config', { ring_id: ring.ring_id });
  const mode = activeMediaMode();
  scheduleMediaDeadline(rtc.media_deadline);
  peer = new RTCPeerConnection({ iceServers: rtc.ice_servers });
  peer.onicecandidate = ({ candidate }) => {
    if (!candidate?.candidate) return;
    void supabase.from('webrtc_ice_candidates').insert({ ring_id: ring.ring_id, sender_role: 'visitor', candidate: candidate.candidate, sdp_mid: candidate.sdpMid, sdp_mline_index: candidate.sdpMLineIndex });
  };
  peer.ontrack = ({ track, streams }) => {
    remoteStream = streams[0] || remoteStream || new MediaStream();
    if (!streams[0] && !remoteStream.getTracks().some((item) => item.id === track.id)) remoteStream.addTrack(track);
    $('remoteVideo').srcObject = remoteStream;
  };
  peer.onconnectionstatechange = () => { $('connectionLabel').textContent = t(peer.connectionState === 'connected' ? 'connected' : 'connecting'); };
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
  const candidate = { candidate: value.candidate, sdpMid: value.sdp_mid ?? null, sdpMLineIndex: value.sdp_mline_index ?? null };
  if (!peer || !remoteDescriptionSet) return queuedRemoteCandidates.push(candidate);
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
    label.textContent = t('videoLimit', { seconds: String(seconds).padStart(2, '0') });
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
  $('mediaLimitLabel').textContent = t('videoLimitEnded');
  closeMedia();
  await ringAction('end');
}

function updateMediaControls() {
  $('muteBtn').setAttribute('aria-pressed', String(muted));
  $('muteBtn').setAttribute('aria-label', t(muted ? 'unmute' : 'mute'));
  $('muteBtn').classList.toggle('is-off', muted);
  $('cameraBtn').setAttribute('aria-pressed', String(!cameraEnabled));
  $('cameraBtn').setAttribute('aria-label', t(cameraEnabled ? 'cameraOff' : 'cameraOn'));
  $('cameraBtn').classList.toggle('is-off', !cameraEnabled);
}

$('muteBtn').addEventListener('click', () => {
  muted = !muted;
  localStream?.getAudioTracks().forEach((track) => { track.enabled = !muted; });
  updateMediaControls();
});
$('cameraBtn').addEventListener('click', () => {
  cameraEnabled = !cameraEnabled;
  localStream?.getVideoTracks().forEach((track) => { track.enabled = cameraEnabled; });
  updateMediaControls();
});

function closeMedia() {
  clearMediaDeadline();
  releaseLocalMedia();
  peer?.close();
  peer = null;
  remoteStream = null;
  remoteDescriptionSet = false;
  offerHandling = false;
  queuedRemoteCandidates = [];
  seenIceCandidateIds.clear();
  $('mediaCard').classList.add('hidden');
}

function endSessionOnUnload() {
  if (unloadSent || !ring || !visitorAccessToken || ['declined', 'missed', 'cancelled', 'ended'].includes(ring.status)) return;
  unloadSent = true;
  const action = ring.status === 'accepted' ? 'end' : ring.status === 'media_requested' ? 'decline_media' : 'cancel';
  void fetch(`${config.supabase_url}/functions/v1/ring-action`, {
    method: 'POST', keepalive: true,
    headers: { 'Content-Type': 'application/json', apikey: config.supabase_publishable_key, Authorization: `Bearer ${visitorAccessToken}` },
    body: JSON.stringify({ ring_id: ring.ring_id, action }),
  });
}

addEventListener('pagehide', endSessionOnUnload);
addEventListener('beforeunload', () => { endSessionOnUnload(); releaseLocalMedia(); peer?.close(); });
bootstrap();
