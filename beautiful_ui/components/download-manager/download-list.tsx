'use client'

import { ScrollArea } from '@/components/ui/scroll-area'
import { DownloadItem } from './download-item'
import { FileX } from 'lucide-react'
import type { Download } from '@/lib/types'

interface DownloadListProps {
  downloads: Download[]
  onPause: (id: string) => void
  onResume: (id: string) => void
  onRemove: (id: string) => void
  onRetry: (id: string) => void
}

export function DownloadList({
  downloads,
  onPause,
  onResume,
  onRemove,
  onRetry
}: DownloadListProps) {
  if (downloads.length === 0) {
    return (
      <div className="flex flex-1 flex-col items-center justify-center p-8">
        <div className="flex h-16 w-16 items-center justify-center rounded-full bg-muted">
          <FileX className="h-8 w-8 text-muted-foreground" />
        </div>
        <h3 className="mt-4 text-lg font-medium text-foreground">No downloads</h3>
        <p className="mt-1 text-sm text-muted-foreground">
          Click the &quot;Add URL&quot; button to start a new download
        </p>
      </div>
    )
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
          />
        ))}
      </div>
    </ScrollArea>
  )
}
