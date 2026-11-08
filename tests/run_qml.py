#!/usr/bin/env python3
"""Run isolated Qt Quick tests with a minimal replacement for Omarchy's Style."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
runner = shutil.which('qmltestrunner') or shutil.which('qmltestrunner6')
if not runner:
    runner = next((str(p) for p in [Path('/usr/lib/qt6/bin/qmltestrunner'),
                                   Path('/usr/lib/qt6/qmltestrunner')]
                   if p.is_file()), None)
if not runner:
    sys.exit('Qt 6 qmltestrunner is required.')

with tempfile.TemporaryDirectory(prefix='omawallswitcher-test-') as directory:
    target = Path(directory)
    for name in ['WallpaperSurface.qml', 'TextSafety.js']:
        shutil.copy2(ROOT / name, target / name)
    shutil.copy2(ROOT / 'tests/tst_surface.qml', target / 'tst_surface.qml')
    module = target / 'qs/Commons'
    module.mkdir(parents=True)
    (module / 'qmldir').write_text('module qs.Commons\nsingleton Style 1.0 Style.qml\n')
    (module / 'Style.qml').write_text('pragma Singleton\nimport QtQuick\n'
                                    'QtObject { property bool animated: true; '
                                    'function duration(ms) { return animated ? ms : 0 } }\n')
    for name, width, height, color in [('red', 128, 128, b'\xff\x00\x00'),
                                       ('blue', 128, 128, b'\x00\x00\xff'),
                                       ('wide', 128, 64, b'\xff\x00\x00')]:
        (target / (name + '.ppm')).write_bytes(
            f'P6\n{width} {height}\n255\n'.encode() + color * width * height)
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
               QT_QPA_PLATFORMTHEME='generic')
    sys.exit(subprocess.call([runner, '-input', directory, '-import', directory], env=env))
