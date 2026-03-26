(function () {
  function isModifiedClick(event) {
    return event.defaultPrevented
      || event.button !== 0
      || event.metaKey
      || event.ctrlKey
      || event.shiftKey
      || event.altKey;
  }

  function isHttpUrl(urlString) {
    try {
      const url = new URL(urlString, window.location.href);
      return url.protocol === "http:" || url.protocol === "https:";
    } catch (_) {
      return false;
    }
  }

  function pathExtension(urlString) {
    try {
      const url = new URL(urlString, window.location.href);
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

  function looksFileLike(urlString, downloadAttr) {
    if (typeof downloadAttr === "string" && downloadAttr.trim().length > 0) {
      return true;
    }
    const extension = pathExtension(urlString);
    return [
      "png", "jpg", "jpeg", "webp", "gif", "bmp", "avif",
      "zip", "rar", "7z", "tar", "gz", "xz", "deb", "rpm", "apk", "dmg", "pkg", "pdf",
      "mp4", "mkv", "webm", "mov", "avi", "mp3", "m4a", "flac", "wav", "ogg"
    ].includes(extension);
  }

  function combinedAnchorText(anchor) {
    return [
      anchor.textContent || "",
      anchor.getAttribute("aria-label") || "",
      anchor.getAttribute("title") || ""
    ].join(" ").trim().toLowerCase();
  }

  function sameOrigin(urlString) {
    try {
      const url = new URL(urlString, window.location.href);
      return url.origin === window.location.origin;
    } catch (_) {
      return false;
    }
  }

  function looksFileServing(urlString) {
    return /download|attachment|file/i.test(urlString);
  }

  function suggestsDownloadIntent(anchor) {
    const text = combinedAnchorText(anchor);
    return ["download", "save", "get file"].some((word) => text.includes(word));
  }

  function findDownloadIntent(eventTarget) {
    const anchor = eventTarget instanceof Element ? eventTarget.closest("a[href]") : null;
    if (!anchor) {
      return null;
    }

    const href = anchor.href || "";
    if (!isHttpUrl(href)) {
      return null;
    }

    const downloadAttr = anchor.getAttribute("download") || "";
    const mildIntentMatch = suggestsDownloadIntent(anchor) && (sameOrigin(href) || looksFileServing(href));
    if (!looksFileLike(href, downloadAttr) && !mildIntentMatch) {
      return null;
    }

    return {
      url: href,
      filename: downloadAttr.trim(),
      href,
      anchorText: (anchor.textContent || "").trim(),
      anchorLabel: anchor.getAttribute("aria-label") || "",
      anchorTitle: anchor.getAttribute("title") || "",
      sameOrigin: sameOrigin(href),
      pageUrl: window.location.href,
      pageTitle: document.title || "",
      referrer: document.referrer || ""
    };
  }

  document.addEventListener("click", (event) => {
    if (!event.isTrusted || isModifiedClick(event)) {
      return;
    }

    const intent = findDownloadIntent(event.target);
    if (!intent) {
      return;
    }

    browser.runtime.sendMessage({
      type: "intent-click",
      url: intent.url,
      filename: intent.filename,
      anchorText: intent.anchorText,
      anchorLabel: intent.anchorLabel,
      anchorTitle: intent.anchorTitle,
      sameOrigin: intent.sameOrigin,
      pageUrl: intent.pageUrl,
      pageTitle: intent.pageTitle,
      referrer: intent.referrer
    }).catch(() => {});
  }, true);
})();
