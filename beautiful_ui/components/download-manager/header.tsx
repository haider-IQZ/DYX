'use client'

import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog'
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from '@/components/ui/tooltip'
import { Label } from '@/components/ui/label'
import {
  Download,
  Plus,
  Settings,
  Pause,
  Play,
  Trash2,
  Activity,
  ArrowDownToLine,
  Gauge,
  Layers
} from 'lucide-react'

interface HeaderProps {
  onAddDownload: (url: string, filename?: string) => void
  onPauseAll: () => void
  onResumeAll: () => void
  onClearCompleted: () => void
  onOpenSettings: () => void
  activeCount: number
  totalSpeed: number
  totalDownloads?: number
  completedToday?: number
}

function formatSpeed(bytesPerSecond: number): string {
  if (bytesPerSecond === 0) return '0 B/s'
  const units = ['B/s', 'KB/s', 'MB/s', 'GB/s']
  const k = 1024
  const i = Math.floor(Math.log(bytesPerSecond) / Math.log(k))
  return `${(bytesPerSecond / Math.pow(k, i)).toFixed(1)} ${units[i]}`
}

export function Header({
  onAddDownload,
  onPauseAll,
  onResumeAll,
  onClearCompleted,
  onOpenSettings,
  activeCount,
  totalSpeed,
  totalDownloads = 0,
  completedToday = 0
}: HeaderProps) {
  const [dialogOpen, setDialogOpen] = useState(false)
  const [url, setUrl] = useState('')
  const [filename, setFilename] = useState('')

  const handleAddDownload = () => {
    if (url.trim()) {
      onAddDownload(url.trim(), filename.trim() || undefined)
      setUrl('')
      setFilename('')
      setDialogOpen(false)
    }
  }

  return (
    <TooltipProvider delayDuration={0}>
      <header className="border-b border-border bg-card/50 backdrop-blur-sm">
        {/* Top Bar - Branding & Actions */}
        <div className="flex items-center justify-between px-5 py-3">
          {/* Logo & Branding */}
          <div className="flex items-center gap-4">
            <div className="relative">
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/10 ring-1 ring-primary/20">
                <ArrowDownToLine className="h-5 w-5 text-primary" />
              </div>
              {activeCount > 0 && (
                <span className="absolute -right-1 -top-1 flex h-4 w-4 items-center justify-center rounded-full bg-primary text-[10px] font-bold text-primary-foreground">
                  {activeCount > 9 ? '9+' : activeCount}
                </span>
              )}
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h1 className="text-base font-semibold tracking-tight text-foreground">Axel</h1>
                <span className="rounded bg-primary/10 px-1.5 py-0.5 text-[10px] font-medium uppercase tracking-wider text-primary">
                  Pro
                </span>
              </div>
              <p className="text-xs text-muted-foreground">Multi-threaded Download Accelerator</p>
            </div>
          </div>

          {/* Actions */}
          <div className="flex items-center gap-1">
            <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
              <DialogTrigger asChild>
                <Button size="sm" className="gap-2 rounded-lg px-4">
                  <Plus className="h-4 w-4" />
                  <span className="hidden sm:inline">New Download</span>
                </Button>
              </DialogTrigger>
              <DialogContent className="sm:max-w-lg">
                <DialogHeader>
                  <DialogTitle>Add Download</DialogTitle>
                  <DialogDescription>
                    Enter a URL to download. Axel will automatically use multiple connections for faster speeds.
                  </DialogDescription>
                </DialogHeader>
                <div className="grid gap-4 py-4">
                  <div className="grid gap-2">
                    <Label htmlFor="url">URL</Label>
                    <Input
                      id="url"
                      placeholder="https://example.com/file.zip"
                      value={url}
                      onChange={(e) => setUrl(e.target.value)}
                      onKeyDown={(e) => e.key === 'Enter' && handleAddDownload()}
                      className="font-mono text-sm"
                    />
                  </div>
                  <div className="grid gap-2">
                    <Label htmlFor="filename">Filename (optional)</Label>
                    <Input
                      id="filename"
                      placeholder="Auto-detect from URL"
                      value={filename}
                      onChange={(e) => setFilename(e.target.value)}
                    />
                  </div>
                </div>
                <DialogFooter>
                  <Button variant="outline" onClick={() => setDialogOpen(false)}>
                    Cancel
                  </Button>
                  <Button onClick={handleAddDownload} disabled={!url.trim()}>
                    <Download className="mr-2 h-4 w-4" />
                    Start Download
                  </Button>
                </DialogFooter>
              </DialogContent>
            </Dialog>

            <div className="mx-2 h-6 w-px bg-border" />

            <Tooltip>
              <TooltipTrigger asChild>
                <Button variant="ghost" size="icon" onClick={onPauseAll} className="h-8 w-8">
                  <Pause className="h-4 w-4" />
                </Button>
              </TooltipTrigger>
              <TooltipContent>Pause All</TooltipContent>
            </Tooltip>

            <Tooltip>
              <TooltipTrigger asChild>
                <Button variant="ghost" size="icon" onClick={onResumeAll} className="h-8 w-8">
                  <Play className="h-4 w-4" />
                </Button>
              </TooltipTrigger>
              <TooltipContent>Resume All</TooltipContent>
            </Tooltip>

            <Tooltip>
              <TooltipTrigger asChild>
                <Button variant="ghost" size="icon" onClick={onClearCompleted} className="h-8 w-8">
                  <Trash2 className="h-4 w-4" />
                </Button>
              </TooltipTrigger>
              <TooltipContent>Clear Completed</TooltipContent>
            </Tooltip>

            <div className="mx-1 h-6 w-px bg-border" />

            <Tooltip>
              <TooltipTrigger asChild>
                <Button variant="ghost" size="icon" onClick={onOpenSettings} className="h-8 w-8">
                  <Settings className="h-4 w-4" />
                </Button>
              </TooltipTrigger>
              <TooltipContent>Settings</TooltipContent>
            </Tooltip>
          </div>
        </div>

        {/* Stats Bar */}
        <div className="grid grid-cols-2 gap-px border-t border-border bg-border md:grid-cols-4">
          {/* Active Downloads */}
          <div className="flex items-center gap-3 bg-card/80 px-5 py-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-primary/10">
              <Activity className="h-4 w-4 text-primary" />
            </div>
            <div>
              <p className="text-xs text-muted-foreground">Active</p>
              <p className="font-mono text-lg font-semibold tabular-nums text-foreground">
                {activeCount}
              </p>
            </div>
          </div>

          {/* Current Speed */}
          <div className="flex items-center gap-3 bg-card/80 px-5 py-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-chart-2/10">
              <Gauge className="h-4 w-4 text-chart-2" />
            </div>
            <div>
              <p className="text-xs text-muted-foreground">Speed</p>
              <p className="font-mono text-lg font-semibold tabular-nums text-foreground">
                {formatSpeed(totalSpeed)}
              </p>
            </div>
          </div>

          {/* Total Downloads */}
          <div className="hidden items-center gap-3 bg-card/80 px-5 py-3 md:flex">
            <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-chart-3/10">
              <Layers className="h-4 w-4 text-chart-3" />
            </div>
            <div>
              <p className="text-xs text-muted-foreground">Total</p>
              <p className="font-mono text-lg font-semibold tabular-nums text-foreground">
                {totalDownloads}
              </p>
            </div>
          </div>

          {/* Completed Today */}
          <div className="hidden items-center gap-3 bg-card/80 px-5 py-3 md:flex">
            <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-success/10">
              <Download className="h-4 w-4 text-success" />
            </div>
            <div>
              <p className="text-xs text-muted-foreground">Completed</p>
              <p className="font-mono text-lg font-semibold tabular-nums text-foreground">
                {completedToday}
              </p>
            </div>
          </div>
        </div>
      </header>
    </TooltipProvider>
  )
}
