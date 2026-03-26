const HOST_NAME = "app.dyx.native_host";
const ENABLED_KEY = "dyxEnabled";
const ACTION_TITLE_ON = "DYX catcher is on";
const ACTION_TITLE_OFF = "DYX catcher is off";
const ACK_TIMEOUT_MS = 1500;
const RECENT_HANDOFF_TTL_MS = 10000;
const RECENT_REJECTED_TTL_MS = 5000;
const RECENT_INTENT_TTL_MS = 5000;
const RECENT_CONTEXT_TTL_MS = 15000;
const PENDING_DECISION_TTL_MS = 4000;
const PENDING_FALLBACK_WAIT_MS = 350;
const BROWSER_ONLY_NOTICE_TTL_MS = 6000;
const DEBUG_LOG = false;

const DIRECT_IMAGE_EXTENSIONS = new Set([
  "png", "jpg", "jpeg", "webp", "gif", "bmp", "avif"
]);
const INTENT_DOWNLOAD_EXTENSIONS = new Set([
  "png", "jpg", "jpeg", "webp", "gif", "bmp", "avif",
  "zip", "rar", "7z", "tar", "gz", "xz", "deb", "rpm", "apk", "dmg", "pkg", "pdf",
  "mp4", "mkv", "webm", "mov", "avi", "mp3", "m4a", "flac", "wav", "ogg"
]);
const PAGE_ASSET_EXTENSIONS = new Set([
  "svg", "js", "mjs", "css", "json", "map", "txt", "xml", "webmanifest"
]);
const EARLY_REQUEST_TYPES = new Set([
  "main_frame", "other"
]);
const LOG_ONLY_REQUEST_TYPES = new Set([
  "object"
]);
const REJECTED_REQUEST_TYPES = new Set([
  "image", "script", "stylesheet", "xmlhttprequest", "sub_frame",
  "media", "font", "websocket", "ping", "beacon", "imageset",
  "speculative", "csp_report", "web_manifest"
]);
const ATTACHMENT_LIKE_REQUEST_TYPES = new Set([
  "main_frame", "other", "media", "image"
]);
const DOWNLOAD_CONTENT_TYPE_HINTS = [
  "octet-stream",
  "pdf",
  "zip",
  "gzip",
  "x-gzip",
  "x-tar",
  "x-7z",
  "7z-compressed",
  "x-rar",
  "rar",
  "bittorrent",
  "diskimage",
  "apple-diskimage",
  "msdownload",
  "deb",
  "rpm",
  "apk",
  "epub",
  "binary"
];
const INLINE_CONTENT_TYPE_HINTS = [
  "text/",
  "html",
  "json",
  "javascript",
  "xml",
  "svg+xml",
  "webmanifest"
];
const SUSPICIOUS_PATH_TOKENS = [
  "sprite", "sprites", "bundle", "runtime", "manifest", "asset", "assets", "chunk", "api", "endpoint"
];
const INTENT_HINT_WORDS = [
  "download", "save", "get file"
];
const DISALLOWED_REPLAY_HEADERS = new Set([
  "connection",
  "content-length",
  "host",
  "proxy-authenticate",
  "proxy-authorization",
  "proxy-connection",
  "te",
  "trailer",
  "transfer-encoding",
  "upgrade"
]);
const DISALLOWED_REPLAY_HEADER_PREFIXES = [
  "proxy-",
  "sec-fetch-",
  "sec-websocket-"
];

const recentAcceptedUrls = new Map();
const recentRejectedUrls = new Map();
const recentIntentHints = new Map();
const inFlightDecisions = new Map();
const requestContextsById = new Map();
const recentContextsByUrl = new Map();
const recentBrowserOnlyNotices = new Map();
let debugLoggingAvailable = true;
let debugLoggingWarned = false;

function debugLog(...args) {
  if (DEBUG_LOG) {
    console.log("[DYX]", ...args);
  }
}

async function logDebugEvent(event, data = {}) {
  if (!debugLoggingAvailable) {
    return;
  }
  try {
    await browser.runtime.sendNativeMessage(HOST_NAME, {
      type: "append_debug_log",
      component: "firefox-extension",
      event,
      timestamp: new Date().toISOString(),
      data
    });
  } catch (error) {
    debugLoggingAvailable = false;
    if (!debugLoggingWarned) {
      debugLoggingWarned = true;
      console.warn("[DYX] Firefox debug logging disabled:", error && error.message ? error.message : error);
    }
  }
}

function logClassifierDecision(layer, url, data = {}) {
  return logDebugEvent(`classifier_${layer}`, {
    url,
    ...data
  });
}

