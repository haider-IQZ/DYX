"use client"

import { useState } from "react"
import { 
  Pause, 
  Play, 
  Trash2, 
  FolderOpen, 
  Archive, 
  Video, 
  Music, 
  FileText,
  Image,
  File,
  CheckCircle2,
  Clock,
  AlertCircle
} from "lucide-react"
import type { Download } from "@/app/page"
import { cn } from "@/lib/utils"

type DownloadItemProps = {
  download: Download
  onTogglePause: (id: string) => void
  onRemove: (id: string) => void
  onOpenFolder: (id: string) => void
}

const formatSize = (bytes: number) => {
  if (bytes >= 1000000000) return `${(bytes / 1000000000).toFixed(2)} GB`
  if (bytes >= 1000000) return `${(bytes / 1000000).toFixed(1)} MB`
  if (bytes >= 1000) return `${(bytes / 1000).toFixed(1)} KB`
  return `${bytes} B`
}

const formatSpeed = (bytes: number) => {
  if (bytes >= 1000000) return `${(bytes / 1000000).toFixed(1)} MB/s`
  if (bytes >= 1000) return `${(bytes / 1000).toFixed(1)} KB/s`
  return `${bytes} B/s`
}

const getFileIcon = (type: string) => {
  switch (type) {
    case "archive": return Archive
    case "video": return Video
    case "audio": return Music
    case "document": return FileText
    case "image": return Image
    default: return File
  }
}

const getStatusColor = (status: string) => {
  switch (status) {
    case "downloading": return "text-blue-400"
    case "completed": return "text-green-400"
    case "paused": return "text-yellow-400"
    case "queued": return "text-muted-foreground"
    case "error": return "text-red-400"
    default: return "text-muted-foreground"
  }
}

const getStatusIcon = (status: string) => {
  switch (status) {
    case "completed": return CheckCircle2
    case "queued": return Clock
    case "error": return AlertCircle
    default: return null
  }
}

export function DownloadItem({ download, onTogglePause, onRemove, onOpenFolder }: DownloadItemProps) {
  const [isHovered, setIsHovered] = useState(false)
  
  const progress = (download.downloaded / download.size) * 100
  const FileIcon = getFileIcon(download.fileType)
  const StatusIcon = getStatusIcon(download.status)
  
  const remainingBytes = download.size - download.downloaded
  const eta = download.speed > 0 ? remainingBytes / download.speed : 0
  const etaMinutes = Math.floor(eta / 60)
  const etaSeconds = Math.floor(eta % 60)

  return (
    <div
      className={cn(
        "group relative bg-card border border-border rounded-xl p-4 transition-all duration-200",
        isHovered && "border-primary/50 shadow-lg shadow-primary/5"
      )}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
    >
      <div className="flex items-start gap-4">
        {/* File Icon */}
        <div className={cn(
          "w-12 h-12 rounded-xl flex items-center justify-center shrink-0",
          download.status === "completed" ? "bg-green-500/20" : "bg-muted"
        )}>
          <FileIcon className={cn(
            "w-6 h-6",
            download.status === "completed" ? "text-green-400" : "text-muted-foreground"
          )} />
        </div>

        {/* Content */}
        <div className="flex-1 min-w-0">
          <div className="flex items-start justify-between gap-4">
            <div className="min-w-0">
              <h3 className="text-sm font-medium text-foreground truncate">
                {download.filename}
              </h3>
              <p className="text-xs text-muted-foreground truncate mt-0.5">
                {download.url}
              </p>
            </div>

            {/* Action Buttons */}
            <div className={cn(
              "flex items-center gap-1 transition-opacity duration-200",
              isHovered ? "opacity-100" : "opacity-0"
            )}>
              {(download.status === "downloading" || download.status === "paused") && (
                <button
                  onClick={() => onTogglePause(download.id)}
                  className="w-8 h-8 rounded-lg bg-muted hover:bg-muted/80 flex items-center justify-center transition-colors"
                >
                  {download.status === "downloading" ? (
                    <Pause className="w-4 h-4 text-foreground" />
                  ) : (
                    <Play className="w-4 h-4 text-foreground" />
                  )}
                </button>
              )}
              <button
                onClick={() => onOpenFolder(download.id)}
                className="w-8 h-8 rounded-lg bg-muted hover:bg-muted/80 flex items-center justify-center transition-colors"
              >
                <FolderOpen className="w-4 h-4 text-foreground" />
              </button>
              <button
                onClick={() => onRemove(download.id)}
                className="w-8 h-8 rounded-lg bg-red-500/20 hover:bg-red-500/30 flex items-center justify-center transition-colors"
              >
                <Trash2 className="w-4 h-4 text-red-400" />
              </button>
            </div>
          </div>

          {/* Progress Bar */}
          <div className="mt-3">
            <div className="h-1.5 bg-muted rounded-full overflow-hidden">
              <div
                className={cn(
                  "h-full rounded-full transition-all duration-300 relative",
                  download.status === "completed" 
                    ? "bg-green-500" 
                    : download.status === "downloading"
                    ? "bg-primary"
                    : download.status === "paused"
                    ? "bg-yellow-500"
                    : "bg-muted-foreground"
                )}
                style={{ width: `${progress}%` }}
              >
                {download.status === "downloading" && (
                  <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/30 to-transparent animate-shimmer" />
                )}
              </div>
            </div>
          </div>

          {/* Stats */}
          <div className="flex items-center justify-between mt-2">
            <div className="flex items-center gap-3 text-xs">
              <span className="text-muted-foreground">
                {formatSize(download.downloaded)} / {formatSize(download.size)}
              </span>
              <span className="text-muted-foreground">
                {progress.toFixed(1)}%
              </span>
              {download.status === "downloading" && download.speed > 0 && (
                <>
                  <span className="text-blue-400 font-medium">
                    {formatSpeed(download.speed)}
                  </span>
                  <span className="text-muted-foreground">
                    ETA: {etaMinutes}m {etaSeconds}s
                  </span>
                </>
              )}
            </div>

            <div className="flex items-center gap-2">
              {StatusIcon && (
                <StatusIcon className={cn("w-4 h-4", getStatusColor(download.status))} />
              )}
              <span className={cn("text-xs font-medium capitalize", getStatusColor(download.status))}>
                {download.status}
              </span>
              <span className="text-xs text-muted-foreground">
                {download.connections} connections
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
