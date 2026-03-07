import type {
  AppSettings,
  AxelStatus,
  DashboardSnapshot,
  DownloadItem,
  HistoryItem,
  IpcEvent,
  IpcRequest,
  IpcResponse,
  DirectoryChoice,
  StartDownloadRequest
} from './types';

type EventHandler<T = unknown> = (event: IpcEvent<T>) => void;

interface DYXBridge {
  invoke?: (request: IpcRequest | string) => Promise<IpcResponse | string> | IpcResponse | string;
  onEvent?: (handler: EventHandler) => (() => void) | void;
}

declare global {
  interface Window {
    __DYX__?: DYXBridge;
  }
}

const mockBridge = createMockBridge();
const bridge = window.__DYX__ ?? mockBridge;

function makeId() {
  return `req_${Math.random().toString(36).slice(2, 10)}`;
}

function parseResponse<T>(value: IpcResponse<T> | string, id: string): IpcResponse<T> {
  if (typeof value === 'string') {
    return JSON.parse(value) as IpcResponse<T>;
  }
  return value ?? { id, ok: false, error: 'No response from backend' };
}

async function invoke<T = unknown, P = unknown>(method: string, params?: P): Promise<T> {
  if (!bridge.invoke) {
    throw new Error('No DYX bridge available');
  }

  const request: IpcRequest<P> = {
    id: makeId(),
    method,
    params
  };
  const response = parseResponse<T>(
    (await bridge.invoke(request)) as IpcResponse<T> | string,
    request.id
  );

  if (!response.ok) {
    throw new Error(response.error);
  }

  return response.result;
}

export function subscribeToEvents(handler: EventHandler) {
  const teardown = bridge.onEvent?.(handler);
  return () => {
    teardown?.();
  };
}

export async function checkAxel() {
  return invoke<AxelStatus>('checkAxel');
}

export async function getSettings() {
  return invoke<AppSettings>('getSettings');
}

export async function saveSettings(settings: AppSettings) {
  return invoke<AppSettings, AppSettings>('saveSettings', settings);
}

export async function listDownloads() {
  return invoke<DownloadItem[]>('listDownloads');
}

export async function listHistory() {
  return invoke<HistoryItem[]>('listHistory');
}

export async function loadDashboard(): Promise<DashboardSnapshot> {
  const [downloads, history] = await Promise.all([listDownloads(), listHistory()]);
  return { downloads, history };
}

export async function startDownload(request: StartDownloadRequest) {
  return invoke<DownloadItem, StartDownloadRequest>('startDownload', request);
}

export async function cancelDownload(id: string) {
  return invoke<void, { id: string }>('cancelDownload', { id });
}

export async function retryDownload(id: string) {
  return invoke<DownloadItem, { id: string }>('retryDownload', { id });
}

export async function removeHistoryItem(id: string) {
  return invoke<void, { id: string }>('removeHistoryItem', { id });
}

export async function openFile(path: string) {
  return invoke<void, { path: string }>('openFile', { path });
}

export async function openFolder(path: string) {
  return invoke<void, { path: string }>('openFolder', { path });
}

export async function deleteFile(path: string) {
  return invoke<void, { path: string }>('deleteFile', { path });
}

export async function chooseDirectory(path?: string | null) {
  return invoke<DirectoryChoice, { path?: string | null }>('chooseDirectory', path ? { path } : {});
}