function logNativeHandoffResult(source, url, outcome, extra = {}) {
  return logDebugEvent("native_handoff", {
    source,
    url,
    outcome,
    ...extra
  });
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function getEnabled() {
  const stored = await browser.storage.local.get(ENABLED_KEY);
  if (typeof stored[ENABLED_KEY] === "boolean") {
    return stored[ENABLED_KEY];
  }
  await browser.storage.local.set({ [ENABLED_KEY]: true });
  return true;
}

async function setEnabled(enabled) {
  await browser.storage.local.set({ [ENABLED_KEY]: enabled });
  await updateActionState(enabled);
}

async function updateActionState(enabledValue) {
  const enabled = typeof enabledValue === "boolean" ? enabledValue : await getEnabled();
  await browser.action.setTitle({ title: enabled ? ACTION_TITLE_ON : ACTION_TITLE_OFF });
  await browser.action.setBadgeText({ text: enabled ? "ON" : "OFF" });
  await browser.action.setBadgeBackgroundColor({ color: enabled ? "#22c55e" : "#6b7280" });
}

function isHttpUrl(urlString) {
  try {
    const url = new URL(urlString);
    return url.protocol === "http:" || url.protocol === "https:";
  } catch (_) {
    return false;
  }
}

function headerValueNormalized(value) {
  return value.trim().toLowerCase();
}

function lowerHeaderValue(headers, name) {
  const match = Array.isArray(headers)
    ? headers.find((header) => typeof header.name === "string" && header.name.toLowerCase() === name)
    : null;
  return match && typeof match.value === "string" ? headerValueNormalized(match.value) : "";
}

function rawHeaderValue(headers, name) {
  const match = Array.isArray(headers)
    ? headers.find((header) => typeof header.name === "string" && header.name.toLowerCase() === name)
    : null;
  return match && typeof match.value === "string" ? match.value.trim() : "";
}

function decodedUrlForChecks(urlString) {
  try {
    return decodeURIComponent(urlString).toLowerCase();
  } catch (_) {
    return urlString.toLowerCase();
  }
}

function pathExtension(urlString) {
  try {
    const url = new URL(urlString);
    const pathname = url.pathname || "";
    const lastDot = pathname.lastIndexOf(".");
    if (lastDot < 0) {
      return "";
    }
    return pathname.slice(lastDot + 1).toLowerCase();
  } catch (_) {
    return "";
  }
}

function fileBasename(urlString) {
  try {
    const url = new URL(urlString);
    const segments = (url.pathname || "").split("/").filter(Boolean);
    return segments.length > 0 ? segments[segments.length - 1] : "";
  } catch (_) {
    return "";
  }
}

function hasSuspiciousPathToken(urlString) {
  try {
    const url = new URL(urlString);
    const haystack = `${url.pathname} ${url.search}`.toLowerCase();
    return SUSPICIOUS_PATH_TOKENS.some((token) => haystack.includes(token));
  } catch (_) {
    return false;
  }
}

function hasFileLikePath(urlString) {
  return pathExtension(urlString).length > 0;
}

function isInlineMediaContentType(contentType) {
  return contentType.startsWith("image/")
    || contentType.startsWith("video/")
    || contentType.startsWith("audio/")
    || INLINE_CONTENT_TYPE_HINTS.some((hint) => contentType.includes(hint));
}

function isDownloadLikeContentType(contentType) {
  return DOWNLOAD_CONTENT_TYPE_HINTS.some((hint) => contentType.includes(hint));
}

function isMainFrameRequest(details) {
  return !!details
    && details.type === "main_frame"
    && details.frameId === 0;
}

function isDownloadCandidateRequestType(details) {
  return !!details
    && typeof details.type === "string"
    && EARLY_REQUEST_TYPES.has(details.type);
}

function isExplicitlyRejectedRequestType(details) {
  return !!details
    && typeof details.type === "string"
    && REJECTED_REQUEST_TYPES.has(details.type);
}

function isAttachmentLikeRequestType(details) {
  return !!details
    && typeof details.type === "string"
    && ATTACHMENT_LIKE_REQUEST_TYPES.has(details.type);
}

function cleanupTimedMap(map, ttlMs) {
  const cutoff = Date.now() - ttlMs;
  for (const [key, entry] of map.entries()) {
    const timestamp = typeof entry === "number" ? entry : entry && entry.timestamp;
    if (typeof timestamp !== "number" || timestamp < cutoff) {
      map.delete(key);
    }
  }
}

function generateCorrelationId() {
  return `dyx-${Date.now().toString(36)}-${Math.random().toString(16).slice(2, 10)}`;
}

function markAcceptedUrl(url) {
  cleanupTimedMap(recentAcceptedUrls, RECENT_HANDOFF_TTL_MS);
  recentAcceptedUrls.set(url, Date.now());
  debugLog("accepted url", url);
}

function wasRecentlyAccepted(url) {
  cleanupTimedMap(recentAcceptedUrls, RECENT_HANDOFF_TTL_MS);
  const timestamp = recentAcceptedUrls.get(url);
  return typeof timestamp === "number" && (Date.now() - timestamp) <= RECENT_HANDOFF_TTL_MS;
}

function markRejectedUrl(url) {
  cleanupTimedMap(recentRejectedUrls, RECENT_REJECTED_TTL_MS);
  recentRejectedUrls.set(url, Date.now());
  debugLog("rejected url", url);
}

function wasRecentlyRejected(url) {
  cleanupTimedMap(recentRejectedUrls, RECENT_REJECTED_TTL_MS);
  const timestamp = recentRejectedUrls.get(url);
  return typeof timestamp === "number" && (Date.now() - timestamp) <= RECENT_REJECTED_TTL_MS;
}

function recordDecision(url, state) {
  cleanupTimedMap(inFlightDecisions, PENDING_DECISION_TTL_MS);
  inFlightDecisions.set(url, { state, timestamp: Date.now() });
  debugLog("decision", state, url);
}

function getDecision(url) {
  cleanupTimedMap(inFlightDecisions, PENDING_DECISION_TTL_MS);
  const entry = inFlightDecisions.get(url);
  return entry && typeof entry.state === "string" ? entry.state : "";
}

function getIntentHint(url) {
  cleanupTimedMap(recentIntentHints, RECENT_INTENT_TTL_MS);
  return recentIntentHints.get(url) || null;
}

function storeIntentHint(payload) {
  const url = typeof payload.url === "string" ? payload.url : "";
  if (!isHttpUrl(url)) {
    return null;
  }
  cleanupTimedMap(recentIntentHints, RECENT_INTENT_TTL_MS);
  const existing = recentIntentHints.get(url);
  const hint = {
    timestamp: Date.now(),
    correlationId: existing && typeof existing.correlationId === "string"
      ? existing.correlationId
      : generateCorrelationId(),
    suggestedFilename: typeof payload.filename === "string" ? payload.filename.trim() : "",
    referrer: typeof payload.referrer === "string" ? payload.referrer.trim() : "",
    pageTitle: typeof payload.pageTitle === "string" ? payload.pageTitle.trim() : "",
    pageUrl: typeof payload.pageUrl === "string" ? payload.pageUrl.trim() : "",
    anchorText: typeof payload.anchorText === "string" ? payload.anchorText.trim() : "",
    anchorLabel: typeof payload.anchorLabel === "string" ? payload.anchorLabel.trim() : "",
    anchorTitle: typeof payload.anchorTitle === "string" ? payload.anchorTitle.trim() : ""
  };
  recentIntentHints.set(url, hint);
  return hint;
}

function storeRequestContext(requestId, context) {
  cleanupTimedMap(requestContextsById, RECENT_CONTEXT_TTL_MS);
  cleanupTimedMap(recentContextsByUrl, RECENT_CONTEXT_TTL_MS);
  requestContextsById.set(requestId, context);
  recentContextsByUrl.set(context.url, context);
}

function getRequestContext(details) {
  cleanupTimedMap(requestContextsById, RECENT_CONTEXT_TTL_MS);
  cleanupTimedMap(recentContextsByUrl, RECENT_CONTEXT_TTL_MS);
  if (details && details.requestId && requestContextsById.has(details.requestId)) {
    return requestContextsById.get(details.requestId) || null;
  }
  if (details && details.url && recentContextsByUrl.has(details.url)) {
    return recentContextsByUrl.get(details.url) || null;
  }
  return null;
}

function getContextForUrl(url) {
  cleanupTimedMap(recentContextsByUrl, RECENT_CONTEXT_TTL_MS);
  return recentContextsByUrl.get(url) || null;
}

function classifyIntentClick(payload) {
  const url = typeof payload.url === "string" ? payload.url : "";
  const filename = typeof payload.filename === "string" ? payload.filename.trim() : "";
  if (!isHttpUrl(url)) {
    return { ok: false, reason: "unsupported-url" };
  }

  const extension = pathExtension(url);
  if (PAGE_ASSET_EXTENSIONS.has(extension) || extension === "svg") {
    return { ok: false, reason: "asset-extension", recordReject: true };
  }
  if (hasSuspiciousPathToken(url)) {
    return { ok: false, reason: "suspicious-path", recordReject: true };
  }
  if (filename.length > 0) {
    return { ok: true, source: "firefox-intent-click" };
  }
  if (INTENT_DOWNLOAD_EXTENSIONS.has(extension) && hasFileLikePath(url)) {
    return { ok: true, source: "firefox-intent-click" };
  }

  const intentText = [
    payload.anchorText,
    payload.anchorLabel,
    payload.anchorTitle
  ].filter((value) => typeof value === "string" && value.trim().length > 0).join(" ").toLowerCase();
  const sameOrigin = payload.sameOrigin === true;
  const likelyFileServing = typeof payload.url === "string"
    && /download|attachment|file/i.test(payload.url);

  if (intentText.length > 0
    && INTENT_HINT_WORDS.some((word) => intentText.includes(word))
    && (sameOrigin || likelyFileServing)
  ) {
    return { ok: true, source: "firefox-intent-click" };
  }

  return { ok: false, reason: "not-file-like", recordReject: false };
}

function isNeverEarlyCatch(details, contentType) {
  const extension = pathExtension(details.url);
  if (PAGE_ASSET_EXTENSIONS.has(extension) || extension === "svg") {
    return true;
  }
  if (hasSuspiciousPathToken(details.url)) {
    return true;
  }
  if (!contentType) {
    return false;
  }
  return INLINE_CONTENT_TYPE_HINTS.some((hint) => contentType.includes(hint));
}

function isDirectImageNavigation(details, contentType) {
  const extension = pathExtension(details.url);
  if (!DIRECT_IMAGE_EXTENSIONS.has(extension)) {
    return false;
  }
  if (!contentType.startsWith("image/")) {
    return false;
  }
  if (!isMainFrameRequest(details)) {
    return false;
  }
  if (!hasFileLikePath(details.url) || hasSuspiciousPathToken(details.url)) {
    return false;
  }
  const basename = fileBasename(details.url).toLowerCase();
  if (!basename || SUSPICIOUS_PATH_TOKENS.some((token) => basename.includes(token))) {
    return false;
  }
  return true;
}

function isAttachmentResponse(headers) {
  const disposition = lowerHeaderValue(headers, "content-disposition");
  return disposition.includes("attachment");
}

function hasAttachmentHintInUrl(urlString) {
  const haystack = decodedUrlForChecks(urlString);
  return haystack.includes("response-content-disposition=attachment")
    || haystack.includes("content-disposition=attachment")
    || haystack.includes("filename=")
    || haystack.includes("attachment;");
}

function isAttachmentLike(details, headers) {
  return isAttachmentResponse(headers) || hasAttachmentHintInUrl(details.url);
}

function isBrowserDownloadCandidate(details, attachmentLike) {
  if (!details || !isHttpUrl(details.url) || details.incognito || details.method !== "GET") {
    return false;
  }
  if (attachmentLike && isAttachmentLikeRequestType(details)) {
    return true;
  }
  if (!isDownloadCandidateRequestType(details)) {
    return false;
  }
  if (details.tabId < 0 && !attachmentLike) {
    return false;
  }
  if (typeof details.frameId === "number" && details.frameId > 0 && !attachmentLike) {
    return false;
  }
  return true;
}

function classifyWebRequest(details) {
  if (!details || !isHttpUrl(details.url)) {
    return { ok: false, reason: "request-shape", recordReject: false };
  }
  if (details.incognito) {
    return { ok: false, reason: "incognito-browser-only", recordReject: false, browserOnly: true };
  }
  if (details.method !== "GET") {
    return { ok: false, reason: "non-get-browser-only", recordReject: false, browserOnly: true };
  }
  if (wasRecentlyAccepted(details.url)) {
    return { ok: false, reason: "recent-accepted", recordReject: false };
  }
  if (wasRecentlyRejected(details.url)) {
    return { ok: false, reason: "recent-rejected", recordReject: true };
  }

  const headers = Array.isArray(details.responseHeaders) ? details.responseHeaders : [];
  const attachmentLike = isAttachmentLike(details, headers);
  if (LOG_ONLY_REQUEST_TYPES.has(details.type)) {
    return { ok: false, reason: "request-type-log-only", recordReject: false };
  }
  if (!isBrowserDownloadCandidate(details, attachmentLike)) {
    const reason = isExplicitlyRejectedRequestType(details) ? "request-type-rejected" : "request-type";
    return { ok: false, reason, recordReject: false };
  }
  if (attachmentLike) {
    return { ok: true, source: "firefox-attachment" };
  }

  const contentType = lowerHeaderValue(headers, "content-type");
  if (!contentType) {
    return { ok: false, reason: "missing-content-type", recordReject: false };
  }
  if (isNeverEarlyCatch(details, contentType)) {
    return { ok: false, reason: "denylist", recordReject: true };
  }
  if (isDirectImageNavigation(details, contentType)) {
    return { ok: true, source: "firefox-navigation" };
  }
  if (isInlineMediaContentType(contentType)) {
    return { ok: false, reason: "inline-media-browser-only", recordReject: false, browserOnly: true };
  }
  if (isDownloadLikeContentType(contentType)) {
    return { ok: true, source: "firefox-navigation" };
  }

  const extension = pathExtension(details.url);
  if (INTENT_DOWNLOAD_EXTENSIONS.has(extension) && hasFileLikePath(details.url) && !hasSuspiciousPathToken(details.url)) {
    return {
      ok: true,
      source: isMainFrameRequest(details) ? "firefox-navigation" : "firefox-attachment"
    };
  }

  return { ok: false, reason: "content-type", recordReject: false };
}

function shouldHandleDownload(item) {
  if (!item || typeof item.id !== "number") {
    return false;
  }
  if (item.incognito || item.byExtensionId === browser.runtime.id) {
    return false;
  }
  return isHttpUrl(item.finalUrl || item.url || "");
}

function classifyDownloadItem(item, context) {
  const url = item.finalUrl || item.url || "";
  if (!isHttpUrl(url)) {
    return { ok: false, reason: "unsupported-url", recordReject: false };
  }
  if (wasRecentlyRejected(url)) {
    return { ok: false, reason: "recent-rejected", recordReject: true };
  }
  if (context && context.requestMethod && context.requestMethod !== "GET") {
    return { ok: false, reason: "non-get-browser-only", recordReject: false, browserOnly: true };
  }

  const filename = typeof item.filename === "string" ? item.filename.toLowerCase() : "";
  const extension = filename.includes(".")
    ? filename.slice(filename.lastIndexOf(".") + 1)
    : pathExtension(url);

  if (PAGE_ASSET_EXTENSIONS.has(extension) || extension === "svg") {
    return { ok: false, reason: "asset-extension", recordReject: true };
  }
  if (hasSuspiciousPathToken(url) || (filename && SUSPICIOUS_PATH_TOKENS.some((token) => filename.includes(token)))) {
    return { ok: false, reason: "suspicious-path", recordReject: true };
  }

  const mime = typeof item.mime === "string" ? item.mime.toLowerCase() : "";
  if (mime && INLINE_CONTENT_TYPE_HINTS.some((hint) => mime.includes(hint))) {
    return { ok: false, reason: "inline-mime-browser-only", recordReject: false, browserOnly: true };
  }
  if (mime && isDownloadLikeContentType(mime)) {
    return { ok: true, source: "firefox-fallback", suggestedFilename: item.filename || "" };
  }
  if (DIRECT_IMAGE_EXTENSIONS.has(extension) || INTENT_DOWNLOAD_EXTENSIONS.has(extension)) {
    return { ok: true, source: "firefox-fallback", suggestedFilename: item.filename || "" };
  }

  return { ok: false, reason: "not-download-like", recordReject: false };
}

function disallowedReplayHeader(name) {
  const lowered = name.toLowerCase();
  if (DISALLOWED_REPLAY_HEADERS.has(lowered)) {
    return true;
  }
  return DISALLOWED_REPLAY_HEADER_PREFIXES.some((prefix) => lowered.startsWith(prefix));
}

function sanitizeReplayHeaders(headers) {
  const filtered = new Map();
  let userAgent = "";

  for (const header of Array.isArray(headers) ? headers : []) {
    if (!header || typeof header.name !== "string" || typeof header.value !== "string") {
      continue;
    }

    const name = header.name.trim();
    const value = header.value.trim();
    if (!name || !value) {
      continue;
    }

    const lowered = name.toLowerCase();
    if (lowered === "user-agent") {
      userAgent = value;
      continue;
    }
    if (disallowedReplayHeader(lowered)) {
      continue;
    }
    filtered.set(lowered, `${name}: ${value}`);
  }

  return {
    userAgent,
    headers: Array.from(filtered.values())
  };
}

function hasHeaderString(headers, name) {
  const lowered = name.toLowerCase();
  return Array.isArray(headers) && headers.some((header) => {
    if (typeof header !== "string") {
      return false;
    }
    const colon = header.indexOf(":");
    if (colon < 0) {
      return false;
    }
    return header.slice(0, colon).trim().toLowerCase() === lowered;
  });
}

function referrerFromHeaders(headers) {
  const match = Array.isArray(headers)
    ? headers.find((header) => typeof header === "string" && header.toLowerCase().startsWith("referer:"))
    : null;
  return match ? match.slice(match.indexOf(":") + 1).trim() : "";
}

function extractSuggestedFilename(responseHeaders, hint, fallbackUrl) {
  const fromHint = sanitizeSuggestedFilename(hint);
  if (fromHint) {
    return fromHint;
  }
  const disposition = rawHeaderValue(responseHeaders, "content-disposition");
  const fromDisposition = sanitizeSuggestedFilename(filenameFromContentDisposition(disposition));
  if (fromDisposition) {
    return fromDisposition;
  }
  const fromUrl = sanitizeSuggestedFilename(fileBasename(fallbackUrl));
  return fromUrl || "download.bin";
}

function sanitizeSuggestedFilename(value) {
  if (typeof value !== "string") {
    return "";
  }
  const trimmed = value.trim().replace(/[/\\?%*:|"<>]/g, "_");
  return trimmed.replace(/\s+/g, " ").trim();
}

function filenameFromContentDisposition(disposition) {
  if (typeof disposition !== "string" || disposition.trim().length === 0) {
    return "";
  }

  const starMatch = disposition.match(/filename\*\s*=\s*([^;]+)/i);
  if (starMatch) {
    const rawValue = starMatch[1].trim().replace(/^UTF-8''/i, "").replace(/^"(.*)"$/, "$1");
    try {
      return decodeURIComponent(rawValue);
    } catch (_) {
      return rawValue;
    }
  }

  const plainMatch = disposition.match(/filename\s*=\s*"?([^";]+)"?/i);
  return plainMatch ? plainMatch[1].trim() : "";
}

function buildContextFromDetails(details, hint) {
  const sanitized = sanitizeReplayHeaders(details.requestHeaders || []);
  const requestHeaders = sanitized.headers.slice();
  const referrer = rawHeaderValue(details.requestHeaders || [], "referer")
    || (hint && hint.referrer) || "";
  return {
    timestamp: Date.now(),
    requestId: details.requestId,
    correlationId: hint && hint.correlationId ? hint.correlationId : generateCorrelationId(),
    url: details.url,
    requestMethod: details.method || "GET",
    requestType: details.type || "",
    tabId: typeof details.tabId === "number" ? details.tabId : -1,
    frameId: typeof details.frameId === "number" ? details.frameId : -1,
    tabUrl: hint && hint.pageUrl ? hint.pageUrl : "",
    pageTitle: hint && hint.pageTitle ? hint.pageTitle : "",
    referrer,
    suggestedFilename: hint && hint.suggestedFilename ? hint.suggestedFilename : "",
    requestHeaders,
    userAgent: sanitized.userAgent,
    initiator: typeof details.initiator === "string" ? details.initiator : "",
    originUrl: typeof details.originUrl === "string" ? details.originUrl : ""
  };
}

async function synthesizeCookieHeader(url) {
  try {
    const cookies = await browser.cookies.getAll({ url });
    if (!Array.isArray(cookies) || cookies.length === 0) {
      return "";
    }
    return cookies
      .filter((cookie) => cookie && typeof cookie.name === "string" && typeof cookie.value === "string")
      .map((cookie) => `${cookie.name}=${cookie.value}`)
      .join("; ");
  } catch (_) {
    return "";
  }
}

async function buildHandoffPayload(base) {
  if (!isHttpUrl(base.url) || base.requestMethod !== "GET") {
    return null;
  }

  const headers = Array.isArray(base.headers) ? base.headers.slice() : [];
  if (!hasHeaderString(headers, "cookie")) {
    const cookieHeader = await synthesizeCookieHeader(base.url);
    if (cookieHeader) {
      headers.push(`Cookie: ${cookieHeader}`);
    }
  }

  return {
    type: "enqueue_download",
    url: base.url,
    source: base.source,
    correlationId: base.correlationId || generateCorrelationId(),
    requestMethod: base.requestMethod,
    requestType: base.requestType || "",
    tabUrl: base.tabUrl || "",
    referrer: base.referrer || "",
    pageTitle: base.pageTitle || "",
    suggestedFilename: base.suggestedFilename || "",
    filename: base.suggestedFilename || "",
    headers,
    userAgent: base.userAgent || ""
  };
}

async function sendNativeMessageWithTimeout(message, timeoutMs) {
  return new Promise((resolve, reject) => {
    const timeoutId = setTimeout(() => reject(new Error("Timed out waiting for DYX native host")), timeoutMs);
    browser.runtime.sendNativeMessage(HOST_NAME, message)
      .then((response) => {
        clearTimeout(timeoutId);
        resolve(response);
      })
      .catch((error) => {
        clearTimeout(timeoutId);
        reject(error);
      });
  });
}

async function notifyFailure(title, message) {
  try {
    await browser.notifications.create({
      type: "basic",
      iconUrl: browser.runtime.getURL("icons/dyx-96.png"),
      title,
      message
    });
  } catch (_) {
  }
}

async function notifyBrowserOnly(url, reason, extra = {}) {
  cleanupTimedMap(recentBrowserOnlyNotices, BROWSER_ONLY_NOTICE_TTL_MS);
  if (recentBrowserOnlyNotices.has(url)) {
    return;
  }
  recentBrowserOnlyNotices.set(url, Date.now());
  await logDebugEvent("browser_only_fallback", {
    url,
    reason,
    ...extra
  });
  await notifyFailure(
    "DYX left this download in Firefox",
    "This site is using a browser-only download flow that DYX cannot replay natively yet."
  );
}

async function handoffToDyx(payload) {
  if (!payload || !isHttpUrl(payload.url)) {
    await logNativeHandoffResult(payload && payload.source ? payload.source : "firefox", payload && payload.url ? payload.url : "", "invalid-url");
    return { ok: false, error: "Unsupported URL." };
  }

  await logDebugEvent("native_handoff_attempt", payload);
  const response = await sendNativeMessageWithTimeout(payload, ACK_TIMEOUT_MS);
  if (response && response.ok === true && response.accepted === true) {
    markAcceptedUrl(payload.url);
    await logNativeHandoffResult(payload.source, payload.url, "accepted", {
      correlationId: payload.correlationId,
      response
    });
  } else {
    await logNativeHandoffResult(payload.source, payload.url, "rejected", {
      correlationId: payload.correlationId,
      response
    });
  }
  return response;
}

async function pauseIfPossible(downloadId) {
  try {
    await browser.downloads.pause(downloadId);
    return true;
  } catch (_) {
    return false;
  }
}

async function resumeIfPossible(downloadId) {
  try {
    await browser.downloads.resume(downloadId);
  } catch (_) {
  }
}

async function cancelAndEraseIfPossible(downloadId) {
  try {
    await browser.downloads.cancel(downloadId);
  } catch (_) {
  }
  try {
    await browser.downloads.erase({ id: downloadId });
  } catch (_) {
  }
}

browser.action.onClicked.addListener(async () => {
  const next = !(await getEnabled());
  await setEnabled(next);
});

browser.runtime.onInstalled.addListener(() => {
  updateActionState(true).catch(() => {});
});

browser.runtime.onStartup.addListener(() => {
  updateActionState().catch(() => {});
});

browser.runtime.onMessage.addListener((message) => {
  if (!message || message.type !== "intent-click") {
    return undefined;
  }

  return (async () => {
    await logDebugEvent("intent_seen", {
      url: message.url || "",
      filename: message.filename || "",
      anchorText: message.anchorText || "",
      anchorLabel: message.anchorLabel || "",
      anchorTitle: message.anchorTitle || "",
      sameOrigin: message.sameOrigin === true,
      pageUrl: message.pageUrl || ""
    });

    if (!(await getEnabled())) {
      await logClassifierDecision("intent", message.url || "", { decision: "disabled" });
      return { ok: false, intercept: false, reason: "disabled" };
    }

    const classification = classifyIntentClick(message);
    if (!classification.ok) {
      if (classification.recordReject && message.url) {
        markRejectedUrl(message.url);
      }
      await logClassifierDecision("intent", message.url || "", {
        decision: "rejected",
        reason: classification.reason
      });
      return { ok: false, intercept: false, reason: classification.reason };
    }

    const hint = storeIntentHint(message);
    await logClassifierDecision("intent", message.url || "", {
      decision: "tracked",
      source: classification.source,
      correlationId: hint && hint.correlationId ? hint.correlationId : ""
    });
    return { ok: true, intercept: false, tracked: true };
  })();
});

browser.webRequest.onBeforeSendHeaders.addListener(
  async (details) => {
    if (!(await getEnabled())) {
      return {};
    }
    if (!details || !isHttpUrl(details.url) || details.method !== "GET" || details.incognito) {
      return {};
    }

    const hint = getIntentHint(details.url);
    const context = buildContextFromDetails(details, hint);
    storeRequestContext(details.requestId, context);

    await logDebugEvent("request_context_captured", {
      url: context.url,
      requestId: context.requestId,
      requestType: context.requestType,
      correlationId: context.correlationId,
      headerCount: context.requestHeaders.length,
      hasUserAgent: context.userAgent.length > 0
    });
    return {};
  },
  { urls: ["http://*/*", "https://*/*"] },
  ["requestHeaders", "extraHeaders"]
);

browser.webRequest.onHeadersReceived.addListener(
  (details) => {
    return (async () => {
      if (!(await getEnabled())) {
        return {};
      }

      await logDebugEvent("webrequest_seen", {
        url: details && details.url ? details.url : "",
        requestType: details && details.type ? details.type : "",
        tabId: details && typeof details.tabId === "number" ? details.tabId : -1,
        frameId: details && typeof details.frameId === "number" ? details.frameId : -1,
        method: details && details.method ? details.method : "",
        requestId: details && details.requestId ? details.requestId : ""
      });

      const classification = classifyWebRequest(details);
      const context = getRequestContext(details);
      const hint = getIntentHint(details.url);

      if (!classification.ok) {
        if (classification.recordReject && details && details.url) {
          markRejectedUrl(details.url);
          recordDecision(details.url, "rejected");
        }
        await logClassifierDecision("webrequest", details && details.url ? details.url : "", {
          decision: "rejected",
          reason: classification.reason,
          requestType: details && details.type ? details.type : "",
          tabId: details && typeof details.tabId === "number" ? details.tabId : -1,
          frameId: details && typeof details.frameId === "number" ? details.frameId : -1,
          correlationId: context && context.correlationId ? context.correlationId : hint && hint.correlationId ? hint.correlationId : ""
        });
        if (classification.browserOnly && hint) {
          await notifyBrowserOnly(details.url, classification.reason, {
            correlationId: hint.correlationId
          });
        }
        return {};
      }

      const correlationId = context && context.correlationId
        ? context.correlationId
        : hint && hint.correlationId
          ? hint.correlationId
          : generateCorrelationId();
      const preferredFilename = context && context.suggestedFilename
        ? context.suggestedFilename
        : hint && hint.suggestedFilename
          ? hint.suggestedFilename
          : "";
      const payload = await buildHandoffPayload({
        url: details.url,
        source: classification.source,
        correlationId,
        requestMethod: context && context.requestMethod ? context.requestMethod : details.method || "GET",
        requestType: context && context.requestType ? context.requestType : details.type || "",
        tabUrl: context && context.tabUrl ? context.tabUrl : hint && hint.pageUrl ? hint.pageUrl : "",
        referrer: context && context.referrer ? context.referrer : hint && hint.referrer ? hint.referrer : "",
        pageTitle: context && context.pageTitle ? context.pageTitle : hint && hint.pageTitle ? hint.pageTitle : "",
        suggestedFilename: extractSuggestedFilename(
          details.responseHeaders || [],
          preferredFilename,
          details.url
        ),
        headers: context && Array.isArray(context.requestHeaders) ? context.requestHeaders : [],
        userAgent: context && context.userAgent ? context.userAgent : ""
      });

      if (!payload) {
        if (hint) {
          await notifyBrowserOnly(details.url, "browser-only-unreplayable", {
            correlationId: hint.correlationId
          });
        }
        return {};
      }

      recordDecision(details.url, "pending");
      await logClassifierDecision("webrequest", details.url, {
        decision: "pending",
        source: classification.source,
        requestType: details.type,
        tabId: details.tabId,
        frameId: details.frameId,
        correlationId: payload.correlationId,
        headerCount: payload.headers.length
      });

      try {
        const response = await handoffToDyx(payload);
        if (response && response.ok === true && response.accepted === true) {
          recordDecision(details.url, "accepted");
          await logClassifierDecision("webrequest", details.url, {
            decision: "accepted",
            source: classification.source,
            requestType: details.type,
            correlationId: payload.correlationId
          });
          return { cancel: true };
        }
      } catch (error) {
        await logNativeHandoffResult(classification.source, details.url, "failed", {
          correlationId: payload.correlationId,
          error: error && error.message ? error.message : String(error)
        });
      }

      markRejectedUrl(details.url);
      recordDecision(details.url, "rejected");
      await logClassifierDecision("webrequest", details.url, {
        decision: "rejected",
        reason: "handoff-failed",
        source: classification.source,
        requestType: details.type,
        correlationId: payload.correlationId
      });
      return {};
    })();
  },
  { urls: ["http://*/*", "https://*/*"] },
  ["blocking", "responseHeaders"]
);

browser.downloads.onCreated.addListener(async (item) => {
  if (!(await getEnabled())) {
    return;
  }
  if (!shouldHandleDownload(item)) {
    return;
  }

  const url = item.finalUrl || item.url || "";
  const context = getContextForUrl(url);
  const hint = getIntentHint(url);
  const decision = getDecision(url);

  await logDebugEvent("fallback_seen", {
    url,
    finalUrl: item.finalUrl || "",
    filename: item.filename || "",
    mime: item.mime || "",
    decision,
    correlationId: context && context.correlationId ? context.correlationId : hint && hint.correlationId ? hint.correlationId : ""
  });

  if (wasRecentlyRejected(url) || decision === "rejected") {
    await logClassifierDecision("fallback", url, {
      decision: "rejected",
      reason: "recent-rejected"
    });
    return;
  }

  if (wasRecentlyAccepted(url) || decision === "accepted") {
    await logDebugEvent("fallback_duplicate_cancelled", {
      url,
      downloadId: item.id
    });
    await cancelAndEraseIfPossible(item.id);
    return;
  }

  if (decision === "pending") {
    await sleep(PENDING_FALLBACK_WAIT_MS);
    const nextDecision = getDecision(url);
    if (nextDecision === "accepted" || wasRecentlyAccepted(url)) {
      await logDebugEvent("fallback_duplicate_cancelled_after_wait", {
        url,
        downloadId: item.id
      });
      await cancelAndEraseIfPossible(item.id);
      return;
    }
    if (nextDecision === "rejected" || wasRecentlyRejected(url)) {
      await logClassifierDecision("fallback", url, {
        decision: "rejected",
        reason: "rejected-after-wait"
      });
      return;
    }
  }

  const classification = classifyDownloadItem(item, context);
  if (!classification.ok) {
    if (classification.recordReject) {
      markRejectedUrl(url);
      recordDecision(url, "rejected");
    }
    await logClassifierDecision("fallback", url, {
      decision: "rejected",
      reason: classification.reason,
      finalUrl: item.finalUrl || "",
      filename: item.filename || "",
      mime: item.mime || "",
      correlationId: context && context.correlationId ? context.correlationId : hint && hint.correlationId ? hint.correlationId : ""
    });
    if (classification.browserOnly && hint) {
      await notifyBrowserOnly(url, classification.reason, {
        correlationId: hint.correlationId
      });
    }
    return;
  }

  const fallbackCorrelationId = context && context.correlationId
    ? context.correlationId
    : hint && hint.correlationId
      ? hint.correlationId
      : generateCorrelationId();
  const fallbackPreferredFilename = classification.suggestedFilename
    ? classification.suggestedFilename
    : context && context.suggestedFilename
      ? context.suggestedFilename
      : hint && hint.suggestedFilename
        ? hint.suggestedFilename
        : "";
  const payload = await buildHandoffPayload({
    url,
    source: classification.source,
    correlationId: fallbackCorrelationId,
    requestMethod: context && context.requestMethod ? context.requestMethod : "GET",
    requestType: context && context.requestType ? context.requestType : "download",
    tabUrl: context && context.tabUrl ? context.tabUrl : hint && hint.pageUrl ? hint.pageUrl : "",
    referrer: context && context.referrer ? context.referrer : hint && hint.referrer ? hint.referrer : "",
    pageTitle: context && context.pageTitle ? context.pageTitle : hint && hint.pageTitle ? hint.pageTitle : "",
    suggestedFilename: extractSuggestedFilename(
      [],
      fallbackPreferredFilename,
      url
    ),
    headers: context && Array.isArray(context.requestHeaders) ? context.requestHeaders : [],
    userAgent: context && context.userAgent ? context.userAgent : ""
  });

  if (!payload) {
    if (hint) {
      await notifyBrowserOnly(url, "browser-only-unreplayable", {
        correlationId: hint.correlationId
      });
    }
    return;
  }

  await logClassifierDecision("fallback", url, {
    decision: "accepted",
    source: classification.source,
    finalUrl: item.finalUrl || "",
    filename: item.filename || "",
    mime: item.mime || "",
    correlationId: payload.correlationId,
    headerCount: payload.headers.length
  });

  const paused = await pauseIfPossible(item.id);

  try {
    const response = await handoffToDyx(payload);
    if (response && response.ok === true && response.accepted === true) {
      recordDecision(url, "accepted");
      await cancelAndEraseIfPossible(item.id);
      return;
    }
  } catch (error) {
    await logNativeHandoffResult(classification.source, url, "failed", {
      correlationId: payload.correlationId,
      error: error && error.message ? error.message : String(error)
    });
  }

  markRejectedUrl(url);
  recordDecision(url, "rejected");
  if (paused) {
    await resumeIfPossible(item.id);
  }
});
