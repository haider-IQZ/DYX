"use client"

import { 
  Download, 
  CheckCircle2, 
  Clock, 
  Pause,
  Archive, 
  Video, 
  Music, 
  FileText,
  Activity,
  HardDrive,
  ArrowDown
} from "lucide-react"
import { cn } from "@/lib/utils"

type SidebarProps = {
  activeFilter: string
  onFilterChange: (filter: string) => void
  stats: {
    active: number
    total: number
    downloadSpeed: number
  }
}

const formatSpeed = (bytes: number) => {
  if (bytes >= 1000000) return `${(bytes / 1000000).toFixed(1)} MB/s`
  if (bytes >= 1000) return `${(bytes / 1000).toFixed(1)} KB/s`
  return `${bytes} B/s`
}

const navItems = [
  { id: "all", label: "All Downloads", icon: Download },
  { id: "downloading", label: "Downloading", icon: Activity },
  { id: "completed", label: "Completed", icon: CheckCircle2 },
  { id: "queued", label: "Queued", icon: Clock },
]

const categoryItems = [
  { id: "archives", label: "Archives", icon: Archive },
  { id: "videos", label: "Videos", icon: Video },
  { id: "audio", label: "Audio", icon: Music },
  { id: "documents", label: "Documents", icon: FileText },
]

export function Sidebar({ activeFilter, onFilterChange, stats }: SidebarProps) {
  return (
    <div className="w-56 bg-card border-r border-border flex flex-col shrink-0">
      {/* Stats Section */}
      <div className="p-4 border-b border-border">
        <div className="bg-muted/50 rounded-xl p-4 space-y-3">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-lg bg-primary/20 flex items-center justify-center">
              <Activity className="w-4 h-4 text-primary" />
            </div>
            <div>
              <p className="text-xs text-muted-foreground">Active</p>
              <p className="text-sm font-semibold text-foreground">{stats.active} downloads</p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-lg bg-green-500/20 flex items-center justify-center">
              <HardDrive className="w-4 h-4 text-green-400" />
            </div>
            <div>
              <p className="text-xs text-muted-foreground">Total</p>
              <p className="text-sm font-semibold text-foreground">{stats.total} files</p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-lg bg-blue-500/20 flex items-center justify-center">
              <ArrowDown className="w-4 h-4 text-blue-400" />
            </div>
            <div>
              <p className="text-xs text-muted-foreground">Speed</p>
              <p className="text-sm font-semibold text-foreground">{formatSpeed(stats.downloadSpeed)}</p>
            </div>
          </div>
        </div>
      </div>

      {/* Navigation */}
      <div className="flex-1 overflow-y-auto p-3">
        <div className="space-y-1">
          <p className="text-xs font-medium text-muted-foreground px-3 py-2 uppercase tracking-wider">Status</p>
          {navItems.map((item) => (
            <button
              key={item.id}
              onClick={() => onFilterChange(item.id)}
              className={cn(
                "w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm transition-all",
                activeFilter === item.id
                  ? "bg-primary/20 text-primary"
                  : "text-muted-foreground hover:bg-muted hover:text-foreground"
              )}
            >
              <item.icon className="w-4 h-4" />
              <span>{item.label}</span>
            </button>
          ))}
        </div>

        <div className="mt-6 space-y-1">
          <p className="text-xs font-medium text-muted-foreground px-3 py-2 uppercase tracking-wider">Categories</p>
          {categoryItems.map((item) => (
            <button
              key={item.id}
              onClick={() => onFilterChange(item.id)}
              className={cn(
                "w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm transition-all",
                activeFilter === item.id
                  ? "bg-primary/20 text-primary"
                  : "text-muted-foreground hover:bg-muted hover:text-foreground"
              )}
            >
              <item.icon className="w-4 h-4" />
              <span>{item.label}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Footer */}
      <div className="p-4 border-t border-border">
        <div className="text-center">
          <p className="text-xs text-muted-foreground">Powered by</p>
          <p className="text-sm font-medium text-foreground">axel</p>
        </div>
      </div>
    </div>
  )
}
