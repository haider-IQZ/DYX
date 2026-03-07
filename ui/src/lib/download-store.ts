import { useEffect, useMemo, useRef, useState } from 'react';
import {
  cancelDownload,
  checkAxel,
  chooseDirectory as chooseDirectoryDialog,
  deleteFile,
  getSettings,
  listHistory,
  loadDashboard,
  openFile,
  openFolder,
  removeHistoryItem,
  retryDownload,
  saveSettings,
  startDownload,
  subscribeToEvents
} from '@/lib/api';
import type {
  AppSettings,
  AxelStatus,
  DashboardSnapshot,
  DownloadCard,
  DownloadItem,
  DownloadSettings,
  DownloadStatus,
  HistoryItem,
  IpcEvent,
  SpeedMode,
  StartDownloadRequest
} from '@/lib/types';

type PartialUiSettings = Partial<DownloadSettings>;

const SPEED_MODE_CONNECTIONS: Record<SpeedMode, number> = {
  maximum: 32,
  decent: 16,
  slow: 4
};

const SPEED_MODE_LIMITS: Record<SpeedMode, number> = {
  maximum: 64 * 1024 * 1024,
  decent: 20 * 1024 * 1024,
  slow: 4 * 1024 * 1024
};

function detectCategory(filename: string) {
  const ext = filename.split('.').pop()?.toLowerCase() ?? '';

  if (['mp4', 'mkv', 'avi', 'mov', 'webm', 'flv'].includes(ext)) return 'video';
  if (['mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a'].includes(ext)) return 'audio';
  if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'bmp'].includes(ext)) return 'image';
  if (['pdf', 'doc', 'docx', 'txt', 'xlsx', 'pptx', 'csv'].includes(ext)) return 'document';
  if (['zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz', 'iso'].includes(ext)) return 'archive';

  return 'other';
}

function pathBasename(path: string) {
  const parts = path.split(/[\\/]/);
  return parts[parts.length - 1] || path;
}

function pathDirname(path: string) {
  const normalized = path.replace(/\\/g, '/');
  const index = normalized.lastIndexOf('/');
  return index === -1 ? normalized : normalized.slice(0, index) || '/';
}

function toDate(value?: string | number) {
  if (value == null) return undefined;
  return new Date(value);
}

function mapStatus(status: DownloadStatus) {
  switch (status) {
    case 'completed':
      return 'completed';
    case 'failed':
      return 'error';
    case 'cancelled':
      return 'paused';
    case 'downloading':
      return 'downloading';
    case 'starting':
    case 'queued':
    default:
      return 'queued';
  }
}

function toCard(item: DownloadItem | HistoryItem, fallbackConnections: number): DownloadCard {
  const filename = pathBasename(item.outputPath || item.url);
  const totalBytes = item.totalBytes;
  const downloadedBytes =
    item.downloadedBytes ??
    (typeof totalBytes === 'number' ? Math.round((Math.max(0, Math.min(100, item.progressPercent)) / 100) * totalBytes) : undefined);
  return {
    id: item.id,
    url: item.url,
    filename,
    outputPath: item.outputPath,
    savePath: pathDirname(item.outputPath),
    status: mapStatus(item.status),
    rawStatus: item.status,
    category: detectCategory(filename),
    progressPercent: Math.max(0, Math.min(100, item.progressPercent)),
    downloadedBytes,
    totalBytes,
    speedText: item.speedText,
    etaText: item.etaText,
    error: item.errorMessage,
    addedAt: toDate(item.startedAt) ?? new Date(),
    completedAt: toDate(item.finishedAt),
    connections: fallbackConnections,
    maxConnections: fallbackConnections
  };
}

function inferSpeedMode(settings: AppSettings): SpeedMode {
  if (settings.defaultConnections >= 24) return 'maximum';
  if (settings.defaultConnections >= 10) return 'decent';
  return 'slow';
}

