import {
  AlertCircle,
  CheckCircle2,
  Clock,
  Copy,
  File,
  FileArchive,
  FileAudio,
  FileImage,
  FileText,
  FileVideo,
  FolderOpen,
  Loader2,
  MoreVertical,
  Pause,
  Play,
  RefreshCw,
  X,
  Zap
} from '@/components/ui/icons';
import { Button } from '@/components/ui/button';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger
} from '@/components/ui/dropdown-menu';
import type { DownloadCard } from '@/lib/types';

interface DownloadItemProps {
  download: DownloadCard;
  onPause: (id: string) => Promise<void> | void;
  onResume: (id: string) => Promise<void> | void;
  onRemove: (id: string) => Promise<void> | void;
  onRetry: (id: string) => Promise<void> | void;
  onOpenFile: (path: string) => Promise<void> | void;
  onOpenFolder: (path: string) => Promise<void> | void;
}

function formatTimeAgo(date: Date) {
  const seconds = Math.floor((Date.now() - date.getTime()) / 1000);
  if (seconds < 60) return 'Just now';
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
  return `${Math.floor(seconds / 86400)}d ago`;
}

function formatBytes(bytes: number) {
  if (!Number.isFinite(bytes) || bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  const index = Math.min(units.length - 1, Math.floor(Math.log(bytes) / Math.log(1024)));
  const value = bytes / Math.pow(1024, index);
  const digits = index >= 3 ? 2 : index >= 2 ? 1 : 0;
  return `${value.toFixed(digits)} ${units[index]}`;
}

const categoryIcons = {
  video: FileVideo,
  audio: FileAudio,
  image: FileImage,
  document: FileText,
  archive: FileArchive,
  other: File
};

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
} as const;

export function DownloadItem({
  download,
  onPause,
  onResume,
  onRemove,
  onRetry,
  onOpenFile,
  onOpenFolder
}: DownloadItemProps) {
  const CategoryIcon = categoryIcons[download.category];
  const statusInfo = statusConfig[download.status];
  const StatusIcon = statusInfo.icon;
  const sizeLabel =
    typeof download.totalBytes === 'number'
      ? `${formatBytes(download.downloadedBytes ?? 0)} / ${formatBytes(download.totalBytes)}`
      : null;

  const copyUrl = async () => {
    try {
      await navigator.clipboard.writeText(download.url);
    } catch {}
  };

  return (
    <div className="group relative flex items-start gap-4 rounded-lg border border-border bg-card p-4 transition-all hover:border-primary/30 hover:bg-card/80">
      <div className={`flex h-12 w-12 shrink-0 items-center justify-center rounded-lg ${statusInfo.bgColor}`}>
        <CategoryIcon className={`h-6 w-6 ${statusInfo.color}`} />
      </div>

      <div className="min-w-0 flex-1">
        <div className="grid grid-cols-[minmax(0,1fr)_auto] items-start gap-4">
          <div className="min-w-0">
            <h3 className="truncate text-sm font-medium text-foreground" title={download.filename}>
              {download.filename}
            </h3>
            <div className="mt-1 flex items-center gap-2 text-xs text-muted-foreground">
              <StatusIcon
                className={`h-3 w-3 ${download.status === 'downloading' ? 'animate-spin' : ''} ${statusInfo.color}`}
              />
              <span className={statusInfo.color}>{statusInfo.label}</span>
              <span className="text-border">|</span>
              <span>{formatTimeAgo(download.addedAt)}</span>
            </div>
            <p className="mt-2 truncate font-mono text-[11px] text-muted-foreground" title={download.outputPath}>
              {download.outputPath}
            </p>
          </div>

          <div className="flex shrink-0 items-center gap-1 self-start">
            {download.status === 'downloading' ? (
              <Button variant="ghost" size="icon" className="h-8 w-8" onClick={() => void onPause(download.id)}>
                <Pause className="h-4 w-4" />
              </Button>
            ) : null}
            {download.status === 'paused' || download.status === 'queued' ? (
              <Button variant="ghost" size="icon" className="h-8 w-8" onClick={() => void onResume(download.id)}>
                <Play className="h-4 w-4" />
              </Button>
            ) : null}
            {download.status === 'error' ? (
              <Button variant="ghost" size="icon" className="h-8 w-8" onClick={() => void onRetry(download.id)}>
                <RefreshCw className="h-4 w-4" />
              </Button>
            ) : null}

            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button variant="ghost" size="icon" className="h-8 w-8">
                  <MoreVertical className="h-4 w-4" />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end" className="w-48">
                {download.status === 'completed' ? (
                  <DropdownMenuItem onClick={() => void onOpenFile(download.outputPath)}>
                    <File className="mr-2 h-4 w-4" />
                    Open File
                  </DropdownMenuItem>
                ) : null}
                <DropdownMenuItem onClick={() => void onOpenFolder(download.outputPath)}>
                  <FolderOpen className="mr-2 h-4 w-4" />
                  Open Folder
                </DropdownMenuItem>
                <DropdownMenuItem onClick={() => void copyUrl()}>
                  <Copy className="mr-2 h-4 w-4" />
                  Copy URL
                </DropdownMenuItem>
                <DropdownMenuSeparator />
                <DropdownMenuItem variant="destructive" onClick={() => void onRemove(download.id)}>
                  <X className="mr-2 h-4 w-4" />
                  Delete
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        </div>

        {download.status !== 'completed' && download.status !== 'error' ? (
          <div className="mt-3">
            <div className="relative h-2 overflow-hidden rounded-full bg-secondary">
              <div
                className={`absolute inset-y-0 left-0 rounded-full transition-[width] duration-200 ease-out ${
                  download.status === 'downloading'
                    ? 'bg-primary'
                    : download.status === 'paused'
                      ? 'bg-warning'
                      : 'bg-muted-foreground'
                }`}
                style={{ width: `${download.progressPercent}%` }}
              />
            </div>
          </div>
        ) : null}

        <div className="mt-3 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs">
          {sizeLabel ? (
            <div className="font-mono text-muted-foreground" title={sizeLabel}>
              {sizeLabel}
            </div>
          ) : null}

          {sizeLabel ? <div className="h-3 w-px bg-border" /> : null}

          <div className="flex items-center gap-1.5 text-muted-foreground">
            <span className="font-mono">{download.progressPercent.toFixed(1)}%</span>
            <span className="text-border">complete</span>
          </div>

          {download.status === 'downloading' ? (
            <>
              <div className="h-3 w-px bg-border" />
              <div className="font-mono text-primary">{download.speedText ?? '--'}</div>
              <div className="h-3 w-px bg-border" />
              <div className="flex items-center gap-1.5 text-muted-foreground">
                <Clock className="h-3 w-3" />
                {download.etaText ?? '--'}
              </div>
              <div className="h-3 w-px bg-border" />
              <div className="flex items-center gap-1.5 text-muted-foreground">
                <Zap className="h-3 w-3" />
                {download.connections}/{download.maxConnections} connections
              </div>
            </>
          ) : null}

          {download.status === 'completed' ? (
            <div className="text-success">Saved to {download.savePath}</div>
          ) : null}

          {download.status === 'error' && download.error ? (
            <div className="text-destructive">{download.error}</div>
          ) : null}
        </div>
      </div>
    </div>
  );
}
