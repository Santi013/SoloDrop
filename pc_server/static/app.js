function detectCurrentDevice() {
  const params = new URLSearchParams(window.location.search);
  const deviceFromUrl = params.get("device");
  if (deviceFromUrl === "pc" || deviceFromUrl === "ios") {
    localStorage.setItem("solodropDevice", deviceFromUrl);
    return deviceFromUrl;
  }

  const savedDevice = localStorage.getItem("solodropDevice");
  if (savedDevice === "pc" || savedDevice === "ios") {
    return savedDevice;
  }

  const isAppleMobile =
    /iPhone|iPad|iPod/i.test(navigator.userAgent) ||
    (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);

  return isAppleMobile ? "ios" : "pc";
}

const currentDevice = detectCurrentDevice();
const sender = currentDevice;
const messageList = document.querySelector("#messageList");
const historySidebar = document.querySelector("#historySidebar");
const sidebarOverlay = document.querySelector("#sidebarOverlay");
const historyList = document.querySelector("#historyList");
const openSidebarButton = document.querySelector("#openSidebarButton");
const closeSidebarButton = document.querySelector("#closeSidebarButton");
const messageInput = document.querySelector("#messageInput");
const fileInput = document.querySelector("#fileInput");
const composer = document.querySelector("#composer");
const connectionStatus = document.querySelector("#connectionStatus");
const clearChatButton = document.querySelector("#clearChatButton");
const imageViewer = document.querySelector("#imageViewer");
const viewerImage = document.querySelector("#viewerImage");
const viewerFileName = document.querySelector("#viewerFileName");
const viewerOpenOriginal = document.querySelector("#viewerOpenOriginal");
const closeViewerButton = document.querySelector("#closeViewerButton");
const contextMenuOverlay = document.querySelector("#contextMenuOverlay");
const messageContextMenu = document.querySelector("#messageContextMenu");
const copyMessageButton = document.querySelector("#copyMessageButton");
const saveMessageButton = document.querySelector("#saveMessageButton");
const settingsButton = document.querySelector("#settingsButton");
const settingsOverlay = document.querySelector("#settingsOverlay");
const closeSettingsButton = document.querySelector("#closeSettingsButton");
const autosaveToggle = document.querySelector("#autosaveToggle");
const pairingPanel = document.querySelector("#pairingPanel");
const pairingSummary = document.querySelector("#pairingSummary");
const pairingStatusBadge = document.querySelector("#pairingStatusBadge");
const pairingStatus = document.querySelector("#pairingStatus");
const deviceIdLabel = document.querySelector("#deviceIdLabel");
const deviceNameLabel = document.querySelector("#deviceNameLabel");
const trustStatusLabel = document.querySelector("#trustStatusLabel");
const requestPairCodeButton = document.querySelector("#requestPairCodeButton");
const copyPairCodeButton = document.querySelector("#copyPairCodeButton");
const pairCodeValue = document.querySelector("#pairCodeValue");
const pairCodeExpiry = document.querySelector("#pairCodeExpiry");
const pairingCodeInput = document.querySelector("#pairingCodeInput");
const pairButton = document.querySelector("#pairButton");
const repairPairingButton = document.querySelector("#repairPairingButton");
const resetPairingButton = document.querySelector("#resetPairingButton");
const serverUrlLabel = document.querySelector("#serverUrlLabel");
const bonjourStatusLabel = document.querySelector("#bonjourStatusLabel");
const manualAddressLabel = document.querySelector("#manualAddressLabel");
const trustedDevicesList = document.querySelector("#trustedDevicesList");
const pairingError = document.querySelector("#pairingError");
const dropZone = document.querySelector("#dropZone");
const toast = document.querySelector("#toast");

const AUTOSAVE_KEY = `solodropAutosave:${currentDevice}`;
const DEVICE_ID_KEY = "solodropDeviceId";
const DEVICE_TOKEN_KEY = "solodropDeviceToken";
const PAIRED_KEY = "solodropPaired";
let deviceId = getOrCreateDeviceId();

let allMessages = [];
let autosavedMessageIds = new Set(JSON.parse(localStorage.getItem("solodropAutosavedMessageIds") || "[]"));
let selectedHistoryKey = null;
let selectedCopyMessage = null;
let selectedContextMessage = null;
let longPressTimer = null;
let dragDepth = 0;
let sidebarTouchStartX = null;
let activeSocket = null;
let websocketReconnectTimer = null;
let lastPairCode = "";
let currentPairingStatus = "checking";

function createUuid() {
  if (window.crypto?.randomUUID) {
    return window.crypto.randomUUID();
  }

  return "10000000-1000-4000-8000-100000000000".replace(/[018]/g, (character) => {
    const randomByte = window.crypto?.getRandomValues
      ? window.crypto.getRandomValues(new Uint8Array(1))[0]
      : Math.floor(Math.random() * 256);
    const value = Number(character) ^ (randomByte & (15 >> (Number(character) / 4)));
    return value.toString(16);
  });
}

function normalizeUuid(value) {
  const match = String(value || "").trim().match(/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$/);
  return match ? match[0].toLowerCase() : "";
}

function getOrCreateDeviceId() {
  const saved = localStorage.getItem(DEVICE_ID_KEY);
  const normalizedSaved = normalizeUuid(saved);
  if (normalizedSaved) {
    if (saved !== normalizedSaved) {
      localStorage.setItem(DEVICE_ID_KEY, normalizedSaved);
    }
    return normalizedSaved;
  }

  const created = createUuid();
  localStorage.setItem(DEVICE_ID_KEY, created);
  return created;
}

function getDeviceToken() {
  return localStorage.getItem(DEVICE_TOKEN_KEY) || "";
}

function isPaired() {
  return localStorage.getItem(PAIRED_KEY) === "true";
}

function setPairingCredentials(result = {}) {
  localStorage.setItem(PAIRED_KEY, "true");
  const pairedDeviceId = normalizeUuid(result.deviceId || result.device_id);
  if (pairedDeviceId) {
    deviceId = pairedDeviceId;
    localStorage.setItem(DEVICE_ID_KEY, pairedDeviceId);
  }
  const deviceToken = result.deviceToken || result.device_token;
  if (deviceToken) {
    localStorage.setItem(DEVICE_TOKEN_KEY, deviceToken);
  }
}

