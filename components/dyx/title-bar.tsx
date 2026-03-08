"use client"

import { useState } from "react"

export function TitleBar() {
  const [hovering, setHovering] = useState(false)

  return (
    <div className="h-12 bg-card border-b border-border flex items-center px-4 gap-2 shrink-0">
      {/* macOS Traffic Lights */}
      <div
        className="flex items-center gap-2"
        onMouseEnter={() => setHovering(true)}
        onMouseLeave={() => setHovering(false)}
      >
        <button className="w-3 h-3 rounded-full bg-[#ff5f57] hover:brightness-90 transition-all flex items-center justify-center group">
          {hovering && (
            <svg className="w-2 h-2 text-[#4a0002] opacity-0 group-hover:opacity-100" viewBox="0 0 10 10" fill="currentColor">
              <path d="M1 1l8 8M9 1L1 9" stroke="currentColor" strokeWidth="1.5" fill="none" />
            </svg>
          )}
        </button>
        <button className="w-3 h-3 rounded-full bg-[#febc2e] hover:brightness-90 transition-all flex items-center justify-center group">
          {hovering && (
            <svg className="w-2 h-2 text-[#995700] opacity-0 group-hover:opacity-100" viewBox="0 0 10 10" fill="currentColor">
              <path d="M1 5h8" stroke="currentColor" strokeWidth="1.5" fill="none" />
            </svg>
          )}
        </button>
        <button className="w-3 h-3 rounded-full bg-[#28c840] hover:brightness-90 transition-all flex items-center justify-center group">
          {hovering && (
            <svg className="w-2 h-2 text-[#006500] opacity-0 group-hover:opacity-100" viewBox="0 0 10 10" fill="currentColor">
              <path d="M1 3.5L3.5 1M3.5 1L6 3.5M3.5 1v8M9 6.5L6.5 9M6.5 9L4 6.5M6.5 9V1" stroke="currentColor" strokeWidth="1" fill="none" />
            </svg>
          )}
        </button>
      </div>

      {/* App Title */}
      <div className="flex-1 flex items-center justify-center">
        <span className="text-sm font-semibold text-foreground tracking-wide">DYX</span>
        <span className="text-xs text-muted-foreground ml-2">Download Manager</span>
      </div>

      {/* Spacer for symmetry */}
      <div className="w-14" />
    </div>
  )
}
