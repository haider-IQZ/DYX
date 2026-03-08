"use client"

import { Plus, Search } from "lucide-react"
import { useState } from "react"
import type { Download } from "@/hooks/use-dyx-downloads"
import { DownloadItem } from "./download-item"
import { Input } from "@/components/ui/input"
import { Button } from "@/components/ui/button"

type DownloadAreaProps = {
  downloads: Download[]
  onTogglePause: (id: string) => Promise<void> | void
  onRemove: (id: string) => Promise<void> | void
  onOpenFolder: (id: string) => Promise<void> | void
  onAddNew: () => void
}

export function DownloadArea({ downloads, onTogglePause, onRemove, onOpenFolder, onAddNew }: DownloadAreaProps) {
  const [searchQuery, setSearchQuery] = useState("")

  const filteredDownloads = downloads.filter((d) =>
    d.filename.toLowerCase().includes(searchQuery.toLowerCase())
  )

  return (
    <div className="flex-1 flex flex-col bg-background overflow-hidden">
      {/* Header */}
      <div className="h-14 border-b border-border flex items-center justify-between px-6 shrink-0">
        <div className="flex items-center gap-4">
          <h2 className="text-lg font-semibold text-foreground">Downloads</h2>
          <span className="text-sm text-muted-foreground">
            {filteredDownloads.length} {filteredDownloads.length === 1 ? "item" : "items"}
          </span>
        </div>

        <div className="flex items-center gap-3">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
            <Input
              type="text"
              placeholder="Search downloads..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-64 pl-9 h-9 bg-muted border-border"
            />
          </div>
          <Button onClick={onAddNew} size="sm" className="gap-2">
            <Plus className="w-4 h-4" />
            Add URL
          </Button>
        </div>
      </div>

      {/* Download List */}
      <div className="flex-1 overflow-y-auto p-4">
        {filteredDownloads.length === 0 ? (
          <div className="h-full flex flex-col items-center justify-center text-center">
            <div className="w-16 h-16 rounded-full bg-muted flex items-center justify-center mb-4">
              <Plus className="w-8 h-8 text-muted-foreground" />
            </div>
            <h3 className="text-lg font-medium text-foreground mb-2">No downloads yet</h3>
            <p className="text-sm text-muted-foreground mb-4">
              Click &quot;Add URL&quot; to start downloading files
            </p>
            <Button onClick={onAddNew} size="sm" className="gap-2">
              <Plus className="w-4 h-4" />
              Add your first download
            </Button>
          </div>
        ) : (
          <div className="space-y-2">
            {filteredDownloads.map((download) => (
              <DownloadItem
                key={download.id}
                download={download}
                onTogglePause={onTogglePause}
                onRemove={onRemove}
                onOpenFolder={onOpenFolder}
              />
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
