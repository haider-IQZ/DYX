import {
  AlertCircle,
  CheckCircle2,
  Clock,
  Download,
  File,
  FileArchive,
  FileAudio,
  FileImage,
  FileText,
  FileVideo,
  HardDrive,
  LayoutGrid,
  Pause
} from '@/components/ui/icons';
import { cn } from '@/lib/utils';
import type { DownloadCard } from '@/lib/types';

interface SidebarProps {
  downloads: DownloadCard[];
  activeFilter: string;
  onFilterChange: (filter: string) => void;
}

const statusFilters = [
  { id: 'all', label: 'All Downloads', icon: LayoutGrid, color: 'text-foreground' },
  { id: 'downloading', label: 'Downloading', icon: Download, color: 'text-primary' },
  { id: 'paused', label: 'Paused', icon: Pause, color: 'text-warning' },
  { id: 'completed', label: 'Completed', icon: CheckCircle2, color: 'text-success' },
  { id: 'queued', label: 'Queued', icon: Clock, color: 'text-muted-foreground' },
  { id: 'error', label: 'Failed', icon: AlertCircle, color: 'text-destructive' }
];

const categoryFilters = [
  { id: 'video', label: 'Videos', icon: FileVideo },
  { id: 'audio', label: 'Audio', icon: FileAudio },
  { id: 'image', label: 'Images', icon: FileImage },
  { id: 'document', label: 'Documents', icon: FileText },
  { id: 'archive', label: 'Archives', icon: FileArchive },
  { id: 'other', label: 'Other', icon: File }
];

export function Sidebar({ downloads, activeFilter, onFilterChange }: SidebarProps) {
  const completedCount = downloads.filter((item) => item.status === 'completed').length;
  const progressTotal = downloads.reduce((sum, item) => sum + item.progressPercent, 0);
  const averageProgress = downloads.length ? progressTotal / downloads.length : 0;

  return (
    <aside className="w-60 shrink-0 border-r border-border bg-sidebar/50">
      <div className="flex h-full flex-col">
        <div className="flex-1 overflow-y-auto py-4">
          <div className="px-3">
            <h2 className="mb-3 px-3 text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
              Status
            </h2>
            <nav className="space-y-1">
              {statusFilters.map((filter) => {
                const count =
                  filter.id === 'all'
                    ? downloads.length
                    : downloads.filter((item) => item.status === filter.id).length;
                const isActive = activeFilter === filter.id;
                const Icon = filter.icon;

                return (
                  <button
                    key={filter.id}
                    onClick={() => onFilterChange(filter.id)}
                    className={cn(
                      'group flex w-full items-center justify-between rounded-lg px-3 py-2 text-sm transition-all',
                      isActive
                        ? 'bg-primary/10 text-foreground'
                        : 'text-muted-foreground hover:bg-muted hover:text-foreground'
                    )}
                  >
                    <div className="flex items-center gap-3">
                      <div
                        className={cn(
                          'flex h-7 w-7 items-center justify-center rounded-md transition-colors',
                          isActive ? 'bg-primary/20' : 'bg-muted group-hover:bg-muted'
                        )}
                      >
                        <Icon className={cn('h-3.5 w-3.5', isActive ? filter.color : '')} />
                      </div>
                      <span className="font-medium">{filter.label}</span>
                    </div>
                    {count > 0 ? (
                      <span
                        className={cn(
                          'min-w-[24px] rounded-full px-2 py-0.5 text-center font-mono text-xs',
                          isActive ? 'bg-primary/20 text-primary' : 'bg-muted text-muted-foreground'
                        )}
                      >
                        {count}
                      </span>
                    ) : null}
                  </button>
                );
              })}
            </nav>
          </div>

          <div className="mt-6 px-3">
            <h2 className="mb-3 px-3 text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
              Categories
            </h2>
            <nav className="space-y-1">
              {categoryFilters.map((filter) => {
                const count = downloads.filter((item) => item.category === filter.id).length;
                if (!count) return null;
                const isActive = activeFilter === `category:${filter.id}`;
                const Icon = filter.icon;

                return (
                  <button
                    key={filter.id}
                    onClick={() => onFilterChange(`category:${filter.id}`)}
                    className={cn(
                      'group flex w-full items-center justify-between rounded-lg px-3 py-2 text-sm transition-all',
                      isActive
                        ? 'bg-primary/10 text-foreground'
                        : 'text-muted-foreground hover:bg-muted hover:text-foreground'
                    )}
                  >
                    <div className="flex items-center gap-3">
                      <div
                        className={cn(
                          'flex h-7 w-7 items-center justify-center rounded-md transition-colors',
                          isActive ? 'bg-primary/20' : 'bg-muted group-hover:bg-muted'
                        )}
                      >
                        <Icon className="h-3.5 w-3.5" />
                      </div>
                      <span className="font-medium">{filter.label}</span>
                    </div>
                    <span
                      className={cn(
                        'min-w-[24px] rounded-full px-2 py-0.5 text-center font-mono text-xs',
                        isActive ? 'bg-primary/20 text-primary' : 'bg-muted text-muted-foreground'
                      )}
                    >
                      {count}
                    </span>
                  </button>
                );
              })}
            </nav>
          </div>
        </div>

        <div className="border-t border-border p-4">
          <div className="rounded-lg bg-muted/50 p-3">
            <div className="mb-2 flex items-center gap-2">
              <HardDrive className="h-4 w-4 text-muted-foreground" />
              <span className="text-xs font-medium text-foreground">Progress</span>
            </div>
            <div className="mb-2 h-1.5 overflow-hidden rounded-full bg-muted">
              <div
                className="h-full rounded-full bg-primary transition-all duration-300"
                style={{ width: `${averageProgress}%` }}
              />
            </div>
            <div className="flex justify-between text-[11px] text-muted-foreground">
              <span>{completedCount} done</span>
              <span>{downloads.length} total</span>
            </div>
          </div>
        </div>
      </div>
    </aside>
  );
}
