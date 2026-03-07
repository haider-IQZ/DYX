'use client'

import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Switch } from '@/components/ui/switch'
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from '@/components/ui/sheet'
import { Separator } from '@/components/ui/separator'
import { cn } from '@/lib/utils'
import { 
  FolderOpen, 
  Rocket, 
  Gauge, 
  Snail, 
  Layers,
  ShieldCheck,
  RefreshCw,
  Infinity
} from 'lucide-react'
import type { DownloadSettings, SpeedMode } from '@/lib/types'

interface SettingsPanelProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  settings: DownloadSettings
  onUpdateSettings: (settings: Partial<DownloadSettings>) => void
}

const speedModes: { id: SpeedMode; label: string; description: string; icon: typeof Rocket }[] = [
  { 
    id: 'maximum', 
    label: 'Maximum', 
    description: 'Use all available bandwidth',
    icon: Rocket 
  },
  { 
    id: 'decent', 
    label: 'Balanced', 
    description: 'Good speed, allows browsing',
    icon: Gauge 
  },
  { 
    id: 'slow', 
    label: 'Slow', 
    description: 'Minimal bandwidth usage',
    icon: Snail 
  },
]

const concurrentOptions: (number | 'unlimited')[] = [1, 2, 3, 5, 'unlimited']

export function SettingsPanel({
  open,
  onOpenChange,
  settings,
  onUpdateSettings
}: SettingsPanelProps) {
  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent className="w-full sm:max-w-md">
        <SheetHeader>
          <SheetTitle>Settings</SheetTitle>
          <SheetDescription>
            Configure your download preferences
          </SheetDescription>
        </SheetHeader>

        <div className="mt-6 space-y-6">
          {/* Speed Mode */}
          <div className="space-y-3">
            <Label className="text-sm font-medium">Download Speed</Label>
            <div className="grid gap-2">
              {speedModes.map((mode) => {
                const isActive = settings.speedMode === mode.id
                const Icon = mode.icon
                return (
                  <button
                    key={mode.id}
                    onClick={() => onUpdateSettings({ speedMode: mode.id })}
                    className={cn(
                      'flex items-center gap-4 rounded-lg border p-4 text-left transition-all',
                      isActive 
                        ? 'border-primary bg-primary/5 ring-1 ring-primary' 
                        : 'border-border bg-card hover:border-muted-foreground/50'
                    )}
                  >
                    <div className={cn(
                      'flex h-10 w-10 items-center justify-center rounded-lg',
                      isActive ? 'bg-primary/10' : 'bg-muted'
                    )}>
                      <Icon className={cn(
                        'h-5 w-5',
                        isActive ? 'text-primary' : 'text-muted-foreground'
                      )} />
                    </div>
                    <div className="flex-1">
                      <p className={cn(
                        'font-medium',
                        isActive ? 'text-foreground' : 'text-foreground'
                      )}>
                        {mode.label}
                      </p>
                      <p className="text-xs text-muted-foreground">
                        {mode.description}
                      </p>
                    </div>
                    <div className={cn(
                      'h-4 w-4 rounded-full border-2 transition-colors',
                      isActive 
                        ? 'border-primary bg-primary' 
                        : 'border-muted-foreground/30'
                    )}>
                      {isActive && (
                        <div className="flex h-full w-full items-center justify-center">
                          <div className="h-1.5 w-1.5 rounded-full bg-primary-foreground" />
                        </div>
                      )}
                    </div>
                  </button>
                )
              })}
            </div>
          </div>

          <Separator />

          {/* Concurrent Downloads */}
          <div className="space-y-3">
            <div className="flex items-center gap-2">
              <Layers className="h-4 w-4 text-muted-foreground" />
              <Label className="text-sm font-medium">Downloads at a time</Label>
            </div>
            <div className="flex gap-2">
              {concurrentOptions.map((option) => {
                const isUnlimited = option === 'unlimited'
                const isActive = settings.maxConcurrentDownloads === option
                return (
                  <button
                    key={String(option)}
                    onClick={() => onUpdateSettings({ maxConcurrentDownloads: option })}
                    className={cn(
                      'flex h-11 items-center justify-center rounded-lg border font-mono text-sm font-medium transition-all',
                      isUnlimited ? 'w-14 px-2' : 'w-11',
                      isActive
                        ? 'border-primary bg-primary text-primary-foreground'
                        : 'border-border bg-card text-foreground hover:border-muted-foreground/50'
                    )}
                  >
                    {isUnlimited ? <Infinity className="h-4 w-4" /> : option}
                  </button>
                )
              })}
            </div>
            <p className="text-xs text-muted-foreground">
              How many files to download simultaneously
            </p>
          </div>

          <Separator />

          {/* Toggle Options */}
          <div className="space-y-3">
            {/* Speed Limit Toggle */}
            <div className="flex items-center justify-between rounded-lg border border-border bg-card p-4">
              <div className="flex items-center gap-3">
                <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-muted">
                  <ShieldCheck className="h-5 w-5 text-muted-foreground" />
                </div>
                <div>
                  <Label className="text-sm font-medium">Speed Limit</Label>
                  <p className="text-xs text-muted-foreground">
                    Cap bandwidth based on speed mode
                  </p>
                </div>
              </div>
              <Switch
                checked={settings.enableSpeedLimit}
                onCheckedChange={(checked) => onUpdateSettings({ enableSpeedLimit: checked })}
              />
            </div>

            {/* Auto Retry Toggle */}
            <div className="flex items-center justify-between rounded-lg border border-border bg-card p-4">
              <div className="flex items-center gap-3">
                <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-muted">
                  <RefreshCw className="h-5 w-5 text-muted-foreground" />
                </div>
                <div>
                  <Label className="text-sm font-medium">Auto Retry</Label>
                  <p className="text-xs text-muted-foreground">
                    Automatically retry failed downloads
                  </p>
                </div>
              </div>
              <Switch
                checked={settings.autoRetryOnFail}
                onCheckedChange={(checked) => onUpdateSettings({ autoRetryOnFail: checked })}
              />
            </div>
          </div>

          <Separator />

          {/* Download Directory */}
          <div className="space-y-3">
            <div className="flex items-center gap-2">
              <FolderOpen className="h-4 w-4 text-muted-foreground" />
              <Label className="text-sm font-medium">Download Directory</Label>
            </div>
            <div className="flex gap-2">
              <Input
                value={settings.defaultSavePath}
                onChange={(e) => onUpdateSettings({ defaultSavePath: e.target.value })}
                className="font-mono text-sm"
                placeholder="/home/user/Downloads"
              />
              <Button variant="outline" size="icon" className="shrink-0">
                <FolderOpen className="h-4 w-4" />
              </Button>
            </div>
            <p className="text-xs text-muted-foreground">
              Where downloaded files will be saved
            </p>
          </div>

          {/* Axel Info */}
          <div className="mt-4 rounded-lg bg-muted/50 p-4">
            <div className="flex items-center justify-between text-xs">
              <span className="text-muted-foreground">Powered by Axel</span>
              <span className="font-mono text-foreground">v2.17.14</span>
            </div>
          </div>
        </div>
      </SheetContent>
    </Sheet>
  )
}
