'use client'

import { Button } from '@/components/ui/button'
import { Progress } from '@/components/ui/progress'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import {
  Pause,
  Play,
  X,
  MoreVertical,
  FolderOpen,
  Copy,
  RefreshCw,
  FileVideo,
  FileAudio,
  FileImage,
  FileText,
  FileArchive,
  File,
  AlertCircle,
  CheckCircle2,
  Clock,
  Loader2,
  Zap
} from 'lucide-react'
import type { Download } from '@/lib/types'

interface DownloadItemProps {
  download: Download
  onPause: (id: string) => void
  onResume: (id: string) => void
  onRemove: (id: string) => void
  onRetry: (id: string) => void
}

function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 B'
  const k = 1024
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return `${(bytes / Math.pow(k, i)).toFixed(2)} ${sizes[i]}`
}

function formatSpeed(bytesPerSecond: number): string {
  if (bytesPerSecond === 0) return '--'
  const k = 1024
  const sizes = ['B/s', 'KB/s', 'MB/s', 'GB/s']
  const i = Math.floor(Math.log(bytesPerSecond) / Math.log(k))
  return `${(bytesPerSecond / Math.pow(k, i)).toFixed(1)} ${sizes[i]}`
}

function formatETA(downloaded: number, total: number, speed: number): string {
  if (speed === 0 || downloaded >= total) return '--'
  const remaining = total - downloaded
  const seconds = remaining / speed
  
  if (seconds < 60) return `${Math.round(seconds)}s`
  if (seconds < 3600) return `${Math.round(seconds / 60)}m`
  if (seconds < 86400) {
    const hours = Math.floor(seconds / 3600)
    const mins = Math.round((seconds % 3600) / 60)
    return `${hours}h ${mins}m`
  }
  return `${Math.round(seconds / 86400)}d`
}

