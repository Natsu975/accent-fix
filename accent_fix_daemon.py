#!/usr/bin/env python3
import gi, evdev, threading, subprocess, os, json, atexit
gi.require_version("Gtk", "4.0")
try:
    gi.require_version("Gtk4LayerShell", "1.0")
    from gi.repository import Gtk4LayerShell as ls
    _HAS_LAYER_SHELL = True
except Exception:
    ls = None
    _HAS_LAYER_SHELL = False
from gi.repository import Gtk, GLib, Gdk
import evdev.ecodes as ec

_uinput = None
def _get_uinput():
    global _uinput
    if _uinput is None:
        try:
            _uinput = evdev.UInput(
                {ec.EV_KEY: [ec.KEY_LEFTCTRL, ec.KEY_V, ec.KEY_RIGHT, ec.KEY_LEFT]},
                name="accent_fix",
            )
            atexit.register(_uinput.close)
        except Exception:
            pass
    return _uinput

def _release_key_x11(keycode: int):
    ui = _get_uinput()
    if ui:
        try:
            ui.write(ec.EV_KEY, keycode, 0)
            ui.syn()
        except Exception:
            pass

COLOR_PATHS = [
    os.path.expanduser("~/.cache/matugen/colors.json"),
    os.path.expanduser("~/.local/state/quickshell/user/generated/colors.json"),
    os.path.expanduser("~/.local/state/caelestia/scheme.json"),
]

def get_colors():
    c = {"acc": "#aac7ff", "bg": "rgba(17, 19, 24, 0.92)", "fg": "#e2e2e9", "on_acc": "#0b305f"}
    for path in COLOR_PATHS:
        if os.path.exists(path):
            try:
                with open(path) as f:
                    data = json.load(f)
                    # Check for matugen format
                    colors = data.get("colors", data)
                    if "light" in colors: # matugen typically has light/dark
                        colors = colors.get("dark", colors.get("light", colors))
                    
                    fix = lambda h: h if h and h.startswith("#") else "#{0}".format(h) if h else None
                    acc = fix(colors.get("primary"))
                    bg_raw = colors.get("surface_container") or colors.get("surface")
                    fg = fix(colors.get("on_surface"))
                    on_acc = fix(colors.get("on_primary"))
                    if acc: c["acc"] = acc
                    if fg: c["fg"] = fg
                    if on_acc: c["on_acc"] = on_acc
                    if bg_raw:
                        bg_raw = fix(bg_raw)
                        if bg_raw:
                            h = bg_raw.lstrip("#")
                            r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
                            c["bg"] = "rgba({0},{1},{2},0.92)".format(r, g, b)
                return c
            except: continue
    return c

def apply_style():
    c = get_colors()
    css = ("window {{ background: {0}; border: 2px solid {1}; border-radius: 12px; }} "
           "label {{ color: {2}; font-size: 20px; padding: 10px; }} "
           ".char-selected {{ background: {1}; color: {3}; font-weight: bold; border-radius: 8px; }}"
           ).format(c["bg"], c["acc"], c["fg"], c["on_acc"])
    provider = Gtk.CssProvider()
    provider.load_from_string(css)
    Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

ACCENTS = {
    ec.KEY_A: ["\u00e0", "\u00e1", "\u00e2", "\u00e3", "\u00e4", "\u00e5", "\u00e6", "\u0101"],
    ec.KEY_E: ["\u00e8", "\u00e9", "\u00ea", "\u00eb", "\u0113", "\u0117", "\u20ac"],
    ec.KEY_I: ["\u00ec", "\u00ed", "\u00ee", "\u00ef", "\u012b", "\u012f"],
    ec.KEY_O: ["\u00f2", "\u00f3", "\u00f4", "\u00f5", "\u00f6", "\u00f8", "\u0153", "\u014d"],
    ec.KEY_U: ["\u00f9", "\u00fa", "\u00fb", "\u00fc", "\u016b", "\u0173"],
}

