import { FileX } from '@/components/ui/icons';
import { ScrollArea } from '@/components/ui/scroll-area';
import { DownloadItem } from '@/components/download-manager/download-item';
import type { DownloadCard } from '@/lib/types';

interface DownloadListProps {
  downloads: DownloadCard[];
  onPause: (id: string) => Promise<void> | void;
  onResume: (id: string) => Promise<void> | void;
  onRemove: (id: string) => Promise<void> | void;
  onRetry: (id: string) => Promise<void> | void;
  onOpenFile: (path: string) => Promise<void> | void;
  onOpenFolder: (path: string) => Promise<void> | void;
}

export function DownloadList({
  downloads,
  onPause,
  onResume,
  onRemove,
  onRetry,
  onOpenFile,
  onOpenFolder
}: DownloadListProps) {
  if (!downloads.length) {
    return (
      <div className="flex flex-1 flex-col items-center justify-center p-8">
        <div className="flex h-16 w-16 items-center justify-center rounded-full bg-muted">
          <FileX className="h-8 w-8 text-muted-foreground" />
        </div>
        <h3 className="mt-4 text-lg font-medium text-foreground">No downloads</h3>
        <p className="mt-1 text-sm text-muted-foreground">Click “New Download” to start one.</p>
      </div>
    );
  }

  return (
    <ScrollArea className="flex-1">
      <div className="space-y-2 p-4">
        {downloads.map((download) => (
          <DownloadItem
            key={download.id}
            download={download}
            onPause={onPause}
            onResume={onResume}
            onRemove={onRemove}
            onRetry={onRetry}
            onOpenFile={onOpenFile}
            onOpenFolder={onOpenFolder}
          />
        ))}
      </div>
    </ScrollArea>
  );
}
