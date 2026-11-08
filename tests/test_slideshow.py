"""Exercise the helper without touching the user's configuration."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('slideshow', ROOT / 'slideshow.py')
slideshow = importlib.util.module_from_spec(spec)
spec.loader.exec_module(slideshow)


class SlideshowTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.folder = Path(self.temporary.name)
        config_patch = patch.object(slideshow, 'CONFIG', self.folder / 'settings.json')
        config_patch.start()
        self.addCleanup(config_patch.stop)

    def run_action(self, *args):
        output = io.StringIO()
        with patch.object(sys, 'argv', ['slideshow.py', *args]), contextlib.redirect_stdout(output):
            slideshow.main()
        return output.getvalue()

    def populate(self):
        names = ['a image.JPG', 'b#image.png', 'c<image>.webp']
        for name in names:
            (self.folder / name).touch()
        (self.folder / 'notes.txt').touch()
        (self.folder / 'nested.jpg').mkdir()
        return [str(self.folder / name) for name in names]

    def test_selection_order_wrap_and_multiple_monitors(self):
        paths = self.populate()
        slideshow.save({'folder': str(self.folder)})
        selected = json.loads(self.run_action('next', '--screens', '2'))
        self.assertEqual(selected, {'paths': paths[:2], 'count': 3})
        selected = json.loads(self.run_action('next', '--current', paths[-1], '--screens', '4'))
        self.assertEqual(selected['paths'], paths + paths[:1])
        (self.folder / 'd.avif').touch()
        self.assertEqual(json.loads(self.run_action('next'))['count'], 4)

    def test_fit_survives_folder_changes_and_toggle(self):
        self.populate()
        slideshow.save({'folder': str(self.folder), 'minutes': 5, 'paused': True})
        for mode in slideshow.FIT_MODES:
            self.run_action('fit', '--fit', mode)
            self.assertEqual(slideshow.load()['fit'], mode)
            self.assertTrue(slideshow.load()['paused'])
        self.run_action('configure', '--folder', str(self.folder), '--minutes', '10')
        self.assertEqual(slideshow.load()['fit'], 'stretch')
        self.run_action('toggle')
        self.assertTrue(slideshow.load()['paused'])
        self.assertEqual(slideshow.load()['minutes'], 10)

    def test_invalid_input_does_not_replace_configuration(self):
        self.populate()
        slideshow.save({'folder': str(self.folder), 'fit': 'normal'})
        before = slideshow.CONFIG.read_bytes()
        with self.assertRaises(ValueError):
            self.run_action('configure', '--folder', str(self.folder), '--minutes', '0')
        self.assertEqual(slideshow.CONFIG.read_bytes(), before)
        with self.assertRaises(ValueError):
            self.run_action('fit')
        slideshow.CONFIG.write_text('[]')
        with self.assertRaisesRegex(ValueError, 'expected an object'):
            slideshow.load()

    def test_error_notification_treats_filenames_as_plain_text(self):
        error = ValueError('<img src="https://example.invalid/a"> & wallpaper')
        with patch.object(slideshow.subprocess, 'run') as notify, contextlib.redirect_stderr(io.StringIO()):
            slideshow.report_error(error)
        body = notify.call_args.args[0][-1]
        self.assertNotIn('<', body)
        self.assertIn('&lt;img', body)
        self.assertIn('&amp; wallpaper', body)
        with patch.object(slideshow.subprocess, 'run', side_effect=FileNotFoundError), contextlib.redirect_stderr(io.StringIO()):
            slideshow.report_error(error)

    def test_missing_and_empty_folders(self):
        with self.assertRaises(ValueError):
            self.run_action('next')
        with self.assertRaises(ValueError):
            slideshow.images(self.folder / 'missing')
        with self.assertRaises(ValueError):
            slideshow.images(self.folder)


if __name__ == '__main__':
    unittest.main()
