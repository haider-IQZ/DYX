use serde_json::{json, Value};
use std::{
    collections::HashMap,
    env,
    io::{BufRead, BufReader, Write},
    path::PathBuf,
    process::{Child, ChildStdin, Command, Stdio},
    sync::{
        atomic::{AtomicU64, Ordering},
        mpsc, Arc, Mutex,
    },
    thread,
    time::Duration,
};
use tauri::{AppHandle, Emitter, Manager, State};

fn configure_linux_webkit_runtime() {
    #[cfg(target_os = "linux")]
    {
        if env::var_os("WEBKIT_DISABLE_DMABUF_RENDERER").is_none() {
            unsafe {
                env::set_var("WEBKIT_DISABLE_DMABUF_RENDERER", "1");
            }
        }

        if env::var_os("GDK_BACKEND").is_none() {
            let backend = if env::var("DYX_EXPERIMENTAL_WAYLAND").ok().as_deref() == Some("1") {
                "wayland"
            } else {
                "x11"
            };

            unsafe {
                env::set_var("GDK_BACKEND", backend);
            }
        }
    }
}

struct BackendState {
    child: Mutex<Child>,
    stdin: Mutex<ChildStdin>,
    pending: Arc<Mutex<HashMap<String, mpsc::Sender<Value>>>>,
    next_id: AtomicU64,
}

impl BackendState {
    fn send_request(&self, method: String, params: Option<Value>) -> Result<Value, String> {
        let id = format!("req_{}", self.next_id.fetch_add(1, Ordering::Relaxed));
        let request = json!({
            "id": id,
            "method": method,
            "params": params.unwrap_or_else(|| json!({})),
        });

        let (tx, rx) = mpsc::channel();
        self.pending
            .lock()
            .map_err(|_| "Backend request table lock poisoned".to_string())?
            .insert(id.clone(), tx);

        let line = serde_json::to_string(&request).map_err(|err| err.to_string())?;
        {
            let mut stdin = self
                .stdin
                .lock()
                .map_err(|_| "Backend stdin lock poisoned".to_string())?;
            stdin
                .write_all(line.as_bytes())
                .and_then(|_| stdin.write_all(b"\n"))
                .and_then(|_| stdin.flush())
                .map_err(|err| {
                    self.pending.lock().ok().map(|mut pending| pending.remove(&id));
                    format!("Failed to write to backend: {err}")
                })?;
        }

        rx.recv_timeout(Duration::from_secs(20))
            .map_err(|_| format!("Timed out waiting for backend response to {id}"))
    }
}

fn backend_candidates() -> Vec<PathBuf> {
    let mut candidates = Vec::new();

    if let Ok(path) = env::var("DYX_BACKEND_BIN") {
        candidates.push(PathBuf::from(path));
    }

    let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let repo_root = manifest_dir.join("..");
    candidates.push(repo_root.join("zig-out/bin/dyx-backend"));
    candidates.push(repo_root.join("zig-out/bin/dyx"));

    candidates
}

fn resolve_backend_bin() -> Result<PathBuf, String> {
    backend_candidates()
        .into_iter()
        .find(|path| path.exists())
        .ok_or_else(|| "Could not find dyx-backend. Set DYX_BACKEND_BIN or build the Zig backend first.".to_string())
}

fn spawn_backend(app: AppHandle) -> Result<BackendState, String> {
    let backend_bin = resolve_backend_bin()?;

    let mut child = Command::new(&backend_bin)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::inherit())
        .spawn()
        .map_err(|err| format!("Failed to start backend {}: {err}", backend_bin.display()))?;

    let stdout = child
        .stdout
        .take()
        .ok_or_else(|| "Backend stdout pipe was not available".to_string())?;
    let stdin = child
        .stdin
        .take()
        .ok_or_else(|| "Backend stdin pipe was not available".to_string())?;

    let pending = Arc::new(Mutex::new(HashMap::<String, mpsc::Sender<Value>>::new()));

    let state = BackendState {
        child: Mutex::new(child),
        stdin: Mutex::new(stdin),
        pending: Arc::clone(&pending),
        next_id: AtomicU64::new(1),
    };
    
    let state_pending = Arc::clone(&pending);
    thread::spawn(move || {
        let reader = BufReader::new(stdout);
        for line in reader.lines() {
            let Ok(line) = line else { break };
            if line.trim().is_empty() {
                continue;
            }

            let Ok(value) = serde_json::from_str::<Value>(&line) else {
                continue;
            };

            if value.get("event").is_some() {
                let _ = app.emit("backend-event", value);
                continue;
            }

            let Some(id) = value.get("id").and_then(Value::as_str) else {
                continue;
            };

            if let Ok(mut pending_map) = state_pending.lock() {
                if let Some(tx) = pending_map.remove(id) {
                    let _ = tx.send(value);
                }
            }
        }
    });

    Ok(state)
}

#[tauri::command]
fn backend_request(
    method: String,
    params: Option<Value>,
    state: State<'_, Arc<BackendState>>,
) -> Result<Value, String> {
    state.send_request(method, params)
}

pub fn run() {
    configure_linux_webkit_runtime();

    tauri::Builder::default()
        .setup(|app| {
            let state = spawn_backend(app.handle().clone())?;
            app.manage(Arc::new(state));
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![backend_request])
        .build(tauri::generate_context!())
        .expect("error while building tauri application")
        .run(|app_handle, event| {
            if let tauri::RunEvent::ExitRequested { .. } = event {
                if let Some(state) = app_handle.try_state::<Arc<BackendState>>() {
                    if let Ok(mut child) = state.child.lock() {
                        let _ = child.kill();
                    }
                }
            }
        });
}