function clearPairingCredentials({ resetDeviceId = false } = {}) {
  localStorage.removeItem(PAIRED_KEY);
  localStorage.removeItem(DEVICE_TOKEN_KEY);
  if (resetDeviceId) {
    localStorage.removeItem(DEVICE_ID_KEY);
    deviceId = getOrCreateDeviceId();
  }
  updateDeviceLabels();
}

function deviceName() {
  return `SoloDrop ${currentDeviceLabel()}`;
}

function authSearchParams() {
  const params = new URLSearchParams({ device_id: deviceId });
  const token = getDeviceToken();
  if (token) {
    params.set("device_token", token);
  }
  return params;
}

function authUrl(path) {
  const url = new URL(path, window.location.origin);
  for (const [key, value] of authSearchParams()) {
    url.searchParams.set(key, value);
  }
  return url.toString();
}

function formatTime(value) {
  return new Date(value).toLocaleString("ru-RU", {
    hour: "2-digit",
    minute: "2-digit",
    day: "2-digit",
    month: "2-digit",
  });
}

function parseMessageDate(message) {
  return new Date(message.createdAt);
}

function startOfLocalDay(date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

function dateKey(message) {
  const date = parseMessageDate(message);
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
}

function formatDateDivider(value) {
  const date = startOfLocalDay(new Date(value));
  const today = startOfLocalDay(new Date());
  const yesterday = new Date(today);
  yesterday.setDate(today.getDate() - 1);

  if (date.getTime() === today.getTime()) return "Сегодня";
  if (date.getTime() === yesterday.getTime()) return "Вчера";

  return date.toLocaleDateString("ru-RU", {
    day: "numeric",
    month: "long",
    year: "numeric",
  });
}

function monthLabelFromKey(key) {
  return new Date(`${key}T00:00:00`).toLocaleDateString("ru-RU", {
    month: "long",
    year: "numeric",
  });
}

function absoluteUrl(path) {
  return new URL(path, window.location.origin).toString();
}

function isImageMessage(message) {
  return message.mimeType?.startsWith("image/") || Boolean(message.previewUrl);
}

function isVideoMessage(message) {
  return message.mimeType?.startsWith("video/");
}

function isAudioMessage(message) {
  return message.mimeType?.startsWith("audio/");
}

function isMediaMessage(message) {
  return isImageMessage(message) || isVideoMessage(message) || isAudioMessage(message);
}

function isFileMessage(message) {
  return message.kind === "file" && Boolean(message.fileUrl);
}

function isMediaFile(file) {
  return file.type.startsWith("image/") || file.type.startsWith("video/") || file.type.startsWith("audio/");
}

function isOwnMessage(message) {
  return message.sender === currentDevice;
}

function senderLabel(message) {
  return message.sender === "pc" ? "ПК" : "iPhone";
}

function currentDeviceLabel() {
  return currentDevice === "pc" ? "ПК" : "iPhone";
}

function updateDeviceLabels() {
  deviceIdLabel.textContent = deviceId;
  deviceNameLabel.textContent = deviceName();
}

function applyDeviceChrome() {
  document.body.dataset.device = currentDevice;
  updateDeviceLabels();
  if (currentDevice === "ios") {
    clearChatButton.hidden = true;
  }
  autosaveToggle.checked = localStorage.getItem(AUTOSAVE_KEY) === "true";
}

function transferableTextForMessage(message) {
  if (message.kind === "file" && message.fileUrl) {
    return absoluteUrl(message.fileUrl);
  }

  return message.text || "";
}

function previewUrlForMessage(message) {
  return absoluteUrl(message.previewUrl || message.fileUrl);
}

function contentTypeForMessage(message) {
  if (message.kind === "file" && isMediaMessage(message)) return "media";
  if (message.kind === "file") return "file";
  if (message.kind === "link") return "link";
  return "text";
}

function showToast(text) {
  toast.textContent = text;
  toast.hidden = false;
  window.clearTimeout(showToast.timeoutId);
  showToast.timeoutId = window.setTimeout(() => {
    toast.hidden = true;
  }, 1300);
}

function setClientEnabled(enabled) {
  composer.classList.toggle("disabled", !enabled);
  messageInput.disabled = !enabled;
  fileInput.disabled = !enabled;
  composer.querySelector("button[type='submit']").disabled = !enabled;
}

function setPairingError(text = "") {
  pairingError.textContent = text;
  pairingError.hidden = !text;
}

function formatPairingDate(value) {
  if (!value) return "";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  return date.toLocaleString("ru-RU", {
    hour: "2-digit",
    minute: "2-digit",
    day: "2-digit",
    month: "2-digit",
  });
}

function setPairingStatus(status, text, { summary = text, error = "" } = {}) {
  currentPairingStatus = status;
  pairingPanel.dataset.state = status;
  pairingStatus.textContent = text;
  pairingSummary.textContent = summary;
  pairingStatusBadge.textContent = text;
  setPairingError(error);
  updateDeviceLabels();
}

function hidePairingPanel() {
  setPairingStatus("paired", "Подключено", { summary: "Device token принят сервером" });
  setClientEnabled(true);
}

function showPairingPanel(text, { status = "required", summary = text, error = "", open = false } = {}) {
  setPairingStatus(status, text, { summary, error });
  setClientEnabled(true);
  if (open) openSettings();
}

function clearPairCode() {
  lastPairCode = "";
  pairCodeValue.textContent = "Не запрошен";
  pairCodeExpiry.textContent = "Срок действия появится после запроса";
  copyPairCodeButton.disabled = true;
}

function setPairCode(code, expiresAt) {
  lastPairCode = code || "";
  pairCodeValue.textContent = lastPairCode || "Введите PIN с другого устройства";
  pairCodeExpiry.textContent = expiresAt ? `Действует до ${formatPairingDate(expiresAt)}` : "Срок действия не указан";
  copyPairCodeButton.disabled = !lastPairCode;
}

function disconnectWebSocket(reason = "Pairing changed") {
  window.clearTimeout(websocketReconnectTimer);
  websocketReconnectTimer = null;
  if (activeSocket) {
    activeSocket.soloDropIntentionalClose = true;
    activeSocket.close(1000, reason);
    activeSocket = null;
  }
}

async function checkServerHealth() {
  const response = await fetch("/health", { cache: "no-store" });
  if (!response.ok) {
    throw new Error("Server health check failed");
  }

  const payload = await response.json();
  if (payload.online !== true) {
    throw new Error("Server is not online");
  }
  return payload;
}

async function fetchConnectionConfig() {
  const response = await fetch("/connect/config", { cache: "no-store" });
  if (!response.ok) {
    throw new Error("Connection config unavailable");
  }
  return response.json();
}

async function fetchPairingStatus() {
  const response = await fetch(authUrl("/pair/status"), { cache: "no-store" });
  if (!response.ok) {
    throw new Error("Pairing status unavailable");
  }
  return response.json();
}

async function fetchTrustedDevices() {
  const response = await fetch("/devices", { cache: "no-store" });
  if (!response.ok) {
    throw new Error("Trusted devices unavailable");
  }
  return response.json();
}

function currentServerUrl(config) {
  return config?.serverUrl || window.location.origin;
}

function isManualAddressActive(config) {
  const host = window.location.hostname;
  return Boolean(host && host !== config?.stableHost && host !== config?.mdnsName);
}

function renderServerStatus(config) {
  serverUrlLabel.textContent = currentServerUrl(config);
  const manualEntry = config?.manualEntry || `${window.location.hostname}:${window.location.port || (window.location.protocol === "https:" ? "443" : "80")}`;
  manualAddressLabel.textContent = isManualAddressActive(config) ? `Активен: ${window.location.host}` : manualEntry;

  const bonjour = config?.bonjour;
  if (!bonjour) {
    bonjourStatusLabel.textContent = "Не найден";
    return;
  }
  if (bonjour.advertised) {
    bonjourStatusLabel.textContent = `Найден сервер · ${bonjour.serviceName || config.mdnsName}`;
    return;
  }
  if (!bonjour.enabled) {
    bonjourStatusLabel.textContent = "Не найден · Bonjour отключен";
    return;
  }
  if (!bonjour.available) {
    bonjourStatusLabel.textContent = "Не найден · zeroconf недоступен";
    return;
  }
  bonjourStatusLabel.textContent = "Не найден";
}

function renderTrustedDevices(devices = []) {
  if (!devices.length) {
    trustedDevicesList.textContent = "Нет подключённых устройств";
    return;
  }

  trustedDevicesList.innerHTML = "";
  for (const device of devices) {
    const item = document.createElement("div");
    item.className = "trusted-device-item";
    const isCurrent = normalizeUuid(device.device_id || device.deviceId) === deviceId;
    const name = device.device_name || device.deviceName || "Устройство";
    const lastSeen = formatPairingDate(device.last_seen_at || device.lastSeenAt);
    const title = document.createElement("strong");
    title.textContent = `${name}${isCurrent ? " · current" : ""}`;
    const meta = document.createElement("small");
    meta.textContent = `${device.device_id || device.deviceId}${lastSeen ? ` · last seen ${lastSeen}` : ""}`;
    item.append(title, meta);
    trustedDevicesList.append(item);
  }
}

function renderPairingStatus(statusPayload, devices = []) {
  updateDeviceLabels();
  const currentDevice = statusPayload?.device;
  const trusted = Boolean(statusPayload?.trusted);
  const tokenValid = Boolean(statusPayload?.tokenValid);
  const pairingEnabled = statusPayload?.pairingEnabled !== false;

  if (!pairingEnabled) {
    trustStatusLabel.textContent = "Trusted · pairing отключён";
    setPairingStatus("paired", "Подключено", { summary: "Pairing disabled on server" });
    return true;
  }

  if (tokenValid) {
    trustStatusLabel.textContent = "Trusted";
    setPairingStatus("paired", "Подключено", {
      summary: currentDevice?.lastSeenAt ? `Last seen ${formatPairingDate(currentDevice.lastSeenAt)}` : "Device token принят сервером",
    });
    if (currentDevice?.deviceName) {
      deviceNameLabel.textContent = currentDevice.deviceName;
    }
    return true;
  }

  if (trusted && isPaired()) {
    trustStatusLabel.textContent = "Token invalid";
    setPairingStatus("required", "Требуется повторный pairing", {
      summary: "Сервер знает device_id, но token не принят",
    });
    return false;
  }

  trustStatusLabel.textContent = trusted ? "Untrusted token" : "Untrusted";
  setPairingStatus("not-paired", "Не подключено", {
    summary: devices.length ? "Получите PIN или введите существующий" : "Нет trusted device для этого браузера",
  });
  return false;
}

async function refreshPairingSettings() {
  try {
    const [config, statusPayload, devices] = await Promise.all([
      fetchConnectionConfig(),
      fetchPairingStatus(),
      fetchTrustedDevices(),
    ]);
    renderServerStatus(config);
    renderTrustedDevices(devices);
    return renderPairingStatus(statusPayload, devices);
  } catch {
    serverUrlLabel.textContent = window.location.origin;
    bonjourStatusLabel.textContent = "Не найден";
    manualAddressLabel.textContent = `Активен: ${window.location.host}`;
    trustedDevicesList.textContent = "Сервер недоступен";
    trustStatusLabel.textContent = "Unknown";
    setPairingStatus("error", "Error state", {
      summary: "Сервер недоступен или status endpoint не ответил",
      error: "Не удалось обновить pairing status",
    });
    return false;
  }
}

async function verifyPairedDevice() {
  if (!isPaired()) {
    await refreshPairingSettings();
    return false;
  }

  const statusPayload = await fetchPairingStatus();
  const verified = renderPairingStatus(statusPayload);
  if (!verified && statusPayload.pairingEnabled !== false) {
    clearPairingCredentials();
    return false;
  }
  return verified;
}

async function requestPairCode() {
  requestPairCodeButton.disabled = true;
  setPairingError("");
  try {
    await checkServerHealth();
    const response = await fetch("/pair/code", { cache: "no-store" });
    if (!response.ok) {
      throw new Error("Could not create pairing code");
    }

    const payload = await response.json();
    if (payload.pairingEnabled === false) {
      setPairingCredentials(payload);
      await startAuthorizedClient();
      return;
    }

    setPairCode(payload.code, payload.expiresAt);
    pairingCodeInput.value = "";
    setPairingStatus("required", payload.code ? "Требуется pairing" : "Pairing required", {
      summary: payload.code ? "PIN готов внутри Settings" : "Введите PIN с другого устройства",
    });
  } catch (error) {
    setPairingStatus("error", "Error state", {
      summary: "Сервер недоступен",
      error: error.message || "Не удалось получить PIN",
    });
    showToast("Не удалось получить PIN");
  } finally {
    requestPairCodeButton.disabled = false;
  }
}

async function pairDevice() {
  const code = pairingCodeInput.value.trim();
  if (!code) {
    setPairingStatus(currentPairingStatus, pairingStatus.textContent, {
      summary: pairingSummary.textContent,
      error: "Введите PIN",
    });
    pairingCodeInput.focus();
    return;
  }

  pairButton.disabled = true;
  setPairingError("");
  try {
    await checkServerHealth();
    const response = await fetch("/pair/verify", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        code,
        device_id: deviceId,
        device_name: deviceName(),
      }),
    });

    if (!response.ok) {
      throw new Error(response.status === 401 ? "Неверный или просроченный PIN" : "Pairing failed");
    }

    const result = await response.json();
    if (!result.paired) {
      throw new Error("Pairing rejected");
    }

    setPairingCredentials(result);
    clearPairCode();
    pairingCodeInput.value = "";
    await startAuthorizedClient();
    await refreshPairingSettings();
  } catch (error) {
    setPairingStatus("error", "Error state", {
      summary: "PIN не принят",
      error: error.message || "Неверный или просроченный PIN",
    });
    showToast("Pairing не выполнен");
  } finally {
    pairButton.disabled = false;
  }
}

