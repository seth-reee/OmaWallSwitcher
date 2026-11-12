"""Check the optional third-party patch fails safely and settings persist."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('bridge', ROOT / 'integrations/lock-explorer.py')
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)


class BridgeTests(unittest.TestCase):
    def test_patch_and_repeat(self):
        source = ('  property var shell: null\n'
                  '        backgroundUrl: root.locked && !root.sessionLockXray ? root.backgroundUrl : ""\n'
                  '          backgroundPath: root.backgroundPath\n'
                  '        backgroundPath: root.backgroundPath\n'
                  '  function authenticate() { return pam.start() }\n')
        result = bridge.patched(source)
        self.assertIn('root.omaWallpaper(lockSurface.screen) || root.backgroundPath', result)
        self.assertIn('root.omaWallpaper(previewWindow.screen) || root.backgroundPath', result)
        self.assertIn('root.omaWallpaperUrl(lockSurface.screen)', result)
        self.assertIn('  function authenticate() { return pam.start() }', result)
        self.assertEqual(bridge.patched(result), result)

    def test_unknown_version_is_rejected(self):
        with self.assertRaises(ValueError):
            bridge.patched('  property var shell: null\n')

    def test_ambiguous_version_is_rejected(self):
        with self.assertRaises(ValueError):
            bridge.patched('  property var shell: null\n' * 2)
