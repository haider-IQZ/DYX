'use client'

import { useState, useMemo, useEffect } from 'react'
import { useDownloads } from '@/lib/download-store'
import { Header } from './header'
import { Sidebar } from './sidebar'
import { DownloadList } from './download-list'
import { SettingsPanel } from './settings-panel'
import type { Download } from '@/lib/types'

export function DownloadManager() {
  const {
    downloads,
    settings,
    addDownload,
    removeDownload,
    pauseDownload,
    resumeDownload,
    retryDownload,
    pauseAll,
    resumeAll,
    clearCompleted,
    updateSettings
  } = useDownloads()

  const [activeFilter, setActiveFilter] = useState('all')
  const [settingsOpen, setSettingsOpen] = useState(false)
  const [animatedDownloads, setAnimatedDownloads] = useState(downloads)

  // Simulate download progress animation
  useEffect(() => {
    const interval = setInterval(() => {
      setAnimatedDownloads(prev => prev.map(download => {
        if (download.status !== 'downloading') return download

        const newDownloaded = Math.min(
          download.downloaded + download.speed * 0.1,
          download.size
        )

        // Simulate speed variation
        const speedVariation = 0.9 + Math.random() * 0.2
        const newSpeed = download.speed * speedVariation

        if (newDownloaded >= download.size) {
          return {
            ...download,
            downloaded: download.size,
            speed: 0,
            status: 'completed' as const,
            completedAt: new Date()
          }
        }

        return {
          ...download,
          downloaded: newDownloaded,
          speed: newSpeed
        }
      }))
    }, 100)

    return () => clearInterval(interval)
  }, [])

  // Sync with store downloads
  useEffect(() => {
    setAnimatedDownloads(downloads)
  }, [downloads])

  const filteredDownloads = useMemo(() => {
    if (activeFilter === 'all') return animatedDownloads
    
    if (activeFilter.startsWith('category:')) {
      const category = activeFilter.replace('category:', '')
      return animatedDownloads.filter(d => d.category === category)
    }
    
    return animatedDownloads.filter(d => d.status === activeFilter)
  }, [animatedDownloads, activeFilter])

  const activeCount = useMemo(
    () => animatedDownloads.filter(d => d.status === 'downloading').length,
    [animatedDownloads]
  )

  const totalSpeed = useMemo(
    () => animatedDownloads
      .filter(d => d.status === 'downloading')
      .reduce((sum, d) => sum + d.speed, 0),
    [animatedDownloads]
  )

  const totalDownloads = animatedDownloads.length
  const completedToday = useMemo(
    () => animatedDownloads.filter(d => {
      if (d.status !== 'completed' || !d.completedAt) return false
      const today = new Date()
      const completed = new Date(d.completedAt)
      return completed.toDateString() === today.toDateString()
    }).length,
    [animatedDownloads]
  )

  return (
    <div className="flex h-screen flex-col bg-background">
      <Header
        onAddDownload={addDownload}
        onPauseAll={pauseAll}
        onResumeAll={resumeAll}
        onClearCompleted={clearCompleted}
        onOpenSettings={() => setSettingsOpen(true)}
        activeCount={activeCount}
        totalSpeed={totalSpeed}
        totalDownloads={totalDownloads}
        completedToday={completedToday}
      />

      <div className="flex flex-1 overflow-hidden">
        <Sidebar
          downloads={animatedDownloads}
          activeFilter={activeFilter}
          onFilterChange={setActiveFilter}
        />

        <main className="flex flex-1 flex-col overflow-hidden">
          {/* Toolbar */}
          <div className="flex items-center justify-between border-b border-border px-4 py-3">
            <div className="text-sm text-muted-foreground">
              Showing <span className="font-medium text-foreground">{filteredDownloads.length}</span> downloads
            </div>
          </div>

          <DownloadList
            downloads={filteredDownloads}
            onPause={pauseDownload}
            onResume={resumeDownload}
            onRemove={removeDownload}
            onRetry={retryDownload}
          />
        </main>
      </div>

      <SettingsPanel
        open={settingsOpen}
        onOpenChange={setSettingsOpen}
        settings={settings}
        onUpdateSettings={updateSettings}
      />
    </div>
  )
}
