"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { cancelDownload, checkAxel, deleteFile, getSettings, listDownloads, listHistory, openFolder, removeHistoryItem, retryDownload, startDownload, subscribeToBackendEvents } from "@/lib/dyx-api";
import type { AppSettings, DownloadItem as BackendDownloadItem, HistoryItem, IpcEvent } from "@/lib/dyx-types";

export type Download = {
  id: string;
  filename: string;
  url: string;
  outputPath: string;
  size: number;
  downloaded: number;
  speed: number;
  speedText?: string;
  etaText?: string;
  status: "downloading" | "paused" | "completed" | "queued" | "error";
  connections: number;
  fileType: "archive" | "video" | "audio" | "document" | "image" | "other";
  addedAt: Date;
};

function pathBasename(path: string) {
  const parts = path.split(/[\\/]/);
  return parts[parts.length - 1] || path;
}

function pathDirname(path: string) {
  const normalized = path.replace(/\\/g, "/");
  const index = normalized.lastIndexOf("/");
  return index === -1 ? normalized : normalized.slice(0, index) || "/";
}

function speedToBytes(speed?: string) {
  if (!speed) return 0;
  const match = speed.trim().match(/^([\d.]+)\s*([KMG]?B)\/s$/i);
  if (!match) return 0;
  const value = Number(match[1]);
  const unit = match[2].toUpperCase();
  const factor = unit === "GB" ? 1024 ** 3 : unit === "MB" ? 1024 ** 2 : unit === "KB" ? 1024 : 1;
  return Math.round(value * factor);
}

