# Bitácora

**The terminal of pleamar's desktop.** Tabs with a glyph of their own, panes
side by side or one under another, the desktop's colours, and a line that says
where you are and on which branch.

![Bitácora: two panes, the menu of the right button and the line under them](docs/bitacora.png)

The terminal itself is not here: it is [pleamar](https://github.com/k4ditano/pleamar)'s
own `terminal` element, a shell on a pty drawn by the engine with its own
letters (the emulator underneath is `alacritty_terminal`, Alacritty's and
Zed's). Bitácora is its window: a pleamar scene (`ui/bitacora.plm`) and its
logic (`ui/bitacora.luau`), carried inside one binary with its fonts.

[Leer en español](LEEME.md)

## What it does

- **Tabs** (six at most), each named after what runs in it or the folder it is
  in, with a glyph of five by five grains made from that folder: the same
  folder, the same glyph, wherever you see it.
- **Panes** (four a tab): beside or below, the one with the keys outlined in the
  desktop's accent, the others a little fainter. A shell that ends takes its
  pane with it; the last one, the window.
- **The desktop's colours.** Under [Calima](https://github.com/k4ditano/calima)
  it takes the Taller's accent, surface and ink, light or dark, and follows
  them when they change; the sixteen ANSI colours are tuned for each.
- **The line under it all**: the folder of the shell with the keys, its git
  branch, what runs and how many columns and lines.
- **What a good terminal does**: 16, 256 and 24-bit colours, bold, italic,
  underlines; box lines and blocks drawn by hand so they meet; selecting with
  the mouse (two clicks a word, three a line), Ctrl+Shift+C and V, the middle
  button pastes; the wheel through the history; Ctrl+click opens a link;
  programs that want the mouse (vim, htop) get it; and the cursor glides when
  you type.
- **Agents read it.** In a pleamar-wm session its shells go through the layer of
  terminals, so `pleamar-wm agent` reads them and runs commands in them as in
  any other terminal.

## Keys

| | |
|---|---|
| Ctrl+Shift+T | a new tab, in the folder of the one you are in |
| Ctrl+Shift+W | close the pane (and the tab, with its last one) |
| Ctrl+Shift+D / E | a pane beside / below |
| Alt+arrows | to the pane that way |
| Ctrl+Tab, Ctrl+Shift+Tab, Ctrl+PageDown/Up | the next tab, the one before |
| Ctrl+Shift+C / V | copy what is selected / paste |
| Shift+PageUp / PageDown | through the history |
| Ctrl++ / Ctrl+- / Ctrl+= (Ctrl+Shift+= on some keyboards) | bigger, smaller, as it was |
| Ctrl+Shift+N | a new window |

The right button opens a menu with the same, and with *Select all* and
*Forget its history*.

## Install

It needs Rust, and a pleamar with the `terminal` element (the `terminal`
branch until it is released).

```sh
git clone https://github.com/k4ditano/bitacora && cd bitacora
sh install.sh      # ~/.local/bin/bitacora, its entry among the applications and its icon
```

`bitacora [FOLDER]` opens a window there (where you are, if not said). Each
window is its own process: installing a new Bitácora leaves the open ones
with their shells.

## Working on its look

`BITACORA_UI_DIR=ui bitacora` reads the window from the repository instead of
the copy in the binary, and reloads it when `bitacora.plm` or `bitacora.luau`
is saved.

## Licence

MIT. Its fonts are JetBrains Mono, Manrope and Newsreader, each under the SIL
Open Font License (in `ui/fonts`).
