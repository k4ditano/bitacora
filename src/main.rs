//! Bitácora — the terminal of pleamar's desktop.
//!
//! The terminal itself is pleamar's (`terminal` in its language: a shell on a
//! pty, drawn by the engine with its own letters); this program is its window:
//! tabs, panes, the desktop's colours, and the line of what is where. The
//! window is a scene (`ui/bitacora.plm` and its logic `ui/bitacora.luau`),
//! carried inside the binary with its fonts and written out where pleamar
//! reads it. With `BITACORA_UI_DIR` it reads it from there instead, and
//! reloads it when it is saved: to work on its look.

const UI: &[(&str, &[u8])] = &[
    ("bitacora.plm", include_bytes!("../ui/bitacora.plm")),
    ("bitacora.luau", include_bytes!("../ui/bitacora.luau")),
    ("fonts/JetBrainsMono-Variable.ttf", include_bytes!("../ui/fonts/JetBrainsMono-Variable.ttf")),
    ("fonts/JetBrainsMono-Italic-Variable.ttf", include_bytes!("../ui/fonts/JetBrainsMono-Italic-Variable.ttf")),
    ("fonts/Manrope-Variable.ttf", include_bytes!("../ui/fonts/Manrope-Variable.ttf")),
    ("fonts/Newsreader-Variable.ttf", include_bytes!("../ui/fonts/Newsreader-Variable.ttf")),
];

const HELP: &str = "bitacora [FOLDER]
  The terminal of pleamar's desktop: tabs, panes, and the desktop's colours.

  FOLDER          where its first shell starts (the current folder if not said)
  --version       its version
  --help          this

  In it:
    Ctrl+Shift+T        a new tab, in the folder of the one you are in
    Ctrl+Shift+W        close the pane (and the tab with its last one)
    Ctrl+Shift+D        split: a pane beside
    Ctrl+Shift+E        split: a pane below
    Alt+arrows          to the pane that way
    Ctrl+Tab            the next tab (Ctrl+Shift+Tab, the one before)
    Ctrl+PageDown/Up    the same
    Ctrl+Shift+C / V    copy what is selected / paste
    Shift+PageUp/Down   through the history
    Ctrl++ / Ctrl+- / Ctrl+=   bigger, smaller, as it was
    Ctrl+Shift+N        a new window";

fn main() {
    let mut folder: Option<String> = None;
    for a in std::env::args().skip(1) {
        match a.as_str() {
            "--version" | "-V" => {
                println!("bitacora {}", env!("CARGO_PKG_VERSION"));
                return;
            }
            "--help" | "-h" => {
                println!("{HELP}");
                return;
            }
            f if !f.starts_with('-') => folder = Some(f.to_owned()),
            other => {
                eprintln!("bitacora: «{other}» is not something it understands\n\n{HELP}");
                std::process::exit(2);
            }
        }
    }
    // Where its first shell starts: what was said, or where it was started.
    let start = folder
        .map(std::path::PathBuf::from)
        .map(|p| if p.is_absolute() { p } else { std::env::current_dir().unwrap_or_default().join(p) })
        .or_else(|| std::env::current_dir().ok())
        .filter(|p| p.is_dir())
        .map(|p| p.display().to_string())
        .unwrap_or_default();
    // (Read by the logic through the `env` service.)
    unsafe {
        std::env::set_var("BITACORA_FOLDER", &start);
        std::env::set_var("BITACORA_BIN", std::env::current_exe().map(|p| p.display().to_string()).unwrap_or_else(|_| "bitacora".into()));
        // Its shells say what is drawing them, as other terminals do.
        std::env::set_var("TERM_PROGRAM", "bitacora");
        std::env::set_var("TERM_PROGRAM_VERSION", env!("CARGO_PKG_VERSION"));
    }
    let dir = match std::env::var_os("BITACORA_UI_DIR").filter(|d| !d.is_empty()) {
        Some(d) => std::path::PathBuf::from(d),
        None => match written_out() {
            Ok(d) => d,
            Err(e) => {
                eprintln!("bitacora: its window could not be written out: {e}");
                std::process::exit(1);
            }
        },
    };
    // A new Bitácora installed does not end the shells of the windows open: they keep the one they started with.
    pleamar::stay_on_update();
    pleamar::run_with(vec!["--scene".to_owned(), dir.join("bitacora.plm").display().to_string(), "--no-hud".to_owned()]);
}

/// The window's files, where pleamar reads them: one folder per version of
/// them (`$XDG_DATA_HOME/bitacora/ui-HASH`), written once, whole, before it is used.
fn written_out() -> std::io::Result<std::path::PathBuf> {
    let mut h: u64 = 0xcbf2_9ce4_8422_2325;
    for (name, bytes) in UI {
        for b in name.bytes().chain(bytes.iter().copied()) {
            h = (h ^ b as u64).wrapping_mul(0x0100_0000_01b3);
        }
    }
    let home = std::env::var("HOME").unwrap_or_default();
    let data = std::env::var("XDG_DATA_HOME").ok().filter(|d| !d.is_empty()).unwrap_or_else(|| format!("{home}/.local/share"));
    let dir = std::path::PathBuf::from(data).join("bitacora").join(format!("ui-{h:016x}"));
    if dir.join(".whole").exists() {
        return Ok(dir);
    }
    let new = dir.with_extension(format!("new-{}", std::process::id()));
    for (name, bytes) in UI {
        let p = new.join(name);
        std::fs::create_dir_all(p.parent().unwrap())?;
        std::fs::write(&p, bytes)?;
    }
    std::fs::write(new.join(".whole"), b"")?;
    // (Another window may have written it meanwhile: then that one stays.)
    if std::fs::rename(&new, &dir).is_err() && !dir.join(".whole").exists() {
        return Err(std::io::Error::other("could not put it in its place"));
    }
    Ok(dir)
}