function toUiSettings(settings: AppSettings): DownloadSettings {
  return {
    speedMode: inferSpeedMode(settings),
    maxConcurrentDownloads: settings.maxConcurrentDownloads > 0 ? settings.maxConcurrentDownloads : 'unlimited',
    enableSpeedLimit: settings.defaultMaxSpeedBytes != null,
    autoRetryOnFail: settings.autoRetryOnFail,
    defaultSavePath: settings.defaultDownloadDir
  };
}

function mergeUiIntoBackend(ui: DownloadSettings, base: AppSettings): AppSettings {
  return {
    ...base,
    defaultDownloadDir: ui.defaultSavePath,
    defaultConnections: SPEED_MODE_CONNECTIONS[ui.speedMode],
    defaultMaxSpeedBytes: ui.enableSpeedLimit ? SPEED_MODE_LIMITS[ui.speedMode] : undefined,
    maxConcurrentDownloads: ui.maxConcurrentDownloads === 'unlimited' ? 0 : ui.maxConcurrentDownloads,
    autoRetryOnFail: ui.autoRetryOnFail
  };
}

function appSettingsEqual(left: AppSettings, right: AppSettings) {
  return (
    left.defaultDownloadDir === right.defaultDownloadDir &&
    left.defaultConnections === right.defaultConnections &&
    left.defaultMaxSpeedBytes === right.defaultMaxSpeedBytes &&
    left.defaultNoClobber === right.defaultNoClobber &&
    left.defaultTimeoutSeconds === right.defaultTimeoutSeconds &&
    left.maxConcurrentDownloads === right.maxConcurrentDownloads &&
    left.autoRetryOnFail === right.autoRetryOnFail &&
    left.theme === right.theme
  );
}

function speedLabelToBytes(speed?: string) {
  if (!speed) return 0;
  const match = speed.trim().match(/^([\d.]+)\s*([KMG]?B)\/s$/i);
  if (!match) return 0;
  const value = Number(match[1]);
  const unit = match[2].toUpperCase();
  const factor =
    unit === 'GB' ? 1024 * 1024 * 1024 : unit === 'MB' ? 1024 * 1024 : unit === 'KB' ? 1024 : 1;
  return value * factor;
}