function formatTimeAgo(date: Date): string {
  const seconds = Math.floor((Date.now() - date.getTime()) / 1000)
  
  if (seconds < 60) return 'Just now'
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`
  return `${Math.floor(seconds / 86400)}d ago`
}

const categoryIcons = {
  video: FileVideo,
  audio: FileAudio,
  image: FileImage,
  document: FileText,
  archive: FileArchive,
  other: File
}

const statusConfig = {
  downloading: {
    icon: Loader2,
    color: 'text-primary',
    bgColor: 'bg-primary/10',
    label: 'Downloading'
  },
  paused: {
    icon: Pause,
    color: 'text-warning',
    bgColor: 'bg-warning/10',
    label: 'Paused'
  },
  completed: {
    icon: CheckCircle2,
    color: 'text-success',
    bgColor: 'bg-success/10',
    label: 'Completed'
  },
  error: {
    icon: AlertCircle,
    color: 'text-destructive',
    bgColor: 'bg-destructive/10',
    label: 'Error'
  },
  queued: {
    icon: Clock,
    color: 'text-muted-foreground',
    bgColor: 'bg-muted',
    label: 'Queued'
  }
}

export function DownloadItem({ download, onPause, onResume, onRemove, onRetry }: DownloadItemProps) {
  const progress = (download.downloaded / download.size) * 100
  const CategoryIcon = categoryIcons[download.category]
  const statusInfo = statusConfig[download.status]
  const StatusIcon = statusInfo.icon

  return (
    <div className="group relative flex items-start gap-4 rounded-lg border border-border bg-card p-4 transition-all hover:border-primary/30 hover:bg-card/80">
      {/* File Icon */}
      <div className={`flex h-12 w-12 shrink-0 items-center justify-center rounded-lg ${statusInfo.bgColor}`}>
        <CategoryIcon className={`h-6 w-6 ${statusInfo.color}`} />
      </div>

      {/* Main Content */}
      <div className="min-w-0 flex-1">
        <div className="flex items-start justify-between gap-4">
          <div className="min-w-0 flex-1">
            <h3 className="truncate text-sm font-medium text-foreground">{download.filename}</h3>
            <div className="mt-1 flex items-center gap-2 text-xs text-muted-foreground">
              <StatusIcon className={`h-3 w-3 ${download.status === 'downloading' ? 'animate-spin' : ''} ${statusInfo.color}`} />
              <span className={statusInfo.color}>{statusInfo.label}</span>
              <span className="text-border">|</span>
              <span>{formatTimeAgo(download.addedAt)}</span>
            </div>
          </div>

          {/* Actions */}
          <div className="flex shrink-0 items-center gap-1">
            {download.status === 'downloading' && (
              <Button variant="ghost" size="icon" className="h-8 w-8" onClick={() => onPause(download.id)}>
                <Pause className="h-4 w-4" />
              </Button>
            )}
            {download.status === 'paused' && (
              <Button variant="ghost" size="icon" className="h-8 w-8" onClick={() => onResume(download.id)}>
                <Play className="h-4 w-4" />
              </Button>
            )}
            {download.status === 'error' && (
              <Button variant="ghost" size="icon" className="h-8 w-8" onClick={() => onRetry(download.id)}>
                <RefreshCw className="h-4 w-4" />
              </Button>
            )}
            {download.status === 'queued' && (
              <Button variant="ghost" size="icon" className="h-8 w-8" onClick={() => onResume(download.id)}>
                <Play className="h-4 w-4" />
              </Button>
            )}

            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button variant="ghost" size="icon" className="h-8 w-8">
                  <MoreVertical className="h-4 w-4" />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end" className="w-48">
                <DropdownMenuItem>
                  <FolderOpen className="mr-2 h-4 w-4" />
                  Open Folder
                </DropdownMenuItem>
                <DropdownMenuItem>
                  <Copy className="mr-2 h-4 w-4" />
                  Copy URL
                </DropdownMenuItem>
                <DropdownMenuSeparator />
                <DropdownMenuItem
                  className="text-destructive focus:text-destructive"
                  onClick={() => onRemove(download.id)}
                >
                  <X className="mr-2 h-4 w-4" />
                  Remove
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        </div>

        {/* Progress Section */}
        {download.status !== 'completed' && download.status !== 'error' && (
          <div className="mt-3">
            <div className="relative h-2 overflow-hidden rounded-full bg-secondary">
              <div
                className={`absolute inset-y-0 left-0 rounded-full transition-all ${
                  download.status === 'downloading' 
                    ? 'bg-primary' 
                    : download.status === 'paused' 
                    ? 'bg-warning' 
                    : 'bg-muted-foreground'
                }`}
                style={{ width: `${progress}%` }}
              />
              {download.status === 'downloading' && (
                <div 
                  className="absolute inset-y-0 left-0 animate-pulse rounded-full bg-primary/50"
                  style={{ width: `${progress}%` }}
                />
              )}
            </div>
          </div>
        )}

        {/* Stats Row */}
        <div className="mt-3 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs">
          <div className="flex items-center gap-1.5 text-muted-foreground">
            <span className="font-mono">
              {formatBytes(download.downloaded)} / {formatBytes(download.size)}
            </span>
            <span className="text-border">({progress.toFixed(1)}%)</span>
          </div>
          
          {download.status === 'downloading' && (
            <>
              <div className="h-3 w-px bg-border" />
              <div className="flex items-center gap-1.5 font-mono text-primary">
                {formatSpeed(download.speed)}
              </div>
              <div className="h-3 w-px bg-border" />
              <div className="flex items-center gap-1.5 text-muted-foreground">
                <Clock className="h-3 w-3" />
                {formatETA(download.downloaded, download.size, download.speed)}
              </div>
              <div className="h-3 w-px bg-border" />
              <div className="flex items-center gap-1.5 text-muted-foreground">
                <Zap className="h-3 w-3" />
                {download.connections}/{download.maxConnections} connections
              </div>
            </>
          )}

          {download.status === 'error' && download.error && (
            <div className="text-destructive">{download.error}</div>
          )}
        </div>
      </div>
    </div>
  )
}
