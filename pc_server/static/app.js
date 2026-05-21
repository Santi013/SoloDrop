const LANGUAGE_KEY = "solodropLanguage";
const SUPPORTED_LANGUAGES = ["ru", "en"];
const TRANSLATIONS = {
  ru: {
    "action.attachFile": "Прикрепить файл",
    "action.clearChat": "Очистить чат",
    "action.clearChatConfirm": "Очистить весь чат и удалить загруженные файлы?",
    "action.close": "Закрыть",
    "action.copy": "Скопировать",
    "action.refresh": "Обновить",
    "action.save": "Сохранить",
    "action.send": "Отправить",
    "connection.connecting": "Подключение...",
    "connection.online": "Онлайн в локальной сети · {device}",
    "connection.pairingRequired": "Требуется pairing · {device}",
    "connection.reconnecting": "Переподключение...",
    "connection.serverUnavailable": "Сервер недоступен",
    "connection.syncing": "Синхронизация · {device}",
    "date.today": "Сегодня",
    "date.yesterday": "Вчера",
    "device.current": "текущее",
    "device.ios": "iPhone",
    "device.pc": "ПК",
    "device.serverHost": "Хост сервера",
    "device.unknown": "Устройство",
    "device.webAdmin": "SoloDrop Web",
    "devices.connected": "Подключенные устройства",
    "devices.empty": "Нет подключенных устройств",
    "devices.lastSeen": "был в сети {date}",
    "devices.serverUnavailable": "Сервер недоступен",
    "drop.subtitle": "Изображения, видео и аудио будут отправлены в SoloDrop",
    "drop.title": "Отпустите файлы здесь",
    "error.clearChat": "Не удалось очистить чат.",
    "error.pairingRejected": "Pairing rejected",
    "error.pairingStatus": "Не удалось обновить статус pairing",
    "error.pinExpired": "Неверный или просроченный PIN",
    "error.pinRequired": "Введите PIN",
    "error.pinUnavailable": "Не удалось получить PIN",
    "error.sendFile": "Не удалось отправить файл",
    "error.sendMessage": "Не удалось отправить сообщение",
    "error.serverAddress": "Проверьте адрес SoloDrop Server",
    "error.serverUnavailable": "Сервер недоступен",
    "file.audio": "Аудио",
    "file.file": "файл",
    "file.image": "Изображение",
    "file.saved": "Файл сохранен",
    "file.video": "Видео",
    "history.aria": "История передач",
    "history.empty": "Файлов пока нет",
    "history.subtitle": "Передачи по датам",
    "history.title": "История",
    "messages.aria": "Лента сообщений",
    "messages.emptyBody": "Отправьте файл или выберите дату в истории слева, чтобы посмотреть передачи за нужный день.",
    "messages.emptyTitle": "Текущий обмен",
    "messages.placeholder": "Сообщение",
    "pairing.codeUnavailable": "PIN недоступен",
    "pairing.device": "Устройство",
    "pairing.deviceId": "ID устройства",
    "pairing.pinTitle": "PIN для подключения устройства",
    "pairing.qrLabel": "QR-код",
    "pairing.status.admin": "Admin",
    "pairing.status.checking": "Проверка сервера...",
    "pairing.status.connected": "Подключено",
    "pairing.status.error": "Ошибка",
    "pairing.status.notPaired": "Не подключено",
    "pairing.status.repair": "Требуется повторный pairing",
    "pairing.status.required": "Требуется pairing",
    "pairing.statusLabel": "Статус pairing",
    "pairing.summary.admin": "PIN/QR для внешних устройств",
    "pairing.summary.cleanCredentials": "Локальные pairing credentials очищены",
    "pairing.summary.connectInSettings": "Подключите устройство в настройках",
    "pairing.summary.getPin": "Получите PIN или введите существующий",
    "pairing.summary.knownButTokenRejected": "Сервер знает ID устройства, но token не принят",
    "pairing.summary.noBrowserDevice": "Нет trusted device для этого браузера",
    "pairing.summary.repair": "Получите новый PIN и подключите это устройство",
    "pairing.summary.serverStatusUnavailable": "Сервер недоступен или endpoint статуса не ответил",
    "pairing.summary.tokenAccepted": "Device token принят сервером",
    "pairing.summary.tokenRejected": "Device token не принят сервером",
    "pairing.summary.websocketRejected": "WebSocket отклонен: device_token не принят",
    "pairing.title": "Pairing / Подключение устройств",
    "pairing.trust.admin": "Доверенная admin-сессия",
    "pairing.trust.notTrusted": "Не доверенное",
    "pairing.trust.tokenInvalid": "Token недействителен",
    "pairing.trust.tokenRequired": "Нужен token",
    "pairing.trust.trusted": "Доверенное",
    "pairing.trust.unknown": "Неизвестно",
    "pairing.trustedStatus": "Статус доверия",
    "server.discovery": "Bonjour / обнаружение",
    "server.manualActive": "Активен: {host}",
    "server.manualAddress": "Ручной адрес",
    "server.notFound": "Не найден",
    "server.notFoundBonjourDisabled": "Не найден · Bonjour отключен",
    "server.notFoundZeroconf": "Не найден · zeroconf недоступен",
    "server.serverFound": "Найден сервер · {name}",
    "server.url": "URL сервера",
    "settings.autosave": "Автосохранение",
    "settings.autosaveSubtitle": "Полученные файлы будут сохраняться автоматически",
    "settings.language": "Язык",
    "settings.languageSubtitle": "Интерфейс SoloDrop",
    "settings.subtitle": "Параметры этого устройства",
    "settings.title": "Настройки",
    "toast.autosaveOff": "Автосохранение выключено",
    "toast.autosaveOn": "Автосохранение включено",
    "toast.copied": "Скопировано",
    "toast.copyFailed": "Не удалось скопировать",
    "toast.fileCopied": "Файл скопирован",
    "toast.fileSaved": "Файл сохранен: {name}",
    "toast.fileSent": "Файл отправлен",
    "toast.filesSent": "Файлов отправлено: {count}",
    "toast.mediaCopied": "Медиа скопировано",
    "toast.pairingFailed": "Pairing не выполнен",
    "toast.pinCopied": "PIN скопирован",
    "toast.pinCopyFailed": "Не удалось скопировать PIN",
    "toast.pinUnavailable": "Не удалось получить PIN",
    "toast.savingStarted": "Сохранение началось",
    "toast.sendFailed": "Не удалось отправить: {name}",
    "toast.sendingFiles": "Отправка файлов: {count}",
    "toast.sendingMedia": "Отправка медиа: {count}",
    "toast.serverUnavailableClearLocal": "Сервер недоступен, очищаю локальный pairing",
    "viewer.original": "Оригинал",
  },
  en: {
    "action.attachFile": "Attach file",
    "action.clearChat": "Clear chat",
    "action.clearChatConfirm": "Clear the whole chat and delete uploaded files?",
    "action.close": "Close",
    "action.copy": "Copy",
    "action.refresh": "Refresh",
    "action.save": "Save",
    "action.send": "Send",
    "connection.connecting": "Connecting...",
    "connection.online": "Online on local network · {device}",
    "connection.pairingRequired": "Pairing required · {device}",
    "connection.reconnecting": "Reconnecting...",
    "connection.serverUnavailable": "Server unavailable",
    "connection.syncing": "Syncing · {device}",
    "date.today": "Today",
    "date.yesterday": "Yesterday",
    "device.current": "current",
    "device.ios": "iPhone",
    "device.pc": "PC",
    "device.serverHost": "Server host",
    "device.unknown": "Device",
    "device.webAdmin": "SoloDrop Web",
    "devices.connected": "Connected devices",
    "devices.empty": "No connected devices",
    "devices.lastSeen": "last seen {date}",
    "devices.serverUnavailable": "Server unavailable",
    "drop.subtitle": "Images, video, and audio will be sent to SoloDrop",
    "drop.title": "Drop files here",
    "error.clearChat": "Could not clear the chat.",
    "error.pairingRejected": "Pairing rejected",
    "error.pairingStatus": "Could not update pairing status",
    "error.pinExpired": "Invalid or expired PIN",
    "error.pinRequired": "Enter PIN",
    "error.pinUnavailable": "Could not get PIN",
    "error.sendFile": "Could not send file",
    "error.sendMessage": "Could not send message",
    "error.serverAddress": "Check the SoloDrop Server address",
    "error.serverUnavailable": "Server unavailable",
    "file.audio": "Audio",
    "file.file": "file",
    "file.image": "Image",
    "file.saved": "File saved",
    "file.video": "Video",
    "history.aria": "Transfer history",
    "history.empty": "No files yet",
    "history.subtitle": "Transfers by date",
    "history.title": "History",
    "messages.aria": "Message feed",
    "messages.emptyBody": "Send a file or choose a date in history to view transfers for that day.",
    "messages.emptyTitle": "Current exchange",
    "messages.placeholder": "Message",
    "pairing.codeUnavailable": "PIN unavailable",
    "pairing.device": "Device",
    "pairing.deviceId": "Device ID",
    "pairing.pinTitle": "PIN for connecting a device",
    "pairing.qrLabel": "QR code",
    "pairing.status.admin": "Admin",
    "pairing.status.checking": "Checking server...",
    "pairing.status.connected": "Connected",
    "pairing.status.error": "Error state",
    "pairing.status.notPaired": "Not connected",
    "pairing.status.repair": "Pair again required",
    "pairing.status.required": "Pairing required",
    "pairing.statusLabel": "Pairing status",
    "pairing.summary.admin": "PIN/QR for external devices",
    "pairing.summary.cleanCredentials": "Local pairing credentials cleared",
    "pairing.summary.connectInSettings": "Connect the device in Settings",
    "pairing.summary.getPin": "Get a PIN or enter an existing one",
    "pairing.summary.knownButTokenRejected": "The server knows this device_id, but the token was rejected",
    "pairing.summary.noBrowserDevice": "No trusted device for this browser",
    "pairing.summary.repair": "Get a new PIN and connect this device",
    "pairing.summary.serverStatusUnavailable": "Server unavailable or status endpoint did not respond",
    "pairing.summary.tokenAccepted": "Device token accepted by server",
    "pairing.summary.tokenRejected": "Device token rejected by server",
    "pairing.summary.websocketRejected": "WebSocket rejected: device_token was not accepted",
    "pairing.title": "Pairing / Connect devices",
    "pairing.trust.admin": "Trusted admin",
    "pairing.trust.notTrusted": "Not trusted",
    "pairing.trust.tokenInvalid": "Token invalid",
    "pairing.trust.tokenRequired": "Token required",
    "pairing.trust.trusted": "Trusted",
    "pairing.trust.unknown": "Unknown",
    "pairing.trustedStatus": "Trusted status",
    "server.discovery": "Bonjour / discovery",
    "server.manualActive": "Active: {host}",
    "server.manualAddress": "Manual address",
    "server.notFound": "Not found",
    "server.notFoundBonjourDisabled": "Not found · Bonjour disabled",
    "server.notFoundZeroconf": "Not found · zeroconf unavailable",
    "server.serverFound": "Server found · {name}",
    "server.url": "Server URL",
    "settings.autosave": "Autosave",
    "settings.autosaveSubtitle": "Received files will be saved automatically",
    "settings.language": "Language",
    "settings.languageSubtitle": "SoloDrop interface",
    "settings.subtitle": "This device settings",
    "settings.title": "Settings",
    "toast.autosaveOff": "Autosave off",
    "toast.autosaveOn": "Autosave on",
    "toast.copied": "Copied",
    "toast.copyFailed": "Could not copy",
    "toast.fileCopied": "File copied",
    "toast.fileSaved": "File saved: {name}",
    "toast.fileSent": "File sent",
    "toast.filesSent": "Files sent: {count}",
    "toast.mediaCopied": "Media copied",
    "toast.pairingFailed": "Pairing failed",
    "toast.pinCopied": "PIN copied",
    "toast.pinCopyFailed": "Could not copy PIN",
    "toast.pinUnavailable": "Could not get PIN",
    "toast.savingStarted": "Saving started",
    "toast.sendFailed": "Could not send: {name}",
    "toast.sendingFiles": "Sending files: {count}",
    "toast.sendingMedia": "Sending media: {count}",
    "toast.serverUnavailableClearLocal": "Server unavailable, clearing local pairing",
    "viewer.original": "Original",
  },
};