async function copyPairCode() {
  const copied = await copyTextToClipboard(lastPairCode);
  showToast(copied ? "PIN скопирован" : "Не удалось скопировать PIN");
}

async function repairPairing() {
  clearPairingCredentials();
  disconnectWebSocket("Re-pair");
  connectionStatus.textContent = `Требуется pairing · ${currentDeviceLabel()}`;
  showPairingPanel("Требуется повторный pairing", {
    status: "required",
    summary: "Получите новый PIN и подключите это устройство",
    open: true,
  });
  await requestPairCode();
}

async function resetPairing() {
  const previousDeviceId = deviceId;
  resetPairingButton.disabled = true;
  repairPairingButton.disabled = true;
  try {
    if (previousDeviceId) {
      await fetch(`/devices/${encodeURIComponent(previousDeviceId)}`, { method: "DELETE" });
    }
  } catch {
    showToast("Сервер недоступен, очищаю локальный pairing");
  } finally {
    clearPairingCredentials({ resetDeviceId: true });
    clearPairCode();
    pairingCodeInput.value = "";
    disconnectWebSocket("Pairing reset");
    connectionStatus.textContent = `Требуется pairing · ${currentDeviceLabel()}`;
    showPairingPanel("Требуется pairing", {
      status: "required",
      summary: "Локальные pairing credentials очищены",
      open: true,
    });
    await refreshPairingSettings();
    setPairingStatus("required", "Требуется pairing", {
      summary: "Локальные pairing credentials очищены",
    });
    resetPairingButton.disabled = false;
    repairPairingButton.disabled = false;
  }
}

