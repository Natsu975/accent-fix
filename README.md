# accent-fix

**PowerAccent-style accent character picker for Wayland compositors.**

Hold a letter key, press `←` / `→` to browse accented variants, release to insert.  
Works on **niri**, **Hyprland**, and other wlroots-based compositors.

<!-- TODO: Add screenshot/GIF here -->
<!-- ![accent-fix demo](assets/demo.gif) -->

## Features

- 🎯 **Hold & pick** — Hold a letter, use arrow keys to scroll through accents, release to type
- 🖥️ **Wayland native** — Uses GTK4 + gtk4-layer-shell overlay (no X11 needed)
- 🎨 **Dynamic theming** — Reads accent colors from matugen, Quickshell, or Caelestia
- ⌨️ **Smart input** — Uses `evdev` grab + `uinput` for reliable character insertion
- 🔄 **Clipboard-safe** — Saves and restores your clipboard content after each accent

### Supported Characters

| Key | Accents |
|-----|---------|
| `a` | à á â ã ä å æ ā |
| `e` | è é ê ë ē ė € |
| `i` | ì í î ï ī į |
| `o` | ò ó ô õ ö ø œ ō |
| `u` | ù ú û ü ū ų |

> More keys can be added by editing the `ACCENTS` dictionary in the daemon.

## Requirements

- Arch Linux / CachyOS (or any Arch-based distro)
- A Wayland compositor (niri, Hyprland, Sway, etc.)
- Python 3

## Installation

### Installazione Rapida (Doppio Clic)

Se hai scaricato questa cartella dal browser o tramite uno zip:
1. Entra nella cartella scaricata
2. Fai **doppio clic** sul file `Installer.desktop`
   *(Se il tuo gestore file te lo chiede, seleziona "Esegui" o "Consenti esecuzione")*
3. Si aprirà un terminale che installerà automaticamente il demone e le dipendenze.

### Da Terminale (metodo classico)

```bash
git clone https://github.com/YOURUSERNAME/accent-fix.git
cd accent-fix
chmod +x install.sh
./install.sh
```

The installer will:
1. Install all dependencies via `paru`/`yay`/`pacman`
2. Copy the daemon to `~/.local/bin/`
3. Create and enable a systemd user service
4. (Hyprland only) Add submap keybinds to prevent key conflicts

### Manual Install

```bash
# Install dependencies
sudo pacman -S python-gobject gtk4 gtk4-layer-shell python-evdev wtype wl-clipboard

# Copy daemon
cp accent_fix_daemon.py ~/.local/bin/
chmod +x ~/.local/bin/accent_fix_daemon.py

# Copy and enable service
cp accent-fix.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now accent-fix.service
```

### PKGBUILD (Arch)

```bash
makepkg -si
```

## Usage

Once installed and the service is running, just:

1. **Hold** any supported letter key (e.g., `a`)
2. **Press** `→` or `←` to navigate accented characters
3. **Release** the letter key to insert the selected character

The accent overlay appears at the bottom of your screen.

## Commands

```bash
systemctl --user status accent-fix     # Check status
systemctl --user restart accent-fix    # Restart daemon
systemctl --user stop accent-fix       # Stop daemon
journalctl --user -u accent-fix -f     # Live logs
```

## Uninstall

```bash
chmod +x uninstall.sh
./uninstall.sh
```

## How It Works

The daemon runs as a background systemd user service. It uses `evdev` to listen for keyboard events directly from the input device. When a supported key is held and arrow keys are pressed, it:

1. Grabs the keyboard device to prevent key events from reaching the compositor
2. Displays a GTK4 layer-shell overlay showing available accents
3. On release, copies the selected character to clipboard and pastes it via `uinput` (Ctrl+V)
4. Restores the original clipboard content

## Theming

The overlay automatically reads colors from (in priority order):
1. `~/.cache/matugen/colors.json`
2. `~/.local/state/quickshell/user/generated/colors.json`
3. `~/.local/state/caelestia/scheme.json`

If no theme file is found, a default dark blue theme is used.

## Tiling Fix (Window Managers)

Il programma usa `gtk4-layer-shell` per mostrarsi come overlay, ma in caso di problemi (ad esempio se il modulo python non viene caricato correttamente) il tuo Window Manager potrebbe tentare di "incastrarlo" (tiling) invece di mostrarlo fluttuante.

Per assicurarti che non venga mai visualizzato come tile, aggiungi la seguente regola alla configurazione del tuo compositor:

**Per Niri** (`~/.config/niri/config.kdl`):
```kdl
window-rule {
    match app-id="accent\.fix\.daemon"
    open-floating true
}
```

**Per Hyprland** (`~/.config/hypr/hyprland.conf`):
```conf
windowrulev2 = float, class:^(accent\.fix\.daemon)$
windowrulev2 = noanim, class:^(accent\.fix\.daemon)$
windowrulev2 = pin, class:^(accent\.fix\.daemon)$
```

**Per Sway** (`~/.config/sway/config`):
```config
for_window [app_id="accent\.fix\.daemon"] floating enable
```

## License

[MIT](LICENSE)
