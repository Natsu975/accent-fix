# accent-fix

**PowerToys Quick Accent-style character picker for Wayland compositors.**

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

### Example

| Key | Accents |
|-----|---------|
| `a` | à á â ã ä å æ ā |
| `e` | è é ê ë ē ė € |
| `i` | ì í î ï ī į |
| `o` | ò ó ô õ ö ø œ ō |
| `u` | ù ú ú ü ū ų |

> More keys can be added by editing the `ACCENTS` dictionary in the daemon.

## Requirements

- Linux
- A Wayland compositor (niri, Hyprland, Sway, etc.)
- Python 3

## Installation

### Quick Install (Double Click)

If you downloaded this folder via browser or as a zip:
1. Open the downloaded folder
2. **Double click** on the `Installer.desktop` file
   *(If your file manager asks, select "Execute" or "Allow execution")*
3. A terminal will open and automatically install the daemon and its dependencies.

### From Terminal (Classic method)

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

## NiriMod Integration

If you manage your configurations visually, I highly recommend [NiriMod](https://github.com/srinivasr/nirimod), a fantastic and elegant tool to configure Niri via a graphical interface. Kudos to [srinivasr](https://github.com/srinivasr) for this very useful project!

If you want a convenient on/off toggle to enable and disable *Accent Fix* directly from the NiriMod interface, I've included an automated script. Run this command inside this folder:

```bash
sudo python3 add-to-nirimod.py
```

**What does this script do behind the scenes?**
1. Automatically searches for the system installation folder of NiriMod (`/usr/lib/python3.*/site-packages/nirimod`).
2. Creates and inserts a new dedicated page, written in Python and GTK, to allow integration with the ON/OFF switch.
3. Safely patches the `window.py` file of NiriMod to register the new page and make the keyboard icon appear in the sidebar under the "Advanced" section.

Restart NiriMod and you'll have the toggle always just a click away!

## Tiling Fix (Window Managers)

The program uses `gtk4-layer-shell` to show itself as an overlay, but in case of issues (for example if the python module is not loaded correctly) your Window Manager might try to tile it instead of showing it floating.

To make sure it is never tiled, add the following rule to your compositor's configuration:

**For Niri** (`~/.config/niri/config.kdl`):
```kdl
window-rule {
    match app-id="accent\.fix\.daemon"
    open-floating true
}
```

**For Hyprland** (`~/.config/hypr/hyprland.conf`):
```conf
windowrulev2 = float, class:^(accent\.fix\.daemon)$
windowrulev2 = noanim, class:^(accent\.fix\.daemon)$
windowrulev2 = pin, class:^(accent\.fix\.daemon)$
```

**For Sway** (`~/.config/sway/config`):
```config
for_window [app_id="accent\.fix\.daemon"] floating enable
```

## Credits

- [Matugen](https://github.com/InioX/matugen) by InioX - For generating the beautiful dynamic Material You colors used by the overlay.
- [NiriMod](https://github.com/srinivasr/nirimod) by srinivasr - For the excellent Niri configuration GUI.

## License

[MIT](LICENSE)