async function startAuthorizedClient() {
  hidePairingPanel();
  connectionStatus.textContent = `Синхронизация · ${currentDeviceLabel()}`;
  await loadMessages();
  connectWebSocket();
}

async function bootstrapClient() {
  setClientEnabled(false);
  try {
    await checkServerHealth();
    if (await verifyPairedDevice()) {
      await startAuthorizedClient();
      return;
    }

    connectionStatus.textContent = `Требуется pairing · ${currentDeviceLabel()}`;
    showPairingPanel("Требуется pairing", {
      status: "required",
      summary: "Откройте Settings, получите PIN или введите существующий",
    });
  } catch (error) {
    connectionStatus.textContent = "Сервер недоступен";
    showPairingPanel("Error state", {
      status: "error",
      summary: "Проверьте адрес SoloDrop Server",
      error: error.message || "Сервер недоступен",
    });
  }
}

function ensurePairedForSend() {
  if (isPaired()) {
    return true;
  }

  connectionStatus.textContent = `Требуется pairing · ${currentDeviceLabel()}`;
  showPairingPanel("Требуется pairing", {
    status: "required",
    summary: "Подключите устройство в Settings",
    open: true,
  });
  return false;
}

async function copyTextToClipboard(text) {
  if (!text) return false;

  try {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(text);
    } else {
      const textarea = document.createElement("textarea");
      textarea.value = text;
      textarea.setAttribute("readonly", "");
      textarea.style.position = "fixed";
      textarea.style.left = "-9999px";
      textarea.style.opacity = "0";
      document.body.append(textarea);
      const focusedElement = document.activeElement;
      textarea.select();
      document.execCommand("copy");
      textarea.remove();
      window.getSelection()?.removeAllRanges();
      if (focusedElement instanceof HTMLElement) {
        focusedElement.focus({ preventScroll: true });
      } else {
        document.activeElement?.blur();
      }
    }
    return true;
  } catch {
    return false;
  }
}

async function copyMediaToClipboard(message) {
  if (!message.fileUrl) return false;

  const mediaUrl = absoluteUrl(message.fileUrl);
  try {
    if (!navigator.clipboard?.write || !window.ClipboardItem) {
      return false;
    }

    const response = await fetch(mediaUrl);
    const blob = await response.blob();
    await navigator.clipboard.write([
      new ClipboardItem({
        [blob.type || message.mimeType || "application/octet-stream"]: blob,
      }),
    ]);
    return true;
  } catch {
    return false;
  }
}

