#!/usr/bin/env python3
"""
Aggiunge la sezione Accent Fix a una installazione di NiriMod.
Richiede i permessi di root (sudo) poiché NiriMod è installato a livello di sistema.
"""
import sys, shutil, glob
from pathlib import Path

G = "\033[32m"; Y = "\033[33m"; R = "\033[31m"; B = "\033[34m"
BOLD = "\033[1m"; N = "\033[0m"
ok   = lambda s: print(f"{G}✓{N} {s}")
info = lambda s: print(f"{B}→{N} {s}")
warn = lambda s: print(f"{Y}⚠{N} {s}")
fail = lambda s: (print(f"{R}✗{N} {s}"), sys.exit(1))
hdr  = lambda s: print(f"\n{BOLD}{B}── {s} ──{N}")

print(f"\n{BOLD}  Accent Fix → NiriMod patch script{N}\n")

# ════════════════════════════════════════════════════════════════
hdr("1/3 Trova NiriMod")
# ════════════════════════════════════════════════════════════════

site_pkgs = glob.glob("/usr/lib/python3.*/site-packages/nirimod")
if not site_pkgs:
    fail("Pacchetto nirimod non trovato in /usr/lib/python3.*/site-packages/nirimod")

pkg = Path(site_pkgs[0])
pages_dir = pkg / "pages"
window_py = pkg / "window.py"

for f in [pages_dir, window_py]:
    if not f.exists():
        fail(f"Cartella/file non trovato: {f}")

ok(f"NiriMod trovato in {pkg}")

# ════════════════════════════════════════════════════════════════
hdr("2/3 Scrivi accent_fix_page.py")
# ════════════════════════════════════════════════════════════════

accent_py = pages_dir / "accent_fix_page.py"

CONTENT = '''\
import subprocess
from gi.repository import Adw, GLib, Gtk

_SCRIPT = str(__import__("pathlib").Path.home() / ".local" / "bin" / "accent_fix_daemon.py")

def _is_running() -> bool:
    res = subprocess.run(["pgrep", "-f", "accent_fix_daemon.py"], capture_output=True)
    return res.returncode == 0

class AccentFixPage:
    def __init__(self, window):
        self._window = window
        self._switch_row = None

    def build(self):
        page = Adw.PreferencesPage(title="Accent Fix")
        group = Adw.PreferencesGroup(title="Accent Fix Daemon", description="Overlay per accenti tramite frecce.")
        
        self._switch_row = Adw.SwitchRow(title="Attivo")
        self._switch_row.set_active(_is_running())
        self._switch_row.connect("notify::active", self._on_toggle)
        group.add(self._switch_row)
        
        page.add(group)
        return page

    def _on_toggle(self, row, _pspec):
        if row.get_active():
            if not _is_running():
                # Usa systemctl se disponibile, altrimenti esegui lo script
                res = subprocess.run(["systemctl", "--user", "start", "accent-fix"], capture_output=True)
                if res.returncode != 0:
                    import os
                    subprocess.Popen(
                        ["python3", _SCRIPT],
                        start_new_session=True,
                        env={**os.environ, "LD_PRELOAD": "/usr/lib/libgtk4-layer-shell.so"}
                    )
        else:
            subprocess.run(["systemctl", "--user", "stop", "accent-fix"], capture_output=True)
            subprocess.run(["pkill", "-f", "accent_fix_daemon.py"], capture_output=True)
'''

try:
    if accent_py.exists():
        warn("accent_fix_page.py già presente — sovrascrittura")
        shutil.copy(accent_py, str(accent_py) + ".bak")
    accent_py.write_text(CONTENT, encoding="utf-8")
    ok(f"Scritto: {accent_py}")
except PermissionError:
    fail("Permesso negato! Devi eseguire questo script con sudo.")

# ════════════════════════════════════════════════════════════════
hdr("3/3 Patcha window.py")
# ════════════════════════════════════════════════════════════════

try:
    txt = window_py.read_text(encoding="utf-8")
    changed = False

    # Aggiungi in SIDEBAR_GROUPS
    if '"accent_fix_page"' not in txt:
        old_group = '("raw_config", "text-x-generic-symbolic", "Raw Config"),'
        new_group = old_group + '\n        ("accent_fix_page", "input-keyboard-symbolic", "Accent Fix"),'
        if old_group in txt:
            txt = txt.replace(old_group, new_group)
            changed = True
            ok("Aggiunta Accent Fix alla sidebar (sezione Advanced)")
        else:
            warn("Ancora per SIDEBAR_GROUPS non trovata")

    # Aggiungi l'import in _build_all_pages
    if 'accent_fix_page,' not in txt and 'accent_fix_page\n' not in txt:
        old_imp = 'raw_config,'
        new_imp = 'raw_config,\n            accent_fix_page,'
        if old_imp in txt:
            txt = txt.replace(old_imp, new_imp)
            changed = True
            ok("Aggiunto import di accent_fix_page")
        else:
            warn("Ancora per import non trovata")

    # Aggiungi al dict page_builders
    if '"accent_fix_page": accent_fix_page.AccentFixPage' not in txt:
        old_bld = '"raw_config": raw_config.RawConfigPage,'
        new_bld = old_bld + '\n            "accent_fix_page": accent_fix_page.AccentFixPage,'
        if old_bld in txt:
            txt = txt.replace(old_bld, new_bld)
            changed = True
            ok("Aggiunta pagina al dizionario di build")
        else:
            warn("Ancora per page_builders non trovata")

    if changed:
        shutil.copy(window_py, str(window_py) + ".bak")
        window_py.write_text(txt, encoding="utf-8")
        ok("window.py aggiornato con successo!")
    else:
        ok("window.py già completo — nessuna modifica necessaria.")

except PermissionError:
    fail("Permesso negato! Devi eseguire questo script con sudo.")

print(f"\n{BOLD}{G}  ✓ Installazione plugin completata!{N}")
print(f"  Riavvia NiriMod per vedere la sezione Accent Fix sotto Advanced.\n")
