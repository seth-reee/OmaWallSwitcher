#!/usr/bin/env python3
"""Install the optional wallpaper bridge without changing authentication code."""
import argparse
from pathlib import Path
import shutil

MARKER = '  // OmaWallSwitcher optional per-monitor wallpapers.'
BRIDGE = '''  // OmaWallSwitcher optional per-monitor wallpapers.
  property var omaWallState: ({})
  property double omaWallNow: Date.now()
  FileView {
    path: Quickshell.env("XDG_RUNTIME_DIR") + "/omawallswitcher-lock-wallpapers.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try { root.omaWallState = JSON.parse(text()) }
      catch (error) { root.omaWallState = ({}) }
    }
    onLoadFailed: root.omaWallState = ({})
  }
  Timer {
    interval: 30000
    repeat: true
    running: true
    onTriggered: root.omaWallNow = Date.now()
  }
  function omaWallpaper(screen) {
    var state = omaWallState
    // A lease prevents a stopped or removed slideshow leaving stale wallpaper.
    var age = Math.max(Date.now(), omaWallNow) - Number(state.updated || 0)
    if (!screen || state.version !== 1 || age < 0 || age > 90000) return ""
    var path = state.monitors && state.monitors[screen.name]
    return typeof path === "string" && path.charAt(0) === "/" ? path : ""
  }
  function omaWallpaperUrl(screen) {
    var path = omaWallpaper(screen)
    return path ? "file://" + path.split("/").map(encodeURIComponent).join("/") : backgroundUrl
  }

'''


def patched(source):
    if MARKER in source:
        return source
    changes = [
        ('  property var shell: null\n', '  property var shell: null\n\n' + BRIDGE),
        ('backgroundUrl: root.locked && !root.sessionLockXray ? root.backgroundUrl : ""',
         'backgroundUrl: root.locked && !root.sessionLockXray ? root.omaWallpaperUrl(lockSurface.screen) : ""'),
        ('          backgroundPath: root.backgroundPath\n',
         '          backgroundPath: root.omaWallpaper(lockSurface.screen) || root.backgroundPath\n'),
        ('        backgroundPath: root.backgroundPath\n',
         '        backgroundPath: root.omaWallpaper(previewWindow.screen) || root.backgroundPath\n'),
    ]
    for old, new in changes:
        # Require the exact expected indentation; never patch an unknown layout.
        lines = source.splitlines(keepends=True)
        if old.endswith('\n'):
            if lines.count(old) != 1:
                raise ValueError('Unsupported Lock Explorer version: expected anchor missing or ambiguous: ' + old.strip())
            source = ''.join(new if line == old else line for line in lines)
        else:
            if source.count(old) != 1:
                raise ValueError('Unsupported Lock Explorer version: expected unlock layer missing.')
            source = source.replace(old, new)
    return source


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', nargs='?', type=Path,
                        default=Path.home() / '.config/omarchy/plugins/io.github.sirjul1337.lock-explorer')
    args = parser.parse_args()
    path = args.directory / 'Service.qml'
    original = path.read_text()
    result = patched(original)
    if result == original:
        print('Lock Explorer bridge already installed.')
        return
    backup = path.with_name('Service.qml.before-omawallswitcher')
    if backup.exists():
        raise SystemExit('Existing backup found; inspect it before applying to a new plugin version: ' + str(backup))
    shutil.copy2(path, backup)
    path.write_text(result)
    print('Installed Lock Explorer bridge; backup: ' + str(backup))


if __name__ == '__main__':
    main()