async function copyMessageToClipboard(message) {
  if (!message) return;

  if (isFileMessage(message)) {
    const copiedMedia = await copyMediaToClipboard(message);
    if (copiedMedia) {
      showToast(isMediaMessage(message) ? "Медиа скопировано" : "Файл скопирован");
      return;
    }
  }

  const copiedText = await copyTextToClipboard(transferableTextForMessage(message));
  showToast(copiedText ? "Скопировано" : "Не удалось скопировать");
}

function hideMessageContextMenu() {
  contextMenuOverlay.classList.remove("open");
  window.setTimeout(() => {
    if (!contextMenuOverlay.classList.contains("open")) {
      contextMenuOverlay.hidden = true;
    }
  }, 180);
  selectedContextMessage = null;
}

function openSidebar() {
  sidebarOverlay.hidden = false;
  historySidebar.classList.add("open");
  window.requestAnimationFrame(() => sidebarOverlay.classList.add("open"));
}

function closeSidebar() {
  historySidebar.classList.remove("open");
  sidebarOverlay.classList.remove("open");
  window.setTimeout(() => {
    if (!sidebarOverlay.classList.contains("open")) sidebarOverlay.hidden = true;
  }, 180);
}

function openSettings() {
  settingsOverlay.hidden = false;
  window.requestAnimationFrame(() => settingsOverlay.classList.add("open"));
  refreshPairingSettings();
}

function closeSettings() {
  settingsOverlay.classList.remove("open");
  window.setTimeout(() => {
    if (!settingsOverlay.classList.contains("open")) settingsOverlay.hidden = true;
  }, 180);
}

function shouldShowSaveAction(message) {
  return currentDevice === "pc" && isFileMessage(message);
}

function showMessageContextMenu({ message, source = "mouse" }) {
  if (!message) return;

  selectedCopyMessage = message;
  selectedContextMessage = message;
  saveMessageButton.hidden = !shouldShowSaveAction(message);
  contextMenuOverlay.hidden = false;
  messageContextMenu.dataset.source = source;
  window.requestAnimationFrame(() => contextMenuOverlay.classList.add("open"));
}

function hasActiveTextSelectionInside(element) {
  const selection = window.getSelection();
  if (!selection || selection.isCollapsed || !selection.toString().trim()) {
    return false;
  }

  const anchorNode = selection.anchorNode;
  const focusNode = selection.focusNode;
  return Boolean(
    anchorNode &&
    focusNode &&
    element.contains(anchorNode) &&
    element.contains(focusNode)
  );
}

function attachMessageInteractionHandlers(element, message) {
  element.draggable = isFileMessage(message);

  element.addEventListener("dragstart", (event) => {
    if (hasActiveTextSelectionInside(element)) {
      event.preventDefault();
      return;
    }
    fillDragData(event.dataTransfer, message);
  });

  element.addEventListener("contextmenu", (event) => {
    if (hasActiveTextSelectionInside(element)) {
      return;
    }
    event.preventDefault();
    showMessageContextMenu({
      message,
      source: "mouse",
    });
  });

  element.addEventListener("touchstart", (event) => {
    if (event.touches.length !== 1) return;
    event.preventDefault();
    const touch = event.touches[0];
    window.clearTimeout(longPressTimer);
    longPressTimer = window.setTimeout(() => {
      if (navigator.vibrate) navigator.vibrate(10);
      showMessageContextMenu({
        message,
        source: "touch",
      });
    }, 550);
  }, { passive: false });

  element.addEventListener("touchend", () => {
    window.clearTimeout(longPressTimer);
  });

  element.addEventListener("touchmove", () => {
    window.clearTimeout(longPressTimer);
  });
}

function saveMessageFile(message) {
  if (!isFileMessage(message)) return;
  const anchor = document.createElement("a");
  anchor.href = absoluteUrl(message.fileUrl);
  anchor.download = message.fileName || "solodrop-file";
  anchor.rel = "noreferrer";
  document.body.append(anchor);
  anchor.click();
  anchor.remove();
  showToast("Сохранение началось");
}

async function autosaveMessageFile(message) {
  if (!isFileMessage(message) || isOwnMessage(message) || !autosaveToggle.checked || autosavedMessageIds.has(message.id)) return false;

  autosavedMessageIds.add(message.id);
  localStorage.setItem("solodropAutosavedMessageIds", JSON.stringify([...autosavedMessageIds].slice(-500)));

  if (currentDevice === "ios" && window.webkit?.messageHandlers?.solodropAutosave) {
    window.webkit.messageHandlers.solodropAutosave.postMessage({
      url: absoluteUrl(message.fileUrl),
      previewUrl: message.previewUrl ? absoluteUrl(message.previewUrl) : null,
      fileName: message.fileName || "solodrop-file",
      mimeType: message.mimeType || "application/octet-stream",
    });
  } else {
    saveMessageFile(message);
  }

  showToast(`Файл сохранен: ${message.fileName || "файл"}`);
  return true;
}

function fillDragData(dataTransfer, message) {
  if (!dataTransfer) return;

  const type = contentTypeForMessage(message);
  const transferableText = transferableTextForMessage(message);
  dataTransfer.effectAllowed = "copy";

  if (type === "text") {
    dataTransfer.setData("text/plain", transferableText);
    return;
  }

  if (type === "link") {
    dataTransfer.setData("text/plain", transferableText);
    dataTransfer.setData("text/uri-list", transferableText);
    return;
  }

  if ((type === "media" || type === "file") && message.fileUrl) {
    const fileUrl = absoluteUrl(message.fileUrl);
    const fileName = message.fileName || "file";
    const mimeType = message.mimeType || "application/octet-stream";

    dataTransfer.setData("text/plain", fileUrl);
    dataTransfer.setData("text/uri-list", fileUrl);
    dataTransfer.setData("application/json", JSON.stringify({
      kind: type,
      fileName,
      fileUrl,
      mimeType,
    }));

    // Chromium-based desktop browsers understand DownloadURL for dragging a web file outward.
    dataTransfer.setData("DownloadURL", `${mimeType}:${fileName}:${fileUrl}`);
  }
}

function openImageViewer({ imageUrl, fileName }) {
  viewerImage.src = imageUrl;
  viewerImage.alt = fileName || "Изображение";
  viewerFileName.textContent = fileName || "Изображение";
  viewerOpenOriginal.href = imageUrl;
  imageViewer.hidden = false;
  document.body.classList.add("viewer-open");
}