def _type_char(char: str):
    import time
    try:
        prev = subprocess.run(["wl-paste", "--no-newline"], capture_output=True, text=True).stdout
    except Exception:
        prev = ""
    try:
        subprocess.run(["wl-copy", "--", char], check=True)
        time.sleep(0.05)
        ui = _get_uinput()
        if ui:
            ui.write(ec.EV_KEY, ec.KEY_LEFTCTRL, 1); ui.syn()
            time.sleep(0.02)
            ui.write(ec.EV_KEY, ec.KEY_V, 1); ui.syn()
            time.sleep(0.02)
            ui.write(ec.EV_KEY, ec.KEY_V, 0); ui.syn()
            time.sleep(0.02)
            ui.write(ec.EV_KEY, ec.KEY_LEFTCTRL, 0); ui.syn()
        time.sleep(0.08)
    finally:
        if prev:
            subprocess.run(["wl-copy", "--", prev])
        else:
            subprocess.run(["wl-copy", "--clear"])

_state = {"key": None, "clist": None, "idx": 0, "upper": False, "active": False}
_lock = threading.Lock()
_win = None

def _close_menu():
    global _win
    if _win: _win.set_visible(False)

class AccentWin(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app)
        self.set_title("accent_fix")
        if _HAS_LAYER_SHELL and ls.is_supported():
            ls.init_for_window(self)
            ls.set_layer(self, ls.Layer.OVERLAY)
            ls.set_anchor(self, ls.Edge.BOTTOM, True)
            ls.set_margin(self, ls.Edge.BOTTOM, 60)
            ls.set_keyboard_mode(self, ls.KeyboardMode.NONE)
        else:
            self.set_decorated(False)
        self.box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        self.set_child(self.box)

    def refresh(self, clist, idx, upper):
        apply_style()
        while (child := self.box.get_first_child()):
            self.box.remove(child)
        for i, char in enumerate(clist):
            lbl = Gtk.Label(label=char.upper() if (upper and char.isalpha()) else char)
            if i == (idx % len(clist)):
                lbl.add_css_class("char-selected")
            self.box.append(lbl)
        self.set_visible(True)

def handler(device):
    shift = False
    grabbed = False
    for ev in device.read_loop():
        if ev.type != ec.EV_KEY: continue
        if ev.code in (ec.KEY_LEFTSHIFT, ec.KEY_RIGHTSHIFT):
            shift = (ev.value > 0)
            continue
        
        if ev.code in (ec.KEY_RIGHT, ec.KEY_LEFT):
            if ev.value in (1, 2):
                with _lock:
                    if _state["key"] is None: continue
                    if not _state["active"]:
                        subprocess.run(["wtype", "-k", "BackSpace"])
                        _state["active"] = True
                        if not grabbed:
                            try:
                                device.grab()
                                grabbed = True
                                _release_key_x11(ev.code)
                            except Exception: pass
                    _state["idx"] += 1 if ev.code == ec.KEY_RIGHT else -1
                    clist = _state["clist"]
                    idx = _state["idx"]
                    upper = _state["upper"]
                if _win:
                    GLib.idle_add(_win.refresh, clist, idx, upper)
            continue

        if ev.value == 0:
            with _lock:
                if ev.code != _state.get("key"): continue
                do_insert = _state["active"]
                char = None
                if do_insert:
                    c = _state["clist"]
                    char = c[_state["idx"] % len(c)]
                    if _state["upper"] and char.isalpha(): char = char.upper()
                _state.update({"key": None, "active": False})
            if do_insert:
                if grabbed:
                    try:
                        device.ungrab()
                        grabbed = False
                    except Exception: pass
                GLib.idle_add(_close_menu)
                _type_char(char)
        elif ev.value == 1:
            clist = ACCENTS.get(ev.code)
            was_active = False
            with _lock:
                was_active = _state["active"]
                if clist:
                    _state.update({"key": ev.code, "clist": clist, "upper": shift, "idx": 0, "active": False})
                else:
                    _state.update({"key": None, "active": False})
            if was_active:
                if grabbed:
                    try: device.ungrab(); grabbed = False
                    except Exception: pass
                GLib.idle_add(_close_menu)

def listen():
    seen = set()
    for path in evdev.list_devices():
        try:
            d = evdev.InputDevice(path)
            if ec.EV_KEY not in d.capabilities(): continue
            if ec.KEY_A not in d.capabilities()[ec.EV_KEY]: continue
            if ec.EV_REL in d.capabilities(): continue
            if d.name not in seen:
                seen.add(d.name)
                threading.Thread(target=handler, args=(d,), daemon=True).start()
        except: pass

class App(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="accent.fix.daemon")
    def do_activate(self):
        global _win
        _win = AccentWin(self)
        listen()

if __name__ == "__main__":
    App().run(None)
