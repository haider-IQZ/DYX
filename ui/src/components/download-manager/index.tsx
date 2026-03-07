import { useMemo, useState } from 'react';
import { Header } from '@/components/download-manager/header';
import { Sidebar } from '@/components/download-manager/sidebar';
import { DownloadList } from '@/components/download-manager/download-list';
import { SettingsPanel } from '@/components/download-manager/settings-panel';
import { useDownloads } from '@/lib/download-store';

export function DownloadManager() {
  const {
    downloads,
    settings,
    axelStatus,
    isLoading,
    error,
    addDownload,
    removeDownload,
    pauseDownload,
    resumeDownload,
    retryDownload,
    pauseAll,
    resumeAll,
    clearCompleted,
    updateSettings,
    openFile,
    openFolder,
    chooseDirectory,
    totalSpeed,
    completedToday
  } = useDownloads();

  const [activeFilter, setActiveFilter] = useState('all');
  const [settingsOpen, setSettingsOpen] = useState(false);

  const filteredDownloads = useMemo(() => {
    if (activeFilter === 'all') return downloads;
    if (activeFilter.startsWith('category:')) {
      const category = activeFilter.replace('category:', '');
      return downloads.filter((download) => download.category === category);
    }
    return downloads.filter((download) => download.status === activeFilter);
  }, [downloads, activeFilter]);

  const activeCount = downloads.filter((download) => download.status === 'downloading').length;

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
        totalDownloads={downloads.length}
        completedToday={completedToday}
        axelAvailable={Boolean(axelStatus?.available)}
      />

      {!axelStatus?.available ? (
        <div className="border-b border-destructive/30 bg-destructive/10 px-4 py-2 text-sm text-destructive">
          Axel is not available. Install `axel` on the system to enable downloads.
        </div>
      ) : null}

      {error ? (
        <div className="border-b border-warning/30 bg-warning/10 px-4 py-2 text-sm text-warning-foreground">
          {error}
        </div>
      ) : null}

      <div className="flex flex-1 overflow-hidden">
        <Sidebar downloads={downloads} activeFilter={activeFilter} onFilterChange={setActiveFilter} />

        <main className="flex flex-1 flex-col overflow-hidden">
          <div className="flex items-center justify-between border-b border-border px-4 py-3">
            <div className="text-sm text-muted-foreground">
              Showing <span className="font-medium text-foreground">{filteredDownloads.length}</span> downloads
            </div>
            {isLoading ? <div className="text-xs text-muted-foreground">Syncing…</div> : null}
          </div>

          <DownloadList
            downloads={filteredDownloads}
            onPause={pauseDownload}
            onResume={resumeDownload}
            onRemove={removeDownload}
            onRetry={retryDownload}
            onOpenFile={openFile}
            onOpenFolder={openFolder}
          />
        </main>
      </div>

      <SettingsPanel
        open={settingsOpen}
        onOpenChange={setSettingsOpen}
        settings={settings}
        onUpdateSettings={updateSettings}
        onChooseDirectory={() => chooseDirectory(settings.defaultSavePath)}
        axelVersion={axelStatus?.version}
      />
    </div>
  );
}