function fileNameFromUrl(url) {
  try {
    return decodeURIComponent(new URL(url, window.location.origin).pathname.split("/").pop() || "clipboard-file");
  } catch {
    return "clipboard-file";
  }
}

async function fileFromSameOriginUrl(text) {
  const trimmed = text.trim();
  if (!trimmed) return null;

  let url;
  try {
    url = new URL(trimmed, window.location.origin);
  } catch {
    return null;
  }

  if (url.origin !== window.location.origin || !url.pathname.startsWith("/files/")) {
    return null;
  }

  const response = await fetch(url.toString());
  if (!response.ok) return null;

  const blob = await response.blob();
  const name = fileNameFromUrl(url.toString());
  return new File([blob], name, { type: blob.type || "application/octet-stream" });
}

async function filesFromClipboard(event) {
  const clipboard = event.clipboardData;
  if (!clipboard) return [];

  const files = Array.from(clipboard.files || []).filter((file) => file.size > 0);
  for (const item of Array.from(clipboard.items || [])) {
    if (item.kind !== "file") continue;
    const file = item.getAsFile();
    if (file && file.size > 0 && !files.some((candidate) => candidate.name === file.name && candidate.size === file.size)) {
      files.push(file);
    }
  }

  if (files.length > 0) return files;

  const text = clipboard.getData("text/plain");
  const fileFromUrl = await fileFromSameOriginUrl(text);
  return fileFromUrl ? [fileFromUrl] : [];
}

async function handlePaste(event) {
  if (event.solodropPasteHandled) return;
  event.solodropPasteHandled = true;

  const clipboard = event.clipboardData;
  const hasClipboardFile = Array.from(clipboard?.items || []).some((item) => item.kind === "file") ||
    Array.from(clipboard?.files || []).some((file) => file.size > 0);
  const pastedText = clipboard?.getData("text/plain") || "";
  const hasOwnFileUrl = Boolean(awaitableSameOriginFileUrl(pastedText));

  if (!hasClipboardFile && !hasOwnFileUrl) return;

  event.preventDefault();
  const files = await filesFromClipboard(event);
  if (files.length === 0) return;
  await sendDroppedFiles(files);
}

function awaitableSameOriginFileUrl(text) {
  const trimmed = text.trim();
  if (!trimmed) return null;

  try {
    const url = new URL(trimmed, window.location.origin);
    if (url.origin === window.location.origin && url.pathname.startsWith("/files/")) {
      return url;
    }
  } catch {
    return null;
  }

  return null;
}

function closeImageViewer() {
  imageViewer.hidden = true;
  viewerImage.src = "";
  document.body.classList.remove("viewer-open");
}

function renderMessage(message) {
  const row = document.createElement("div");
  row.className = `message-row ${isOwnMessage(message) ? "own" : "incoming"}`;
  row.dataset.messageId = message.id;

  const bubble = document.createElement("div");
  bubble.className = "bubble";
  attachMessageInteractionHandlers(bubble, message);

  if (message.kind === "file" && isImageMessage(message)) {
    const imageUrl = previewUrlForMessage(message);
    const link = document.createElement("button");
    link.className = "image-button";
    link.type = "button";
    link.addEventListener("click", () => {
      openImageViewer({ imageUrl, fileName: message.fileName });
    });

    const image = document.createElement("img");
    image.className = "image-preview";
    image.src = imageUrl;
    image.alt = message.fileName || "Изображение";
    image.loading = "lazy";
    image.addEventListener("error", () => {
      image.replaceWith(fileFallbackLink(message));
    }, { once: true });
    image.addEventListener("load", () => {
      messageList.scrollTop = messageList.scrollHeight;
    });

    const caption = document.createElement("div");
    caption.className = "file-caption";
    caption.textContent = message.fileName || "Изображение";

    link.append(image, caption);
    bubble.append(link);
  } else if (message.kind === "file" && isVideoMessage(message)) {
    const video = document.createElement("video");
    video.className = "media-preview";
    video.src = absoluteUrl(message.fileUrl);
    video.controls = true;
    video.preload = "metadata";

    const caption = document.createElement("div");
    caption.className = "file-caption";
    caption.textContent = message.fileName || "Видео";

    bubble.append(video, caption);
  } else if (message.kind === "file" && isAudioMessage(message)) {
    const audio = document.createElement("audio");
    audio.className = "audio-preview";
    audio.src = absoluteUrl(message.fileUrl);
    audio.controls = true;
    audio.preload = "metadata";

    const caption = document.createElement("div");
    caption.className = "file-caption";
    caption.textContent = message.fileName || "Аудио";

    bubble.append(audio, caption);
  } else if (message.kind === "file") {
    bubble.append(fileFallbackLink(message));
  } else if (message.kind === "link") {
    const link = document.createElement("a");
    link.className = "message-text";
    link.href = message.text;
    link.target = "_blank";
    link.rel = "noreferrer";
    link.textContent = message.text;
    bubble.append(link);
  } else {
    const text = document.createElement("div");
    text.className = "message-text";
    text.textContent = message.text;
    bubble.append(text);
  }

  const meta = document.createElement("div");
  meta.className = "meta";
  meta.textContent = `${senderLabel(message)} · ${formatTime(message.createdAt)}`;
  bubble.append(meta);

  if (isFileMessage(message) && autosavedMessageIds.has(message.id)) {
    const saved = document.createElement("div");
    saved.className = "saved-note";
    saved.textContent = "Файл сохранен";
    bubble.append(saved);
  }

  row.append(bubble);
  messageList.append(row);
}

function renderEmptyState() {
  const empty = document.createElement("div");
  empty.className = "empty-state";
  empty.innerHTML = `
    <h2>Текущий обмен</h2>
    <p>Отправьте файл или выберите дату в истории слева, чтобы посмотреть передачи за нужный день.</p>
  `;
  messageList.append(empty);
}

function fileFallbackLink(message) {
  const link = document.createElement("a");
  link.className = "file-link";
  link.href = absoluteUrl(message.fileUrl);
  link.target = "_blank";
  link.rel = "noreferrer";
  link.textContent = `📎 ${message.fileName}`;
  return link;
}