function normalizeLanguage(value) {
  const language = String(value || "").toLowerCase().split("-")[0];
  return SUPPORTED_LANGUAGES.includes(language) ? language : "";
}

function detectInitialLanguage() {
  const saved = normalizeLanguage(localStorage.getItem(LANGUAGE_KEY));
  if (saved) return saved;

  const languages = navigator.languages?.length ? navigator.languages : [navigator.language];
  for (const language of languages) {
    const normalized = normalizeLanguage(language);
    if (normalized) return normalized;
  }
  return "en";
}

let currentLanguage = detectInitialLanguage();

function languageLocale() {
  return currentLanguage === "ru" ? "ru-RU" : "en-US";
}

function t(key, params = {}) {
  const template = TRANSLATIONS[currentLanguage]?.[key] ?? TRANSLATIONS.en[key] ?? key;
  return template.replace(/\{([a-zA-Z0-9_]+)\}/g, (_, name) => String(params[name] ?? ""));
}

function fileCountLabel(count) {
  if (currentLanguage === "en") {
    return `${count} ${count === 1 ? "file" : "files"}`;
  }

  const lastTwo = count % 100;
  const last = count % 10;
  let suffix = "файлов";
  if (lastTwo < 11 || lastTwo > 14) {
    if (last === 1) suffix = "файл";
    if (last >= 2 && last <= 4) suffix = "файла";
  }
  return `${count} ${suffix}`;
}

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
const languageSelect = document.querySelector("#languageSelect");
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
const pairQrImage = document.querySelector("#pairQrImage");
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
const ADMIN_SESSION_TOKEN_KEY = "solodropAdminSessionToken";
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
let adminSessionToken = sessionStorage.getItem(ADMIN_SESSION_TOKEN_KEY) || "";
let pairCodeRequest = null;
let currentPairingStatus = "checking";
let currentConnectionStatus = { key: "connecting", params: {} };
let lastConnectionConfig = null;
let lastPairingStatusPayload = null;
let lastTrustedDevices = [];

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