function createMockBridge(): DYXBridge {
  const listeners = new Set<EventHandler>();
  const timers = new Map<string, number>();

  let axelStatus: AxelStatus = {
    available: true,
    version: 'Axel 2.17.14 (mock)',
    message: 'Running in UI mock mode'
  };

  let settings: AppSettings = {
    defaultDownloadDir: '/home/soka/Downloads',
    defaultConnections: 8,
    defaultMaxSpeedBytes: undefined,
    defaultNoClobber: true,
    defaultTimeoutSeconds: 30,
    theme: 'system'
  };

  let downloads: DownloadItem[] = [
    {
      id: 'live_1',
      url: 'https://example.com/releases/dyx-nightly.tar.xz',
      outputPath: '/home/soka/Downloads/dyx-nightly.tar.xz',
      status: 'downloading',
      progressPercent: 42,
      speedText: '13.6 MB/s',
      etaText: '00:12',
      startedAt: new Date(Date.now() - 1000 * 48).toISOString()
    },
    {
      id: 'live_2',
      url: 'https://mirror.example.net/asset-pack.zip',
      outputPath: '/home/soka/Downloads/asset-pack.zip',
      status: 'starting',
      progressPercent: 0,
      startedAt: new Date(Date.now() - 1000 * 9).toISOString()
    }
  ];

  let history: HistoryItem[] = [
    {
      id: 'hist_ok',
      url: 'https://example.com/video.mp4',
      outputPath: '/home/soka/Videos/video.mp4',
      status: 'completed',
      progressPercent: 100,
      speedText: '11.8 MB/s',
      etaText: '00:00',
      startedAt: new Date(Date.now() - 1000 * 60 * 25).toISOString(),
      finishedAt: new Date(Date.now() - 1000 * 60 * 18).toISOString()
    },
    {
      id: 'hist_fail',
      url: 'https://example.com/missing.iso',
      outputPath: '/home/soka/Downloads/missing.iso',
      status: 'failed',
      progressPercent: 15,
      errorMessage: 'Remote server returned 404.',
      startedAt: new Date(Date.now() - 1000 * 60 * 60).toISOString(),
      finishedAt: new Date(Date.now() - 1000 * 60 * 57).toISOString()
    }
  ];

  const emit = <T>(event: string, payload: T) => {
    listeners.forEach((listener) => {
      listener({ event, payload });
    });
  };

  const updateDownload = (id: string, patch: Partial<DownloadItem>) => {
    downloads = downloads.map((download) => {
      if (download.id !== id) {
        return download;
      }

      const next = { ...download, ...patch };
      emit('downloadStateChanged', next);
      return next;
    });
  };

  const finalizeDownload = (id: string, status: HistoryItem['status'], errorMessage?: string) => {
    const target = downloads.find((download) => download.id === id);
    if (!target) {
      return;
    }

    const finished: HistoryItem = {
      ...target,
      status,
      progressPercent: status === 'completed' ? 100 : target.progressPercent,
      errorMessage,
      finishedAt: new Date().toISOString(),
      etaText: '00:00'
    };

    downloads = downloads.filter((download) => download.id !== id);
    history = [finished, ...history];
    emit('downloadRemoved', { id });
    emit('historyChanged', history);
  };

  const startTicker = (id: string) => {
    if (timers.has(id)) {
      return;
    }

    const handle = window.setInterval(() => {
      const target = downloads.find((download) => download.id === id);
      if (!target) {
        window.clearInterval(handle);
        timers.delete(id);
        return;
      }

      const nextPercent = Math.min(100, target.progressPercent + Math.floor(Math.random() * 12) + 4);
      updateDownload(id, {
        status: 'downloading',
        progressPercent: nextPercent,
        speedText: `${(8 + Math.random() * 12).toFixed(1)} MB/s`,
        etaText: nextPercent >= 100 ? '00:00' : `00:${String(Math.max(1, Math.round((100 - nextPercent) / 7))).padStart(2, '0')}`
      });

      if (nextPercent >= 100) {
        window.clearInterval(handle);
        timers.delete(id);
        finalizeDownload(id, 'completed');
      }
    }, 1100);

    timers.set(id, handle);
  };

  downloads.forEach((download) => {
    if (download.status !== 'completed' && download.status !== 'failed' && download.status !== 'cancelled') {
      startTicker(download.id);
    }
  });

  async function handleRequest(request: IpcRequest): Promise<IpcResponse> {
    switch (request.method) {
      case 'checkAxel':
        return { id: request.id, ok: true, result: axelStatus };
      case 'getSettings':
        return { id: request.id, ok: true, result: settings };
      case 'saveSettings':
        settings = { ...settings, ...(request.params as Partial<AppSettings>) };
        return { id: request.id, ok: true, result: settings };
      case 'listDownloads':
        return { id: request.id, ok: true, result: downloads };
      case 'listHistory':
        return { id: request.id, ok: true, result: history };
      case 'startDownload': {
        const params = request.params as StartDownloadRequest;
        const item: DownloadItem = {
          id: `live_${Math.random().toString(36).slice(2, 10)}`,
          url: params.url,
          outputPath: params.outputPath || `${settings.defaultDownloadDir}/${params.url.split('/').pop() || 'download.bin'}`,
          status: 'starting',
          progressPercent: 0,
          speedText: 'Waiting...',
          etaText: '--:--',
          startedAt: new Date().toISOString()
        };
        downloads = [item, ...downloads];
        emit('downloadStateChanged', item);
        startTicker(item.id);
        return { id: request.id, ok: true, result: item };
      }
      case 'cancelDownload': {
        const { id } = request.params as { id: string };
        const timer = timers.get(id);
        if (timer) {
          window.clearInterval(timer);
          timers.delete(id);
        }
        finalizeDownload(id, 'cancelled', 'Cancelled from mock bridge.');
        return { id: request.id, ok: true, result: null };
      }
      case 'retryDownload': {
        const { id } = request.params as { id: string };
        const source = history.find((item) => item.id === id);
        if (!source) {
          return { id: request.id, ok: false, error: 'History item not found' };
        }
        const retry: DownloadItem = {
          ...source,
          id: `retry_${Math.random().toString(36).slice(2, 10)}`,
          status: 'starting',
          progressPercent: 0,
          errorMessage: undefined,
          finishedAt: undefined,
          startedAt: new Date().toISOString()
        };
        downloads = [retry, ...downloads];
        emit('downloadStateChanged', retry);
        startTicker(retry.id);
        return { id: request.id, ok: true, result: retry };
      }
      case 'removeHistoryItem': {
        const { id } = request.params as { id: string };
        history = history.filter((item) => item.id !== id);
        emit('historyChanged', history);
        return { id: request.id, ok: true, result: null };
      }
      case 'openFile':
      case 'openFolder':
        return { id: request.id, ok: true, result: null };
      default:
        return { id: request.id, ok: false, error: `Unknown IPC method: ${request.method}` };
    }
  }

  return {
    invoke(request) {
      const normalized = typeof request === 'string' ? (JSON.parse(request) as IpcRequest) : request;
      return handleRequest(normalized);
    },
    onEvent(handler) {
      listeners.add(handler);
      return () => {
        listeners.delete(handler);
      };
    }
  };
}
