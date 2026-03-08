import { useState } from "react"
import { Sidebar } from "@/components/dyx/sidebar"
import { DownloadArea } from "@/components/dyx/download-area"
import { AddDownloadDialog } from "@/components/dyx/add-download-dialog"
import { TitleBar } from "@/components/dyx/title-bar"
import { useDyxDownloads } from "@/hooks/use-dyx-downloads"

export default function App() {
  const {
    downloads,
    stats,
    defaultSavePath,
    addDownload,
    togglePause,
    removeDownload,
    revealDownload,
  } = useDyxDownloads()
  const [activeFilter, setActiveFilter] = useState("all")
  const [isDialogOpen, setIsDialogOpen] = useState(false)

  const filteredDownloads = downloads.filter((d) => {
    if (activeFilter === "all") return true
    if (activeFilter === "downloading") return d.status === "downloading"
    if (activeFilter === "completed") return d.status === "completed"
    if (activeFilter === "queued") return d.status === "queued"
    if (activeFilter === "archives") return d.fileType === "archive"
    if (activeFilter === "videos") return d.fileType === "video"
    if (activeFilter === "audio") return d.fileType === "audio"
    if (activeFilter === "documents") return d.fileType === "document"
    return true
  })

  return (
    <div className="dark h-screen w-screen overflow-hidden bg-background text-foreground">
      <div className="flex h-full flex-col">
        <TitleBar />
        <div className="flex flex-1 overflow-hidden">
          <Sidebar activeFilter={activeFilter} onFilterChange={setActiveFilter} stats={stats} />
          <DownloadArea
            downloads={filteredDownloads}
            onTogglePause={togglePause}
            onRemove={removeDownload}
            onOpenFolder={revealDownload}
            onAddNew={() => setIsDialogOpen(true)}
          />
        </div>
        <AddDownloadDialog
          open={isDialogOpen}
          onOpenChange={setIsDialogOpen}
          onAdd={addDownload}
          defaultSavePath={defaultSavePath}
        />
      </div>
    </div>
  )
}