function isAdminSessionReady() {
  return Boolean(adminSessionToken);
}

function adminHeaders(extraHeaders = {}) {
  if (!isAdminSessionReady()) return extraHeaders;
  return {
    ...extraHeaders,
    "X-SoloDrop-Admin-Session": adminSessionToken,
  };
}

async function ensureAdminSession() {
  if (isAdminSessionReady()) return true;

  const response = await fetch("/admin/session", {
    method: "POST",
    cache: "no-store",
  });
  if (!response.ok) {
    throw new Error("Admin session unavailable");
  }

  const payload = await response.json();
  adminSessionToken = payload.adminSessionToken || payload.admin_session_token || "";
  if (!adminSessionToken) {
    throw new Error("Admin session token missing");
  }
  sessionStorage.setItem(ADMIN_SESSION_TOKEN_KEY, adminSessionToken);
  localStorage.removeItem(PAIRED_KEY);
  localStorage.removeItem(DEVICE_TOKEN_KEY);
  updateDeviceLabels();
  return true;
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
  if (isAdminSessionReady()) {
    return new URLSearchParams({ admin_session: adminSessionToken });
  }

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

function applyStaticTranslations() {
  document.documentElement.lang = currentLanguage;
  document.querySelectorAll("[data-i18n]").forEach((element) => {
    element.textContent = t(element.dataset.i18n);
  });
  document.querySelectorAll("[data-i18n-title]").forEach((element) => {
    element.title = t(element.dataset.i18nTitle);
  });
  document.querySelectorAll("[data-i18n-placeholder]").forEach((element) => {
    element.placeholder = t(element.dataset.i18nPlaceholder);
  });
  document.querySelectorAll("[data-i18n-aria-label]").forEach((element) => {
    element.setAttribute("aria-label", t(element.dataset.i18nAriaLabel));
  });
  document.querySelectorAll("[data-i18n-alt]").forEach((element) => {
    element.alt = t(element.dataset.i18nAlt);
  });
  if (languageSelect) {
    languageSelect.value = currentLanguage;
  }
}

function setConnectionStatus(key, params = {}) {
  currentConnectionStatus = { key, params };
  connectionStatus.textContent = t(`connection.${key}`, params);
}

function renderConnectionStatus() {
  const params = { ...currentConnectionStatus.params };
  if (["online", "pairingRequired", "syncing"].includes(currentConnectionStatus.key)) {
    params.device = currentDeviceLabel();
  }
  setConnectionStatus(currentConnectionStatus.key, params);
}

function renderLanguageSensitiveState() {
  renderConnectionStatus();
  updateDeviceLabels();
  if (lastConnectionConfig) {
    renderServerStatus(lastConnectionConfig);
  }
  if (lastTrustedDevices) {
    renderTrustedDevices(lastTrustedDevices);
  }
  if (lastPairingStatusPayload) {
    renderPairingStatus(lastPairingStatusPayload, lastTrustedDevices);
  } else if (currentPairingStatus === "checking") {
    setPairingStatus("checking", t("pairing.status.checking"));
  }
  const previousMessageScroll = messageList.scrollTop;
  renderMessageHistory();
  messageList.scrollTop = previousMessageScroll;
}

function setLanguage(language, { persist = true } = {}) {
  const normalized = normalizeLanguage(language) || "en";
  currentLanguage = normalized;
  if (persist) {
    localStorage.setItem(LANGUAGE_KEY, normalized);
  }
  applyStaticTranslations();
  renderLanguageSensitiveState();
}

function formatTime(value) {
  return new Date(value).toLocaleString(languageLocale(), {
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

  if (date.getTime() === today.getTime()) return t("date.today");
  if (date.getTime() === yesterday.getTime()) return t("date.yesterday");

  return date.toLocaleDateString(languageLocale(), {
    day: "numeric",
    month: "long",
    year: "numeric",
  });
}

function monthLabelFromKey(key) {
  return new Date(`${key}T00:00:00`).toLocaleDateString(languageLocale(), {
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
  return message.sender === "pc" ? t("device.pc") : t("device.ios");
}

function currentDeviceLabel() {
  return currentDevice === "pc" ? t("device.pc") : t("device.ios");
}

function updateDeviceLabels() {
  if (isAdminSessionReady()) {
    deviceIdLabel.textContent = t("device.serverHost");
    deviceNameLabel.textContent = t("device.webAdmin");
    return;
  }
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
  return date.toLocaleString(languageLocale(), {
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
  if (isAdminSessionReady()) {
    setPairingStatus("paired", t("pairing.status.admin"), { summary: t("pairing.summary.admin") });
  } else {
    setPairingStatus("paired", t("pairing.status.connected"), { summary: t("pairing.summary.tokenAccepted") });
  }
  setClientEnabled(true);
}

function showPairingPanel(text, { status = "required", summary = text, error = "", open = false } = {}) {
  setPairingStatus(status, text, { summary, error });
  setClientEnabled(true);
  if (open) openSettings();
}

function clearPairCode() {
  lastPairCode = "";
  pairCodeValue.textContent = "------";
  copyPairCodeButton.disabled = true;
  if (pairQrImage) {
    pairQrImage.hidden = true;
    pairQrImage.removeAttribute("src");
  }
}

function setPairCode(code, expiresAt, qrUrl) {
  lastPairCode = code || "";
  pairCodeValue.textContent = lastPairCode ? lastPairCode.split("").join(" ") : "------";
  copyPairCodeButton.disabled = !lastPairCode;
  if (pairQrImage) {
    if (qrUrl && lastPairCode) {
      const url = new URL(qrUrl, window.location.origin);
      url.searchParams.set("_", String(Date.now()));
      pairQrImage.src = url.toString();
      pairQrImage.hidden = false;
    } else {
      pairQrImage.hidden = true;
      pairQrImage.removeAttribute("src");
    }
  }
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
  const response = await fetch(authUrl("/pair/status"), {
    cache: "no-store",
    headers: adminHeaders(),
  });
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
  manualAddressLabel.textContent = isManualAddressActive(config) ? t("server.manualActive", { host: window.location.host }) : manualEntry;

  const bonjour = config?.bonjour;
  if (!bonjour) {
    bonjourStatusLabel.textContent = t("server.notFound");
    return;
  }
  if (bonjour.advertised) {
    bonjourStatusLabel.textContent = t("server.serverFound", { name: bonjour.serviceName || config.mdnsName });
    return;
  }
  if (!bonjour.enabled) {
    bonjourStatusLabel.textContent = t("server.notFoundBonjourDisabled");
    return;
  }
  if (!bonjour.available) {
    bonjourStatusLabel.textContent = t("server.notFoundZeroconf");
    return;
  }
  bonjourStatusLabel.textContent = t("server.notFound");
}

function renderTrustedDevices(devices = []) {
  const visibleDevices = devices.filter((device) => !isBrowserDeviceEntry(device));
  if (!visibleDevices.length) {
    trustedDevicesList.textContent = t("devices.empty");
    return;
  }

  trustedDevicesList.innerHTML = "";
  for (const device of visibleDevices) {
    const item = document.createElement("div");
    item.className = "trusted-device-item";
    const isCurrent = normalizeUuid(device.device_id || device.deviceId) === deviceId;
    const name = device.device_name || device.deviceName || t("device.unknown");
    const lastSeen = formatPairingDate(device.last_seen_at || device.lastSeenAt);
    const title = document.createElement("strong");
    title.textContent = `${name}${isCurrent ? ` · ${t("device.current")}` : ""}`;
    const meta = document.createElement("small");
    meta.textContent = `${device.device_id || device.deviceId}${lastSeen ? ` · ${t("devices.lastSeen", { date: lastSeen })}` : ""}`;
    item.append(title, meta);
    trustedDevicesList.append(item);
  }
}

function isBrowserDeviceEntry(device) {
  const normalizedId = normalizeUuid(device.device_id || device.deviceId);
  const normalizedName = String(device.device_name || device.deviceName || "").trim().toLowerCase();
  if (isAdminSessionReady() && normalizedId && normalizedId === deviceId) {
    return true;
  }
  return ["solodrop pc", "solodrop пк", "solodrop mac"].includes(normalizedName);
}

function renderPairingStatus(statusPayload, devices = []) {
  updateDeviceLabels();
  const currentDevice = statusPayload?.device;
  const trusted = Boolean(statusPayload?.trusted);
  const tokenValid = Boolean(statusPayload?.tokenValid);
  const pairingEnabled = statusPayload?.pairingEnabled !== false;
  const isAdmin = isAdminSessionReady() || statusPayload?.sessionType === "admin";

  if (!pairingEnabled) {
    trustStatusLabel.textContent = t("pairing.trust.admin");
    setPairingStatus("paired", t("pairing.status.admin"), { summary: t("pairing.summary.admin") });
    return true;
  }

  if (isAdmin) {
    trustStatusLabel.textContent = t("pairing.trust.admin");
    setPairingStatus("paired", t("pairing.status.admin"), { summary: t("pairing.summary.admin") });
    return true;
  }

  if (tokenValid) {
    trustStatusLabel.textContent = t("pairing.trust.trusted");
    setPairingStatus("paired", t("pairing.status.connected"), {
      summary: currentDevice?.lastSeenAt
        ? t("devices.lastSeen", { date: formatPairingDate(currentDevice.lastSeenAt) })
        : t("pairing.summary.tokenAccepted"),
    });
    if (currentDevice?.deviceName) {
      deviceNameLabel.textContent = currentDevice.deviceName;
    }
    return true;
  }

  if (trusted && isPaired()) {
    trustStatusLabel.textContent = t("pairing.trust.tokenInvalid");
    setPairingStatus("required", t("pairing.status.repair"), {
      summary: t("pairing.summary.knownButTokenRejected"),
    });
    return false;
  }

  trustStatusLabel.textContent = trusted ? t("pairing.trust.tokenRequired") : t("pairing.trust.notTrusted");
  setPairingStatus("not-paired", t("pairing.status.notPaired"), {
    summary: devices.length ? t("pairing.summary.getPin") : t("pairing.summary.noBrowserDevice"),
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
    lastConnectionConfig = config;
    lastPairingStatusPayload = statusPayload;
    lastTrustedDevices = devices;
    renderServerStatus(config);
    renderTrustedDevices(devices);
    return renderPairingStatus(statusPayload, devices);
  } catch {
    serverUrlLabel.textContent = window.location.origin;
    bonjourStatusLabel.textContent = t("server.notFound");
    manualAddressLabel.textContent = t("server.manualActive", { host: window.location.host });
    trustedDevicesList.textContent = t("devices.serverUnavailable");
    trustStatusLabel.textContent = t("pairing.trust.unknown");
    setPairingStatus("error", t("pairing.status.error"), {
      summary: t("pairing.summary.serverStatusUnavailable"),
      error: t("error.pairingStatus"),
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
  if (pairCodeRequest) return pairCodeRequest;
  requestPairCodeButton.disabled = true;
  setPairingError("");
  pairCodeRequest = (async () => {
    await checkServerHealth();
    const response = await fetch("/pair/code", { cache: "no-store" });
    if (!response.ok) {
      throw new Error(t("error.pinUnavailable"));
    }

    const payload = await response.json();
    if (payload.pairingEnabled === false) {
      setPairingCredentials(payload);
      await startAuthorizedClient();
      return;
    }

    setPairCode(payload.code, payload.expiresAt, payload.qrUrl);
    if (pairingCodeInput) pairingCodeInput.value = "";
    setPairingStatus("paired", t("pairing.status.admin"), {
      summary: payload.code ? t("pairing.summary.admin") : t("pairing.codeUnavailable"),
    });
  })();
  try {
    await pairCodeRequest;
  } catch (error) {
    setPairingStatus("error", t("pairing.status.error"), {
      summary: t("error.serverUnavailable"),
      error: error.message || t("error.pinUnavailable"),
    });
    showToast(t("toast.pinUnavailable"));
  } finally {
    requestPairCodeButton.disabled = false;
    pairCodeRequest = null;
  }
}

async function ensurePairCode() {
  if (lastPairCode || pairCodeRequest) return;
  await requestPairCode();
}

async function pairDevice() {
  if (!pairingCodeInput || !pairButton) return;
  const code = pairingCodeInput.value.trim();
  if (!code) {
    setPairingStatus(currentPairingStatus, pairingStatus.textContent, {
      summary: pairingSummary.textContent,
      error: t("error.pinRequired"),
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
      throw new Error(response.status === 401 ? t("error.pinExpired") : t("toast.pairingFailed"));
    }

    const result = await response.json();
    if (!result.paired) {
      throw new Error(t("error.pairingRejected"));
    }

    setPairingCredentials(result);
    clearPairCode();
    pairingCodeInput.value = "";
    await startAuthorizedClient();
    await refreshPairingSettings();
  } catch (error) {
    setPairingStatus("error", t("pairing.status.error"), {
      summary: t("error.pinExpired"),
      error: error.message || t("error.pinExpired"),
    });
    showToast(t("toast.pairingFailed"));
  } finally {
    pairButton.disabled = false;
  }
}

async function copyPairCode() {
  const copied = await copyTextToClipboard(lastPairCode);
  showToast(copied ? t("toast.pinCopied") : t("toast.pinCopyFailed"));
}

async function repairPairing() {
  if (isAdminSessionReady()) {
    await requestPairCode();
    return;
  }
  clearPairingCredentials();
  disconnectWebSocket("Re-pair");
  setConnectionStatus("pairingRequired", { device: currentDeviceLabel() });
  showPairingPanel(t("pairing.status.repair"), {
    status: "required",
    summary: t("pairing.summary.repair"),
    open: true,
  });
  await requestPairCode();
}

async function resetPairing() {
  if (!resetPairingButton || !repairPairingButton) return;
  const previousDeviceId = deviceId;
  resetPairingButton.disabled = true;
  repairPairingButton.disabled = true;
  try {
    if (previousDeviceId) {
      await fetch(`/devices/${encodeURIComponent(previousDeviceId)}`, { method: "DELETE" });
    }
  } catch {
    showToast(t("toast.serverUnavailableClearLocal"));
  } finally {
    clearPairingCredentials({ resetDeviceId: true });
    clearPairCode();
    if (pairingCodeInput) pairingCodeInput.value = "";
    disconnectWebSocket("Pairing reset");
    setConnectionStatus("pairingRequired", { device: currentDeviceLabel() });
    showPairingPanel(t("pairing.status.required"), {
      status: "required",
      summary: t("pairing.summary.cleanCredentials"),
      open: true,
    });
    await refreshPairingSettings();
    setPairingStatus("required", t("pairing.status.required"), {
      summary: t("pairing.summary.cleanCredentials"),
    });
    resetPairingButton.disabled = false;
    repairPairingButton.disabled = false;
  }
}

async function startAuthorizedClient() {
  hidePairingPanel();
  setConnectionStatus("syncing", { device: currentDeviceLabel() });
  await loadMessages();
  connectWebSocket();
}

async function bootstrapClient() {
  setClientEnabled(false);
  try {
    await checkServerHealth();
    await ensureAdminSession();
    await refreshPairingSettings();
    await startAuthorizedClient();
  } catch (error) {
    setConnectionStatus("serverUnavailable");
    showPairingPanel(t("pairing.status.error"), {
      status: "error",
      summary: t("error.serverAddress"),
      error: t("error.serverUnavailable"),
    });
  }
}

function ensurePairedForSend() {
  if (isAdminSessionReady()) {
    return true;
  }

  if (isPaired()) {
    return true;
  }

  setConnectionStatus("pairingRequired", { device: currentDeviceLabel() });
  showPairingPanel(t("pairing.status.required"), {
    status: "required",
    summary: t("pairing.summary.connectInSettings"),
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
      showToast(isMediaMessage(message) ? t("toast.mediaCopied") : t("toast.fileCopied"));
      return;
    }
  }

  const copiedText = await copyTextToClipboard(transferableTextForMessage(message));
  showToast(copiedText ? t("toast.copied") : t("toast.copyFailed"));
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
  refreshPairingSettings().then(() => ensurePairCode());
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
  showToast(t("toast.savingStarted"));
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

  showToast(t("toast.fileSaved", { name: message.fileName || t("file.file") }));
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
  viewerImage.alt = fileName || t("file.image");
  viewerFileName.textContent = fileName || t("file.image");
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
    image.alt = message.fileName || t("file.image");
    image.loading = "lazy";
    image.addEventListener("error", () => {
      image.replaceWith(fileFallbackLink(message));
    }, { once: true });
    image.addEventListener("load", () => {
      messageList.scrollTop = messageList.scrollHeight;
    });

    const caption = document.createElement("div");
    caption.className = "file-caption";
    caption.textContent = message.fileName || t("file.image");

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
    caption.textContent = message.fileName || t("file.video");

    bubble.append(video, caption);
  } else if (message.kind === "file" && isAudioMessage(message)) {
    const audio = document.createElement("audio");
    audio.className = "audio-preview";
    audio.src = absoluteUrl(message.fileUrl);
    audio.controls = true;
    audio.preload = "metadata";

    const caption = document.createElement("div");
    caption.className = "file-caption";
    caption.textContent = message.fileName || t("file.audio");

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
    saved.textContent = t("file.saved");
    bubble.append(saved);
  }

  row.append(bubble);
  messageList.append(row);
}

function renderEmptyState() {
  const empty = document.createElement("div");
  empty.className = "empty-state";
  empty.innerHTML = `
    <h2>${t("messages.emptyTitle")}</h2>
    <p>${t("messages.emptyBody")}</p>
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
    button.innerHTML = `<span>${formatDateDivider(`${key}T00:00:00`)}</span><small>${fileCountLabel(files.length)}</small>`;
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
    empty.textContent = t("history.empty");
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
  const body = {
    id: createUuid(),
    sender,
    text,
    createdAt: timestamp,
    updatedAt: timestamp,
  };
  if (!isAdminSessionReady()) {
    body.device_id = deviceId;
    body.device_token = getDeviceToken();
  }

  const response = await fetch("/api/messages", {
    method: "POST",
    headers: adminHeaders({ "Content-Type": "application/json" }),
    body: JSON.stringify(body),
  });
  if (response.status === 401 || response.status === 403) {
    clearPairingCredentials();
    showPairingPanel(t("pairing.status.repair"), {
      status: "required",
      summary: t("pairing.summary.tokenRejected"),
      open: true,
    });
  }
  if (!response.ok) throw new Error(t("error.sendMessage"));
}

async function sendFile(file) {
  const formData = new FormData();
  formData.append("sender", sender);
  if (!isAdminSessionReady()) {
    formData.append("device_id", deviceId);
    const token = getDeviceToken();
    if (token) formData.append("device_token", token);
  }
  formData.append("client_item_id", createUuid());
  formData.append("uploaded_file", file);

  const response = await fetch("/api/files", {
    method: "POST",
    headers: adminHeaders(),
    body: formData,
  });
  if (response.status === 401 || response.status === 403) {
    clearPairingCredentials();
    showPairingPanel(t("pairing.status.repair"), {
      status: "required",
      summary: t("pairing.summary.tokenRejected"),
      open: true,
    });
  }
  if (!response.ok) throw new Error(t("error.sendFile"));
}

async function sendDroppedFiles(files) {
  if (!ensurePairedForSend()) return;

  const fileList = Array.from(files).filter((file) => file.size > 0);
  if (fileList.length === 0) return;

  const mediaCount = fileList.filter(isMediaFile).length;
  showToast(mediaCount > 0 ? t("toast.sendingMedia", { count: mediaCount }) : t("toast.sendingFiles", { count: fileList.length }));

  for (const file of fileList) {
    try {
      await sendFile(file);
    } catch {
      showToast(t("toast.sendFailed", { name: file.name }));
      return;
    }
  }

  showToast(fileList.length === 1 ? t("toast.fileSent") : t("toast.filesSent", { count: fileList.length }));
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
  const confirmed = window.confirm(t("action.clearChatConfirm"));
  if (!confirmed) return;

  const response = await fetch(authUrl("/api/messages"), {
    method: "DELETE",
    headers: adminHeaders(),
  });
  if (!response.ok) {
    window.alert(t("error.clearChat"));
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
    setConnectionStatus("online", { device: currentDeviceLabel() });
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
      if (isAdminSessionReady()) {
        adminSessionToken = "";
        sessionStorage.removeItem(ADMIN_SESSION_TOKEN_KEY);
        ensureAdminSession()
          .then(connectWebSocket)
          .catch(() => {
            setConnectionStatus("serverUnavailable");
          });
      } else {
        clearPairingCredentials();
        setConnectionStatus("pairingRequired", { device: currentDeviceLabel() });
        showPairingPanel(t("pairing.status.repair"), {
          status: "required",
          summary: t("pairing.summary.websocketRejected"),
        });
      }
      return;
    }
    if (!isAdminSessionReady() && !isPaired()) {
      return;
    }
    setConnectionStatus("reconnecting");
    websocketReconnectTimer = window.setTimeout(connectWebSocket, 1500);
  });
}

composer.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (!ensurePairedForSend()) return;

  const text = messageInput.value.trim();
  if (!text) return;
  messageInput.value = "";
  try {
    await sendText(text);
  } catch (error) {
    showToast(error.message || t("error.sendMessage"));
  }
});

autosaveToggle.addEventListener("change", () => {
  localStorage.setItem(AUTOSAVE_KEY, String(autosaveToggle.checked));
  showToast(autosaveToggle.checked ? t("toast.autosaveOn") : t("toast.autosaveOff"));
  if (autosaveToggle.checked) autosaveNewFiles(allMessages);
});

languageSelect?.addEventListener("change", (event) => {
  setLanguage(event.target.value);
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
pairButton?.addEventListener("click", pairDevice);
repairPairingButton?.addEventListener("click", repairPairing);
resetPairingButton?.addEventListener("click", resetPairing);
pairingCodeInput?.addEventListener("keydown", (event) => {
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
  try {
    await sendFile(file);
  } catch (error) {
    showToast(error.message || t("error.sendFile"));
  }
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

applyStaticTranslations();
setConnectionStatus("connecting");
setPairingStatus("checking", t("pairing.status.checking"));
applyDeviceChrome();
bootstrapClient();

closeViewerButton.addEventListener("click", closeImageViewer);
imageViewer.addEventListener("click", (event) => {
  if (event.target === imageViewer) closeImageViewer();
});
window.addEventListener("keydown", (event) => {
  if (event.key === "Escape" && !imageViewer.hidden) closeImageViewer();
});
