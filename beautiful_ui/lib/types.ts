export type DownloadStatus = 'downloading' | 'paused' | 'completed' | 'error' | 'queued'

export type FileCategory = 'video' | 'audio' | 'image' | 'document' | 'archive' | 'other'

export interface Download {
  id: string
  filename: string
  url: string
  size: number
  downloaded: number
  speed: number
  status: DownloadStatus
  category: FileCategory
  connections: number
  maxConnections: number
  addedAt: Date
  completedAt?: Date
  error?: string
  savePath: string
}

export type SpeedMode = 'maximum' | 'decent' | 'slow'

export interface DownloadSettings {
  speedMode: SpeedMode
  maxConcurrentDownloads: number | 'unlimited'
  enableSpeedLimit: boolean
  autoRetryOnFail: boolean
  defaultSavePath: string
}