function detectFileType(filename: string): Download["fileType"] {
  const ext = filename.split(".").pop()?.toLowerCase() ?? "";
  if (["mp4", "mkv", "avi", "mov", "webm"].includes(ext)) return "video";
  if (["mp3", "wav", "flac", "aac", "ogg"].includes(ext)) return "audio";
  if (["jpg", "jpeg", "png", "gif", "webp", "svg"].includes(ext)) return "image";
  if (["pdf", "doc", "docx", "txt", "csv", "xlsx", "pptx"].includes(ext)) return "document";
  if (["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "iso", "dmg"].includes(ext)) return "archive";
  return "other";
}

function mapStatus(status: BackendDownloadItem["status"]): Download["status"] {
  if (status === "completed") return "completed";
  if (status === "failed") return "error";
  if (status === "cancelled") return "paused";
  if (status === "downloading") return "downloading";
  return "queued";
}

function toDownload(item: BackendDownloadItem | HistoryItem, fallbackConnections: number): Download {
  const filename = pathBasename(item.outputPath || item.url);
  const size = item.totalBytes ?? 0;
  const downloaded =
    item.downloadedBytes ??
    (size > 0 ? Math.round((Math.max(0, Math.min(100, item.progressPercent)) / 100) * size) : 0);

  return {
    id: item.id,
    filename,
    url: item.url,
    outputPath: item.outputPath,
    size,
    downloaded,
    speed: speedToBytes(item.speedText),
    speedText: item.speedText,
    etaText: item.etaText,
    status: mapStatus(item.status),
    connections: fallbackConnections,
    fileType: detectFileType(filename),
    addedAt: new Date(item.startedAt),
  };
}

function upsertById<T extends { id: string }>(items: T[], next: T) {
  const index = items.findIndex((item) => item.id === next.id);
  if (index === -1) return [next, ...items];
  const copy = items.slice();
  copy[index] = next;
  return copy;
}

export function useDyxDownloads() {
  const [downloads, setDownloads] = useState<BackendDownloadItem[]>([]);
  const [history, setHistory] = useState<HistoryItem[]>([]);
  const [settings, setSettings] = useState<AppSettings | null>(null);
  const [axelVersion, setAxelVersion] = useState<string>("Detecting...");
  const [axelAvailable, setAxelAvailable] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);
  const pendingDeleteRef = useRef<Map<string, string>>(new Map());

  useEffect(() => {
    let cancelled = false;

    async function hydrate() {
      try {
        const [nextDownloads, nextHistory, nextSettings, nextAxel] = await Promise.all([
          listDownloads(),
          listHistory(),
          getSettings(),
          checkAxel(),
        ]);
        if (cancelled) return;
        setDownloads(nextDownloads);
        setHistory(nextHistory);
        setSettings(nextSettings);
        setAxelVersion(nextAxel.version ?? (nextAxel.available ? "Available" : "Missing"));
        setAxelAvailable(nextAxel.available);
      } catch (cause) {
        if (!cancelled) {
          setError(cause instanceof Error ? cause.message : "Failed to load downloads");
        }
      }
    }

    hydrate();

    let unlisten: (() => void) | undefined;
    void subscribeToBackendEvents((event: IpcEvent) => {
      if (cancelled) return;
      switch (event.event) {
        case "downloadStateChanged":
          setDownloads((current) => upsertById(current, event.payload as BackendDownloadItem));
          break;
        case "downloadRemoved":
          setDownloads((current) => current.filter((item) => item.id !== (event.payload as { id: string }).id));
          break;
        case "historyChanged":
          setHistory(event.payload as HistoryItem[]);
          for (const item of event.payload as HistoryItem[]) {
            const pendingPath = pendingDeleteRef.current.get(item.id);
            if (!pendingPath) continue;
            pendingDeleteRef.current.delete(item.id);
            void (async () => {
              try {
                await deleteFile(pendingPath);
                await removeHistoryItem(item.id);
                setHistory((current) => current.filter((entry) => entry.id !== item.id));
              } catch (cause) {
                setError(cause instanceof Error ? cause.message : "Failed to delete file");
              }
            })();
          }
          break;
        case "axelAvailabilityChanged": {
          const status = event.payload as { available: boolean; version?: string };
          setAxelAvailable(status.available);
          setAxelVersion(status.version ?? (status.available ? "Available" : "Missing"));
          break;
        }
        case "settingsChanged":
          setSettings(event.payload as AppSettings);
          break;
      }
    }).then((dispose) => {
      unlisten = dispose;
    });

    return () => {
      cancelled = true;
      unlisten?.();
    };
  }, []);

  const mergedDownloads = useMemo(() => {
    const fallbackConnections = settings?.defaultConnections ?? 8;
    const activeOutputPaths = new Set(downloads.map((item) => item.outputPath));
    const visibleHistory = history.filter((item) => !activeOutputPaths.has(item.outputPath));
    return [...downloads, ...visibleHistory]
      .map((item) => toDownload(item, fallbackConnections))
      .sort((a, b) => b.addedAt.getTime() - a.addedAt.getTime());
  }, [downloads, history, settings]);

  const stats = useMemo(() => {
    const active = mergedDownloads.filter((item) => item.status === "downloading");
    return {
      active: active.length,
      total: mergedDownloads.length,
      downloadSpeed: active.reduce((sum, item) => sum + item.speed, 0),
    };
  }, [mergedDownloads]);

  const addDownload = async (url: string, connections: number, savePath?: string) => {
    const normalizedSavePath = savePath?.trim() || settings?.defaultDownloadDir;
    const fileName = pathBasename(new URL(url).pathname || "download");
    await startDownload({
      url,
      connections,
      outputPath: normalizedSavePath ? `${normalizedSavePath.replace(/\/$/, "")}/${fileName}` : undefined,
    });
  };

  const togglePause = async (id: string) => {
    const item = mergedDownloads.find((entry) => entry.id === id);
    if (!item) return;
    if (item.status === "downloading" || item.status === "queued") {
      await cancelDownload(id);
    } else if (item.status === "paused" || item.status === "error") {
      await retryDownload(id);
    }
  };

  const removeDownload = async (id: string) => {
    const active = downloads.find((item) => item.id === id);
    if (active) {
      pendingDeleteRef.current.set(id, active.outputPath);
      await cancelDownload(id);
      return;
    }

    const historyItem = history.find((item) => item.id === id);
    if (!historyItem) return;
    await deleteFile(historyItem.outputPath);
    await removeHistoryItem(id);
    setHistory((current) => current.filter((item) => item.id !== id));
  };

  const revealDownload = async (id: string) => {
    const item = mergedDownloads.find((entry) => entry.id === id);
    if (!item) return;
    await openFolder(item.outputPath);
  };

  return {
    downloads: mergedDownloads,
    stats,
    defaultSavePath: settings?.defaultDownloadDir ?? "~/Downloads",
    axelVersion,
    axelAvailable,
    error,
    addDownload,
    togglePause,
    removeDownload,
    revealDownload,
  };
}
