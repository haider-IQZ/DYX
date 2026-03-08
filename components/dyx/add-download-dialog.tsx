"use client"

import { useEffect, useState } from "react"
import { FolderOpen, Link2, Zap } from "lucide-react"
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Button } from "@/components/ui/button"
import { Label } from "@/components/ui/label"
import { Slider } from "@/components/ui/slider"

type AddDownloadDialogProps = {
  open: boolean
  onOpenChange: (open: boolean) => void
  onAdd: (url: string, connections: number, savePath: string) => void
  defaultSavePath: string
}

export function AddDownloadDialog({ open, onOpenChange, onAdd, defaultSavePath }: AddDownloadDialogProps) {
  const [url, setUrl] = useState("")
  const [savePath, setSavePath] = useState(defaultSavePath)
  const [connections, setConnections] = useState([8])

  useEffect(() => {
    setSavePath(defaultSavePath)
  }, [defaultSavePath])

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (url.trim()) {
      onAdd(url.trim(), connections[0], savePath)
      setUrl("")
      onOpenChange(false)
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg bg-card border-border">
        <DialogHeader>
          <DialogTitle className="text-xl font-semibold text-foreground">
            Add New Download
          </DialogTitle>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-6 mt-4">
          {/* URL Input */}
          <div className="space-y-2">
            <Label htmlFor="url" className="text-sm font-medium text-foreground">
              Download URL
            </Label>
            <div className="relative">
              <Link2 className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
              <Input
                id="url"
                type="url"
                placeholder="https://example.com/file.zip"
                value={url}
                onChange={(e) => setUrl(e.target.value)}
                className="pl-10 bg-muted border-border"
                autoFocus
              />
            </div>
          </div>

          {/* Save Location */}
          <div className="space-y-2">
            <Label htmlFor="path" className="text-sm font-medium text-foreground">
              Save Location
            </Label>
            <div className="flex gap-2">
              <div className="relative flex-1">
                <FolderOpen className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                <Input
                  id="path"
                  type="text"
                  value={savePath}
                  onChange={(e) => setSavePath(e.target.value)}
                  className="pl-10 bg-muted border-border"
                />
              </div>
              <Button type="button" variant="secondary" size="icon">
                <FolderOpen className="w-4 h-4" />
              </Button>
            </div>
          </div>

          {/* Connections Slider */}
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <Label className="text-sm font-medium text-foreground flex items-center gap-2">
                <Zap className="w-4 h-4 text-primary" />
                Connections
              </Label>
              <span className="text-sm font-semibold text-primary">
                {connections[0]} parallel connections
              </span>
            </div>
            <Slider
              value={connections}
              onValueChange={setConnections}
              min={1}
              max={32}
              step={1}
              className="w-full"
            />
            <div className="flex justify-between text-xs text-muted-foreground">
              <span>1 (Slower)</span>
              <span>32 (Faster)</span>
            </div>
          </div>

          {/* Info Box */}
          <div className="bg-muted/50 rounded-lg p-4 border border-border">
            <p className="text-xs text-muted-foreground">
              DYX uses <span className="text-foreground font-medium">axel</span> under the hood 
              for multi-connection accelerated downloads. More connections can speed up downloads 
              from servers that support it.
            </p>
          </div>

          {/* Actions */}
          <div className="flex justify-end gap-3">
            <Button type="button" variant="ghost" onClick={() => onOpenChange(false)}>
              Cancel
            </Button>
            <Button type="submit" disabled={!url.trim()}>
              Start Download
            </Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  )
}
