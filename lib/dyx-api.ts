"use client";

import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import type { AppSettings, AxelStatus, DownloadItem, HistoryItem, IpcEvent, IpcResponse, StartDownloadRequest } from "./dyx-types";

function makeId() {
  return `req_${Math.random().toString(36).slice(2, 10)}`;
}

async function request<T = unknown>(method: string, params?: unknown): Promise<T> {
  const response = await invoke<IpcResponse<T>>("backend_request", { method, params });
  if (!response.ok) {
    throw new Error(response.error);
  }
  return response.result;
}

export async function subscribeToBackendEvents(handler: (event: IpcEvent) => void) {
  return listen<IpcEvent>("backend-event", (event) => {
    handler(event.payload);
  });
}

export const checkAxel = () => request<AxelStatus>("checkAxel");
export const getSettings = () => request<AppSettings>("getSettings");
export const saveSettings = (settings: AppSettings) => request<AppSettings>("saveSettings", settings);
export const listDownloads = () => request<DownloadItem[]>("listDownloads");
export const listHistory = () => request<HistoryItem[]>("listHistory");
export const startDownload = (payload: StartDownloadRequest) => request<DownloadItem>("startDownload", payload);
export const cancelDownload = (id: string) => request<void>("cancelDownload", { id });
export const retryDownload = (id: string) => request<DownloadItem>("retryDownload", { id });
export const removeHistoryItem = (id: string) => request<void>("removeHistoryItem", { id });
export const deleteFile = (path: string) => request<void>("deleteFile", { path });
export const openFolder = (path: string) => request<void>("openFolder", { path });