async function loadMessages() {
  const response = await fetch("/api/messages");
  const messages = (await response.json()).map(normalizeMessage).filter(Boolean);
  allMessages = mergeMessages(messages);
  await autosaveNewFiles(messages);
  renderMessageHistory();
}

function normalizeMessage(message) {
  if (!message) return null;
  return {
    ...message,
    kind: message.kind || message.type || "text",
    fileUrl: message.fileUrl || message.remoteFileUrl || null,
  };
}

function mergeMessages(messages) {
  const byId = new Map(allMessages.map((message) => [message.id, message]));
  messages.map(normalizeMessage).filter(Boolean).forEach((message) => byId.set(message.id, message));
  return Array.from(byId.values()).sort((a, b) => parseMessageDate(a) - parseMessageDate(b));
}

function renderMessageHistory() {
  messageList.innerHTML = "";
  renderSidebarHistory();

  const key = selectedHistoryKey || dateKey({ createdAt: new Date().toISOString() });
  const visibleMessages = allMessages.filter((message) => dateKey(message) === key);
  if (visibleMessages.length === 0) {
    renderEmptyState();
    return;
  }

  const divider = document.createElement("div");
  divider.className = "date-divider";
  divider.textContent = formatDateDivider(`${key}T00:00:00`);
  messageList.append(divider);
  visibleMessages.forEach(renderMessage);

  messageList.scrollTop = 0;
}

function renderSidebarHistory() {
  historyList.innerHTML = "";

  const fileGroups = new Map();
  for (const message of allMessages.filter(isFileMessage)) {
    const key = dateKey(message);
    if (!fileGroups.has(key)) fileGroups.set(key, []);
    fileGroups.get(key).push(message);
  }

  const keys = [...fileGroups.keys()].sort((a, b) => new Date(`${b}T00:00:00`) - new Date(`${a}T00:00:00`));
  let currentMonth = "";

  for (const key of keys) {
    const month = monthLabelFromKey(key);
    if (month !== currentMonth) {
      currentMonth = month;
      const monthTitle = document.createElement("div");
      monthTitle.className = "history-month";
      monthTitle.textContent = month;
      historyList.append(monthTitle);
    }

    const files = fileGroups.get(key);
    const button = document.createElement("button");
    button.type = "button";
    button.className = `history-item ${key === (selectedHistoryKey || dateKey({ createdAt: new Date().toISOString() })) ? "active" : ""}`;
    button.innerHTML = `<span>${formatDateDivider(`${key}T00:00:00`)}</span><small>${files.length} файл${files.length === 1 ? "" : "ов"}</small>`;
    button.addEventListener("click", () => {
      selectedHistoryKey = key;
      renderMessageHistory();
      closeSidebar();
    });
    historyList.append(button);
  }

  if (keys.length === 0) {
    const empty = document.createElement("div");
    empty.className = "history-empty";
    empty.textContent = "Файлов пока нет";
    historyList.append(empty);
  }
}

async function autosaveNewFiles(messages) {
  let changed = false;
  for (const message of messages) {
    changed = (await autosaveMessageFile(message)) || changed;
  }
  if (changed) renderMessageHistory();
}

async function sendText(text) {
  const timestamp = new Date().toISOString();
  const response = await fetch("/api/messages", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      id: createUuid(),
      sender,
      text,
      device_id: deviceId,
      device_token: getDeviceToken(),
      createdAt: timestamp,
      updatedAt: timestamp,
    }),
  });
  if (response.status === 401 || response.status === 403) {
    clearPairingCredentials();
    showPairingPanel("Требуется повторный pairing", {
      status: "required",
      summary: "Device token не принят сервером",
      open: true,
    });
  }
  if (!response.ok) throw new Error("Не удалось отправить сообщение");
}

async function sendFile(file) {
  const formData = new FormData();
  formData.append("sender", sender);
  formData.append("device_id", deviceId);
  const token = getDeviceToken();
  if (token) formData.append("device_token", token);
  formData.append("client_item_id", createUuid());
  formData.append("uploaded_file", file);

  const response = await fetch("/api/files", {
    method: "POST",
    body: formData,
  });
  if (response.status === 401 || response.status === 403) {
    clearPairingCredentials();
    showPairingPanel("Требуется повторный pairing", {
      status: "required",
      summary: "Device token не принят сервером",
      open: true,
    });
  }
  if (!response.ok) throw new Error("Не удалось отправить файл");
}

async function sendDroppedFiles(files) {
  if (!ensurePairedForSend()) return;

  const fileList = Array.from(files).filter((file) => file.size > 0);
  if (fileList.length === 0) return;

  const mediaCount = fileList.filter(isMediaFile).length;
  showToast(mediaCount > 0 ? `Отправка медиа: ${mediaCount}` : `Отправка файлов: ${fileList.length}`);

  for (const file of fileList) {
    try {
      await sendFile(file);
    } catch {
      showToast(`Не удалось отправить: ${file.name}`);
      return;
    }
  }

  showToast(fileList.length === 1 ? "Файл отправлен" : `Файлов отправлено: ${fileList.length}`);
}

function showDropZone() {
  dropZone.hidden = false;
  document.body.classList.add("dragging-file");
}

function hideDropZone() {
  dragDepth = 0;
  dropZone.hidden = true;
  document.body.classList.remove("dragging-file");
}

function hasFiles(event) {
  return Array.from(event.dataTransfer?.types || []).includes("Files");
}

async function clearChat() {
  const confirmed = window.confirm("Очистить весь чат и удалить загруженные файлы?");
  if (!confirmed) return;

  const response = await fetch(authUrl("/api/messages"), {
    method: "DELETE",
  });
  if (!response.ok) {
    window.alert("Не удалось очистить чат.");
    return;
  }

  messageList.innerHTML = "";
  historyList.innerHTML = "";
  allMessages = [];
  selectedHistoryKey = null;
  hideMessageContextMenu();
  closeImageViewer();
}

