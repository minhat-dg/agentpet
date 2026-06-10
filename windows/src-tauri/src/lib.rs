pub mod cli;
pub mod hooks;
pub mod server;
pub mod statemap;

use std::sync::Mutex;
use tauri::menu::{Menu, MenuItem};
use tauri::tray::TrayIconBuilder;
use tauri::{Manager, WebviewUrl, WebviewWindowBuilder};

/// Tray menu items kept around so the language switcher can re-label them live.
struct TrayItems {
    settings: MenuItem<tauri::Wry>,
    quit: MenuItem<tauri::Wry>,
}

fn lang_file() -> Option<std::path::PathBuf> {
    dirs::config_dir().map(|d| d.join("AgentPet").join("lang"))
}

fn read_lang() -> String {
    lang_file()
        .and_then(|p| std::fs::read_to_string(p).ok())
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "en".into())
}

fn write_lang(code: &str) {
    if let Some(p) = lang_file() {
        if let Some(d) = p.parent() {
            let _ = std::fs::create_dir_all(d);
        }
        let _ = std::fs::write(p, code);
    }
}

/// Localised tray labels (the only app text on the Rust side).
fn tray_labels(code: &str) -> (&'static str, &'static str) {
    match code {
        "vi" => ("Cài đặt", "Thoát AgentPet"),
        "zh" => ("设置", "退出 AgentPet"),
        _ => ("Settings", "Quit AgentPet"),
    }
}

#[tauri::command]
fn list_agents() -> Vec<hooks::AgentInfo> {
    hooks::catalog()
}

#[tauri::command]
fn is_installed(kind: String) -> bool {
    hooks::is_installed(&kind)
}

#[tauri::command]
fn toggle_install(kind: String) -> Result<bool, String> {
    hooks::toggle(&kind)
}

#[tauri::command]
fn open_settings(app: tauri::AppHandle) {
    if let Some(w) = app.get_webview_window("settings") {
        let _ = w.set_focus();
        return;
    }
    let _ = WebviewWindowBuilder::new(&app, "settings", WebviewUrl::App("settings.html".into()))
        .title("AgentPet , Settings")
        .inner_size(460.0, 640.0)
        .resizable(true)
        .build();
}

/// Persist the chosen language (for the tray on next launch) and re-label the
/// tray menu items now. Called by the Settings language switcher.
#[tauri::command]
fn set_lang(app: tauri::AppHandle, code: String) {
    write_lang(&code);
    let (s, q) = tray_labels(&code);
    if let Some(items) = app.try_state::<Mutex<TrayItems>>() {
        if let Ok(it) = items.lock() {
            let _ = it.settings.set_text(s);
            let _ = it.quit.set_text(q);
        }
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_autostart::init(
            tauri_plugin_autostart::MacosLauncher::LaunchAgent,
            None,
        ))
        .invoke_handler(tauri::generate_handler![
            list_agents,
            is_installed,
            toggle_install,
            open_settings,
            set_lang
        ])
        .setup(|app| {
            server::start(app.handle().clone());

            // Park the pet near the bottom-right of the primary screen. The
            // config x/y is only a fallback; this keeps it on-screen on smaller
            // or HiDPI displays where a fixed position could land off-screen.
            if let Some(win) = app.get_webview_window("pet") {
                if let Ok(Some(mon)) = win.primary_monitor() {
                    let s = mon.scale_factor();
                    let sz = mon.size();
                    let x = (sz.width as f64 / s) - 200.0 - 40.0;
                    let y = (sz.height as f64 / s) - 220.0 - 70.0;
                    let _ = win.set_position(tauri::LogicalPosition::new(x.max(0.0), y.max(0.0)));
                }
            }

            // Tray menu , the pet window is frameless, so this is how you reach
            // Settings or quit the app. Labels start in the saved language; the
            // Settings switcher re-labels them live via the `set_lang` command.
            let (s_lbl, q_lbl) = tray_labels(&read_lang());
            let settings_i = MenuItem::with_id(app, "settings", s_lbl, true, None::<&str>)?;
            let quit_i = MenuItem::with_id(app, "quit", q_lbl, true, None::<&str>)?;
            let menu = Menu::with_items(app, &[&settings_i, &quit_i])?;
            app.manage(Mutex::new(TrayItems {
                settings: settings_i.clone(),
                quit: quit_i.clone(),
            }));
            let mut tray = TrayIconBuilder::new()
                .tooltip("AgentPet")
                .menu(&menu)
                .on_menu_event(|app, event| match event.id.as_ref() {
                    "settings" => open_settings(app.clone()),
                    "quit" => app.exit(0),
                    _ => {}
                });
            if let Some(icon) = app.default_window_icon() {
                tray = tray.icon(icon.clone());
            }
            let _tray = tray.build(app)?;

            // First run: open Settings so the user knows to pick a pet and
            // connect an agent (otherwise the pet just sits there silently).
            let marker = dirs::config_dir().map(|d| d.join("AgentPet").join(".onboarded"));
            if let Some(m) = marker {
                if !m.exists() {
                    open_settings(app.handle().clone());
                    if let Some(parent) = m.parent() {
                        let _ = std::fs::create_dir_all(parent);
                    }
                    let _ = std::fs::write(&m, "1");
                }
            }
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running AgentPet");
}
