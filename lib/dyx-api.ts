"use client";

import type { AppSettings, AxelStatus, DownloadItem, HistoryItem, IpcEvent, IpcResponse, StartDownloadRequest } from "./dyx-types";

type Unlisten = () => void;

type DYXBridge = {
  request<T = unknown>(method: string, params?: unknown): Promise<IpcResponse<T>>;
  subscribe?(handler: (event: IpcEvent) => void): Promise<Unlisten> | Unlisten;
};

declare global {
  interface Window {
    __DYX__?: DYXBridge;
  }
}

let tauriBridgePromise: Promise<DYXBridge> | null = null;

async function getTauriBridge(): Promise<DYXBridge> {
  if (!tauriBridgePromise) {
    tauriBridgePromise = (async () => {
      const [{ invoke }, { listen }] = await Promise.all([
        import("@tauri-apps/api/core"),
        import("@tauri-apps/api/event"),
      ]);

      return {
        request<T = unknown>(method: string, params?: unknown) {
          return invoke<IpcResponse<T>>("backend_request", { method, params });
        },
        subscribe(handler: (event: IpcEvent) => void) {
          return listen<IpcEvent>("backend-event", (event) => {
            handler(event.payload);
          });
        },
      };
    })();
  }

  return tauriBridgePromise;
}

async function getBridge(): Promise<DYXBridge> {
  if (typeof window !== "undefined" && window.__DYX__) {
    return window.__DYX__;
  }

  return getTauriBridge();
}

async function request<T = unknown>(method: string, params?: unknown): Promise<T> {
  const bridge = await getBridge();
  const response = await bridge.request<T>(method, params);
  if (!response.ok) {
    throw new Error(response.error);
  }
  return response.result;
}

export async function subscribeToBackendEvents(handler: (event: IpcEvent) => void) {
  const bridge = await getBridge();
  if (!bridge.subscribe) {
    return () => {};
  }
  return bridge.subscribe(handler);
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