function connectWebSocket() {
  window.clearTimeout(websocketReconnectTimer);
  if (activeSocket) {
    activeSocket.soloDropIntentionalClose = true;
    activeSocket.close(1000, "Reconnect");
  }

  const protocol = window.location.protocol === "https:" ? "wss" : "ws";
  const socket = new WebSocket(`${protocol}://${window.location.host}/ws?${authSearchParams().toString()}`);
  activeSocket = socket;
  let pingTimer = null;

  socket.addEventListener("open", () => {
    connectionStatus.textContent = `Онлайн в локальной сети · ${currentDeviceLabel()}`;
    pingTimer = window.setInterval(() => {
      if (socket.readyState === WebSocket.OPEN) {
        socket.send(JSON.stringify({ type: "ping" }));
      }
    }, 25000);
  });

  socket.addEventListener("message", (event) => {
    const payload = JSON.parse(event.data);
    if (payload.type === "message" || payload.type === "item.upserted") {
      const message = normalizeMessage(payload.message || payload.payload);
      if (!message) return;
      allMessages = mergeMessages([message]);
      autosaveMessageFile(message).then(() => renderMessageHistory());
    }
    if (payload.type === "clear" || payload.type === "items.cleared") {
      allMessages = [];
      messageList.innerHTML = "";
      hideMessageContextMenu();
      closeImageViewer();
    }
  });

  socket.addEventListener("close", (event) => {
    if (pingTimer) {
      window.clearInterval(pingTimer);
    }
    if (activeSocket === socket) {
      activeSocket = null;
    }
    if (socket.soloDropIntentionalClose) {
      return;
    }
    if (event.code === 1008) {
      clearPairingCredentials();
      connectionStatus.textContent = `Требуется pairing · ${currentDeviceLabel()}`;
      showPairingPanel("Требуется повторный pairing", {
        status: "required",
        summary: "WebSocket отклонён: device_token не принят",
      });
      return;
    }
    if (!isPaired()) {
      return;
    }
    connectionStatus.textContent = "Переподключение...";
    websocketReconnectTimer = window.setTimeout(connectWebSocket, 1500);
  });
}

composer.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (!ensurePairedForSend()) return;

  const text = messageInput.value.trim();
  if (!text) return;
  messageInput.value = "";
  await sendText(text);
});

autosaveToggle.addEventListener("change", () => {
  localStorage.setItem(AUTOSAVE_KEY, String(autosaveToggle.checked));
  showToast(autosaveToggle.checked ? "Автосохранение включено" : "Автосохранение выключено");
  if (autosaveToggle.checked) autosaveNewFiles(allMessages);
});

openSidebarButton.addEventListener("click", openSidebar);
closeSidebarButton.addEventListener("click", closeSidebar);
sidebarOverlay.addEventListener("click", closeSidebar);
settingsButton.addEventListener("click", openSettings);
closeSettingsButton.addEventListener("click", closeSettings);
settingsOverlay.addEventListener("click", (event) => {
  if (event.target === settingsOverlay) closeSettings();
});
requestPairCodeButton.addEventListener("click", requestPairCode);
copyPairCodeButton.addEventListener("click", copyPairCode);
pairButton.addEventListener("click", pairDevice);
repairPairingButton.addEventListener("click", repairPairing);
resetPairingButton.addEventListener("click", resetPairing);
pairingCodeInput.addEventListener("keydown", (event) => {
  if (event.key === "Enter") {
    event.preventDefault();
    pairDevice();
  }
});

fileInput.addEventListener("change", async () => {
  if (!ensurePairedForSend()) {
    fileInput.value = "";
    return;
  }

  const file = fileInput.files?.[0];
  if (!file) return;
  await sendFile(file);
  fileInput.value = "";
});

composer.addEventListener("paste", handlePaste);

window.addEventListener("dragenter", (event) => {
  if (!hasFiles(event)) return;
  event.preventDefault();
  dragDepth += 1;
  showDropZone();
});

window.addEventListener("dragover", (event) => {
  if (!hasFiles(event)) return;
  event.preventDefault();
  event.dataTransfer.dropEffect = "copy";
  showDropZone();
});

window.addEventListener("dragleave", (event) => {
  if (!hasFiles(event)) return;
  dragDepth = Math.max(0, dragDepth - 1);
  if (dragDepth === 0) hideDropZone();
});

window.addEventListener("drop", async (event) => {
  if (!hasFiles(event)) return;
  event.preventDefault();
  const files = event.dataTransfer.files;
  hideDropZone();
  await sendDroppedFiles(files);
});

if (!clearChatButton.hidden) {
  clearChatButton.addEventListener("click", clearChat);
}
copyMessageButton.addEventListener("click", async () => {
  await copyMessageToClipboard(selectedCopyMessage);
  hideMessageContextMenu();
});
saveMessageButton.addEventListener("click", () => {
  saveMessageFile(selectedContextMessage);
  hideMessageContextMenu();
});
document.addEventListener("click", (event) => {
  if (event.target === contextMenuOverlay) {
    hideMessageContextMenu();
  }
});
document.addEventListener("scroll", hideMessageContextMenu, true);

document.addEventListener("gesturestart", (event) => event.preventDefault());
document.addEventListener("gesturechange", (event) => event.preventDefault());
document.addEventListener("gestureend", (event) => event.preventDefault());
document.addEventListener("touchmove", (event) => {
  if (currentDevice === "ios" && event.touches.length > 1) {
    event.preventDefault();
  }
}, { passive: false });

document.addEventListener("touchstart", (event) => {
  sidebarTouchStartX = event.touches[0]?.clientX ?? null;
}, { passive: true });

document.addEventListener("touchend", (event) => {
  if (sidebarTouchStartX === null) return;
  const endX = event.changedTouches[0]?.clientX ?? sidebarTouchStartX;
  if (sidebarTouchStartX < 26 && endX - sidebarTouchStartX > 70) {
    openSidebar();
  }
  sidebarTouchStartX = null;
}, { passive: true });

applyDeviceChrome();
bootstrapClient();

closeViewerButton.addEventListener("click", closeImageViewer);
imageViewer.addEventListener("click", (event) => {
  if (event.target === imageViewer) closeImageViewer();
});
window.addEventListener("keydown", (event) => {
  if (event.key === "Escape" && !imageViewer.hidden) closeImageViewer();
});
