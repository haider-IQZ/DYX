export type ThemeMode = 'system' | 'light' | 'dark';
export type DownloadStatus =
  | 'queued'
  | 'starting'
  | 'downloading'
  | 'completed'
  | 'failed'
  | 'cancelled';

export interface StartDownloadRequest {
  url: string;
  outputPath?: string;
  connections?: number;
  maxSpeedBytes?: number;
  headers?: string[];
  userAgent?: string;
  ipv4?: boolean;
  ipv6?: boolean;
  noProxy?: boolean;
  insecure?: boolean;
  noClobber?: boolean;
  timeoutSeconds?: number;
}

export interface DownloadItem {
  id: string;
  url: string;
  outputPath: string;
  status: DownloadStatus;
  progressPercent: number;
  downloadedBytes?: number;
  totalBytes?: number;
  speedText?: string;
  etaText?: string;
  errorMessage?: string;
  startedAt: string | number;
  finishedAt?: string | number;
}

export interface HistoryItem extends DownloadItem {}

export interface AppSettings {
  defaultDownloadDir: string;
  defaultConnections: number;
  defaultMaxSpeedBytes?: number;
  defaultNoClobber: boolean;
  defaultTimeoutSeconds: number;
  theme: ThemeMode;
}

export interface AxelStatus {
  available: boolean;
  version?: string;
  path?: string;
  message?: string;
}

export interface DirectoryChoice {
  path: string | null;
}

export interface IpcRequest<T = unknown> {
  id: string;
  method: string;
  params?: T;
}

export interface IpcSuccess<T = unknown> {
  id: string;
  ok: true;
  result: T;
}

export interface IpcFailure {
  id: string;
  ok: false;
  error: string;
}

export type IpcResponse<T = unknown> = IpcSuccess<T> | IpcFailure;

export interface IpcEvent<T = unknown> {
  event: string;
  payload: T;
}

export interface DashboardSnapshot {
  downloads: DownloadItem[];
  history: HistoryItem[];
}

export type DownloadCardStatus =
  | 'queued'
  | 'downloading'
  | 'paused'
  | 'completed'
  | 'error';

export type FileCategory =
  | 'video'
  | 'audio'
  | 'image'
  | 'document'
  | 'archive'
  | 'other';

export type SpeedMode = 'maximum' | 'decent' | 'slow';

export interface DownloadCard {
  id: string;
  url: string;
  filename: string;
  outputPath: string;
  savePath: string;
  status: DownloadCardStatus;
  rawStatus: DownloadStatus;
  category: FileCategory;
  progressPercent: number;
  downloadedBytes?: number;
  totalBytes?: number;
  speedText?: string;
  etaText?: string;
  error?: string;
  addedAt: Date;
  completedAt?: Date;
  connections: number;
  maxConnections: number;
}

export interface DownloadSettings {
  speedMode: SpeedMode;
  maxConcurrentDownloads: number | 'unlimited';
  enableSpeedLimit: boolean;
  autoRetryOnFail: boolean;
  defaultSavePath: string;
}