export function useDownloads() {
  const [downloads, setDownloads] = useState<DownloadItem[]>([]);
  const [history, setHistory] = useState<HistoryItem[]>([]);
  const [axelStatus, setAxelStatus] = useState<AxelStatus | null>(null);
  const [settings, setSettings] = useState<DownloadSettings>({
    speedMode: 'decent',
    maxConcurrentDownloads: 'unlimited',
    enableSpeedLimit: false,
    autoRetryOnFail: true,
    defaultSavePath: '/home/soka/Downloads'
  });
  const [backendSettings, setBackendSettings] = useState<AppSettings | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const hydratedRef = useRef(false);
  const settingsRef = useRef(settings);
  const backendSettingsRef = useRef<AppSettings | null>(backendSettings);
  const pendingDeleteRef = useRef<Map<string, string>>(new Map());
  const pendingAutoRetryRef = useRef<Set<string>>(new Set());
  const autoRetryCountsRef = useRef<Map<string, number>>(new Map());

  useEffect(() => {
    settingsRef.current = settings;
  }, [settings]);

  useEffect(() => {
    backendSettingsRef.current = backendSettings;
  }, [backendSettings]);

  useEffect(() => {
    let cancelled = false;

    async function hydrate() {
      try {
        setIsLoading(true);
        setError(null);
        const [snapshot, nextAxelStatus, nextBackendSettings] = await Promise.all([
          loadDashboard(),
          checkAxel(),
          getSettings()
        ]);
        if (cancelled) return;

        setDownloads(snapshot.downloads);
        setHistory(snapshot.history);
        setAxelStatus(nextAxelStatus);
        setBackendSettings(nextBackendSettings);
        setSettings(toUiSettings(nextBackendSettings));
      } catch (cause) {
        if (!cancelled) {
          setError(cause instanceof Error ? cause.message : 'Failed to load downloads');
        }
      } finally {
        if (!cancelled) {
          hydratedRef.current = true;
          setIsLoading(false);
        }
      }
    }

    hydrate();

    const unsubscribe = subscribeToEvents((event: IpcEvent) => {
      if (cancelled) return;
      switch (event.event) {
        case 'downloadStateChanged':
          setDownloads((current) => upsertById(current, event.payload as DownloadItem));
          break;
        case 'downloadRemoved':
          setDownloads((current) =>
            current.filter((download) => download.id !== (event.payload as { id: string }).id)
          );
          break;
        case 'historyChanged':
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
                setError(cause instanceof Error ? cause.message : 'Failed to delete file');
              }
            })();
          }
          for (const item of event.payload as HistoryItem[]) {
            if (item.status === 'completed' || item.status === 'cancelled') {
              autoRetryCountsRef.current.delete(item.outputPath);
            }

            if (
              item.status !== 'failed' ||
              !settingsRef.current.autoRetryOnFail ||
              pendingDeleteRef.current.has(item.id) ||
              pendingAutoRetryRef.current.has(item.id)
            ) {
              continue;
            }

            const attempts = autoRetryCountsRef.current.get(item.outputPath) ?? 0;
            if (attempts >= 3) {
              continue;
            }

            pendingAutoRetryRef.current.add(item.id);
            autoRetryCountsRef.current.set(item.outputPath, attempts + 1);
            window.setTimeout(() => {
              void (async () => {
                try {
                  const created = await retryDownload(item.id);
                  setDownloads((current) => upsertById(current, created));
                  await removeHistoryItem(item.id);
                  setHistory((current) => current.filter((entry) => entry.id !== item.id));
                } catch (cause) {
                  setError(cause instanceof Error ? cause.message : 'Failed to retry download');
                } finally {
                  pendingAutoRetryRef.current.delete(item.id);
                }
              })();
            }, 1500);
          }
          break;
        case 'axelAvailabilityChanged':
          setAxelStatus(event.payload as AxelStatus);
          break;
        case 'settingsChanged': {
          const nextBackend = event.payload as AppSettings;
          setBackendSettings(nextBackend);
          setSettings(toUiSettings(nextBackend));
          break;
        }
        default:
          break;
      }
    });

    return () => {
      cancelled = true;
      unsubscribe();
    };
  }, []);

  useEffect(() => {
    if (!hydratedRef.current || !backendSettings) return;
    const nextBackend = mergeUiIntoBackend(settings, backendSettings);
    if (appSettingsEqual(nextBackend, backendSettings)) return;
    void (async () => {
      try {
        const saved = await saveSettings(nextBackend);
        setBackendSettings(saved);
      } catch (cause) {
        setError(cause instanceof Error ? cause.message : 'Failed to save settings');
      }
    })();
  }, [settings, backendSettings]);

  const mergedDownloads = useMemo(() => {
    const fallbackConnections = backendSettings?.defaultConnections ?? SPEED_MODE_CONNECTIONS[settings.speedMode];
    const activeOutputPaths = new Set(downloads.map((item) => item.outputPath));
    const visibleHistory = history.filter((item) => !activeOutputPaths.has(item.outputPath));
    const cards = [...downloads, ...visibleHistory].map((item) => toCard(item, fallbackConnections));
    cards.sort((left, right) => right.addedAt.getTime() - left.addedAt.getTime());
    return cards;
  }, [downloads, history, backendSettings, settings.speedMode]);

  const addDownload = async (url: string, filename?: string) => {
    const request: StartDownloadRequest = {
      url,
      connections: backendSettings?.defaultConnections,
      maxSpeedBytes: backendSettings?.defaultMaxSpeedBytes,
      noClobber: backendSettings?.defaultNoClobber,
      timeoutSeconds: backendSettings?.defaultTimeoutSeconds
    };

    if (filename?.trim()) {
      request.outputPath = `${settings.defaultSavePath.replace(/\/$/, '')}/${filename.trim()}`;
    }

    const created = await startDownload(request);
    setDownloads((current) => upsertById(current, created));
  };

  const pauseDownload = async (id: string) => {
    await cancelDownload(id);
  };

  const resumeDownload = async (id: string) => {
    const created = await retryDownload(id);
    setDownloads((current) => upsertById(current, created));
    await removeHistoryItem(id);
    setHistory((current) => current.filter((item) => item.id !== id));
  };

  const retryOne = async (id: string) => {
    const created = await retryDownload(id);
    setDownloads((current) => upsertById(current, created));
    await removeHistoryItem(id);
    setHistory((current) => current.filter((item) => item.id !== id));
  };

  const removeDownload = async (id: string) => {
    const activeItem = downloads.find((item) => item.id === id);
    if (activeItem) {
      pendingDeleteRef.current.set(id, activeItem.outputPath);
      await cancelDownload(id);
      return;
    }

    const historyItem = history.find((item) => item.id === id);
    if (!historyItem) return;

    await deleteFile(historyItem.outputPath);
    await removeHistoryItem(id);
    setHistory((current) => current.filter((item) => item.id !== id));
  };

  const pauseAll = async () => {
    await Promise.all(
      downloads
        .filter((item) => ['queued', 'starting', 'downloading'].includes(item.status))
        .map((item) => cancelDownload(item.id))
    );
  };

  const resumeAll = async () => {
    await Promise.all(
      history
        .filter((item) => item.status === 'cancelled' || item.status === 'failed')
        .map(async (item) => {
          const created = await retryDownload(item.id);
          setDownloads((current) => upsertById(current, created));
          await removeHistoryItem(item.id);
          setHistory((current) => current.filter((entry) => entry.id !== item.id));
        })
    );
  };

  const clearCompleted = async () => {
    const completed = history.filter((item) => item.status === 'completed');
    await Promise.all(completed.map((item) => removeHistoryItem(item.id)));
    setHistory((current) => current.filter((item) => item.status !== 'completed'));
  };

  const updateSettings = (nextSettings: PartialUiSettings) => {
    setSettings((current) => ({ ...current, ...nextSettings }));
  };

  const chooseDirectory = async (initialPath?: string | null) => {
    const selected = await chooseDirectoryDialog(initialPath ?? settingsRef.current.defaultSavePath);
    if (!selected?.path) {
      return selected;
    }

    setSettings((current) => ({ ...current, defaultSavePath: selected.path as string }));

    const currentBackend = backendSettingsRef.current;
    if (!currentBackend) {
      return selected;
    }

    const nextBackend = mergeUiIntoBackend(
      { ...settingsRef.current, defaultSavePath: selected.path },
      currentBackend
    );

    try {
      const saved = await saveSettings(nextBackend);
      setBackendSettings(saved);
      setSettings(toUiSettings(saved));
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Failed to save settings');
    }

    return selected;
  };

  const totalSpeed = useMemo(
    () =>
      mergedDownloads
        .filter((item) => item.status === 'downloading')
        .reduce((sum, item) => sum + speedLabelToBytes(item.speedText), 0),
    [mergedDownloads]
  );

  const completedToday = useMemo(() => {
    const today = new Date().toDateString();
    return mergedDownloads.filter(
      (item) => item.status === 'completed' && item.completedAt?.toDateString() === today
    ).length;
  }, [mergedDownloads]);

  return {
    downloads: mergedDownloads,
    rawDownloads: downloads,
    rawHistory: history,
    settings,
    axelStatus,
    isLoading,
    error,
    addDownload,
    removeDownload,
    pauseDownload,
    resumeDownload,
    retryDownload: retryOne,
    pauseAll,
    resumeAll,
    clearCompleted,
    updateSettings,
    openFile,
    openFolder,
    chooseDirectory,
    totalSpeed,
    completedToday
  };
}

function upsertById<T extends { id: string }>(items: T[], next: T) {
  const index = items.findIndex((item) => item.id === next.id);
  if (index === -1) {
    return [next, ...items];
  }

  const copy = [...items];
  copy[index] = next;
  return copy;
}
