export type DownloadStatus =
  | "queued"
  | "starting"
  | "downloading"
  | "completed"
  | "failed"
  | "cancelled";

export interface StartDownloadRequest {
  url: string;
  outputPath?: string;
  connections?: number;
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
  maxConcurrentDownloads: number;
  autoRetryOnFail: boolean;
  theme: "system" | "light" | "dark";
}

export interface AxelStatus {
  available: boolean;
  version?: string;
  path?: string;
  message?: string;
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
