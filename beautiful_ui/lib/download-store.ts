'use client'

import { useState, useCallback } from 'react'
import type { Download, DownloadStatus, FileCategory, DownloadSettings } from './types'

// Simulate file category detection
function detectCategory(filename: string): FileCategory {
  const ext = filename.split('.').pop()?.toLowerCase() || ''
  
  if (['mp4', 'mkv', 'avi', 'mov', 'webm', 'flv'].includes(ext)) return 'video'
  if (['mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a'].includes(ext)) return 'audio'
  if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'bmp'].includes(ext)) return 'image'
  if (['pdf', 'doc', 'docx', 'txt', 'xlsx', 'pptx', 'csv'].includes(ext)) return 'document'
  if (['zip', 'rar', '7z', 'tar', 'gz', 'bz2'].includes(ext)) return 'archive'
  
  return 'other'
}

// Generate mock downloads for demo
function generateMockDownloads(): Download[] {
  return [
    {
      id: '1',
      filename: 'ubuntu-24.04-desktop-amd64.iso',
      url: 'https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso',
      size: 5.2 * 1024 * 1024 * 1024,
      downloaded: 2.8 * 1024 * 1024 * 1024,
      speed: 45.2 * 1024 * 1024,
      status: 'downloading',
      category: 'archive',
      connections: 16,
      maxConnections: 16,
      addedAt: new Date(Date.now() - 1000 * 60 * 15),
      savePath: '/home/user/Downloads'
    },
    {
      id: '2',
      filename: 'Blade.Runner.2049.2017.2160p.UHD.BluRay.mkv',
      url: 'https://example.com/movie.mkv',
      size: 65 * 1024 * 1024 * 1024,
      downloaded: 12 * 1024 * 1024 * 1024,
      speed: 28.5 * 1024 * 1024,
      status: 'downloading',
      category: 'video',
      connections: 32,
      maxConnections: 32,
      addedAt: new Date(Date.now() - 1000 * 60 * 45),
      savePath: '/home/user/Videos'
    },
    {
      id: '3',
      filename: 'VS.Code.Setup.1.95.exe',
      url: 'https://code.visualstudio.com/download',
      size: 95 * 1024 * 1024,
      downloaded: 95 * 1024 * 1024,
      speed: 0,
      status: 'completed',
      category: 'other',
      connections: 8,
      maxConnections: 8,
      addedAt: new Date(Date.now() - 1000 * 60 * 60),
      completedAt: new Date(Date.now() - 1000 * 60 * 55),
      savePath: '/home/user/Downloads'
    },
    {
      id: '4',
      filename: 'arch-linux-2024.01.01-x86_64.iso',
      url: 'https://archlinux.org/download/',
      size: 850 * 1024 * 1024,
      downloaded: 340 * 1024 * 1024,
      speed: 0,
      status: 'paused',
      category: 'archive',
      connections: 16,
      maxConnections: 16,
      addedAt: new Date(Date.now() - 1000 * 60 * 30),
      savePath: '/home/user/ISOs'
    },
    {
      id: '5',
      filename: 'project-assets.zip',
      url: 'https://github.com/project/assets.zip',
      size: 2.1 * 1024 * 1024 * 1024,
      downloaded: 0,
      speed: 0,
      status: 'queued',
      category: 'archive',
      connections: 16,
      maxConnections: 16,
      addedAt: new Date(Date.now() - 1000 * 60 * 5),
      savePath: '/home/user/Downloads'
    },
    {
      id: '6',
      filename: 'documentation.pdf',
      url: 'https://example.com/docs.pdf',
      size: 15 * 1024 * 1024,
      downloaded: 8 * 1024 * 1024,
      speed: 0,
      status: 'error',
      category: 'document',
      connections: 4,
      maxConnections: 4,
      addedAt: new Date(Date.now() - 1000 * 60 * 20),
      error: 'Connection refused by server',
      savePath: '/home/user/Documents'
    }
  ]
}

export function useDownloads() {
  const [downloads, setDownloads] = useState<Download[]>(generateMockDownloads)
  const [settings, setSettings] = useState<DownloadSettings>({
    speedMode: 'maximum',
    maxConcurrentDownloads: 3,
    enableSpeedLimit: false,
    autoRetryOnFail: true,
    defaultSavePath: '/home/user/Downloads'
  })

  const addDownload = useCallback((url: string, filename?: string) => {
    const name = filename || url.split('/').pop() || 'download'
    // Connection count based on speed mode
    const connectionsByMode = { maximum: 32, decent: 16, slow: 4 }
    const connections = connectionsByMode[settings.speedMode]
    
    const newDownload: Download = {
      id: crypto.randomUUID(),
      filename: name,
      url,
      size: Math.random() * 5 * 1024 * 1024 * 1024,
      downloaded: 0,
      speed: 0,
      status: 'downloading',
      category: detectCategory(name),
      connections,
      maxConnections: connections,
      addedAt: new Date(),
      savePath: settings.defaultSavePath
    }
    setDownloads(prev => [newDownload, ...prev])
    return newDownload.id
  }, [settings])

  const updateStatus = useCallback((id: string, status: DownloadStatus) => {
    setDownloads(prev => prev.map(d => 
      d.id === id ? { ...d, status, speed: status === 'paused' ? 0 : d.speed } : d
    ))
  }, [])

  const removeDownload = useCallback((id: string) => {
    setDownloads(prev => prev.filter(d => d.id !== id))
  }, [])

  const pauseDownload = useCallback((id: string) => {
    updateStatus(id, 'paused')
  }, [updateStatus])

  const resumeDownload = useCallback((id: string) => {
    updateStatus(id, 'downloading')
  }, [updateStatus])

  const retryDownload = useCallback((id: string) => {
    setDownloads(prev => prev.map(d => 
      d.id === id ? { ...d, status: 'downloading', error: undefined, downloaded: 0 } : d
    ))
  }, [])

  const pauseAll = useCallback(() => {
    setDownloads(prev => prev.map(d => 
      d.status === 'downloading' ? { ...d, status: 'paused', speed: 0 } : d
    ))
  }, [])

  const resumeAll = useCallback(() => {
    setDownloads(prev => prev.map(d => 
      d.status === 'paused' ? { ...d, status: 'downloading' } : d
    ))
  }, [])

  const clearCompleted = useCallback(() => {
    setDownloads(prev => prev.filter(d => d.status !== 'completed'))
  }, [])

  const updateSettings = useCallback((newSettings: Partial<DownloadSettings>) => {
    setSettings(prev => ({ ...prev, ...newSettings }))
  }, [])

  return {
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
  }
}
