#!/usr/bin/env python3
"""Short-lived helpers; the shell owns the single slideshow timer."""
import argparse
import html
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

CONFIG = Path.home() / '.config/omarchy/wallpaper-slideshow.json'
FIT_MODES = ('normal', 'vertical', 'horizontal', 'stretch')
EXTENSIONS = {'.jpg', '.jpeg', '.png', '.webp', '.bmp', '.avif'}


def images(folder):
    directory = Path(folder).expanduser().resolve()
    if not directory.is_dir():
        raise ValueError('Choose an existing wallpaper folder.')
    result = sorted((p for p in directory.iterdir()
                     if p.is_file() and p.suffix.lower() in EXTENSIONS),
                    key=lambda p: p.name)
    if not result:
        raise ValueError('No supported images in this folder.')
    return result


def load():
    if not CONFIG.exists():
        return {'folder': '', 'minutes': 5, 'paused': False}
    config = json.loads(CONFIG.read_text())
    if not isinstance(config, dict):
        raise ValueError('Invalid slideshow configuration: expected an object.')
    return config


def save(config):
    CONFIG.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(dir=CONFIG.parent, prefix='.slideshow-')
    try:
        with os.fdopen(fd, 'w') as output:
            json.dump(config, output, indent=2)
            output.write('\n')
        os.replace(temporary, CONFIG)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def dialog(*args):
    result = subprocess.run(['zenity', *args], capture_output=True, text=True)
    return result.stdout.rstrip('\n') if result.returncode == 0 else None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['configure', 'next', 'toggle', 'fit', 'lock-screen'])
    parser.add_argument('--enabled', choices=['true', 'false'])
    parser.add_argument('--fit', choices=FIT_MODES)
    parser.add_argument('--folder')
    parser.add_argument('--minutes', type=int)
    parser.add_argument('--current', default='')
    parser.add_argument('--screens', type=int, default=1)
    args = parser.parse_args()
    config = load()
    if args.action == 'configure':
        folder = args.folder
        if folder is None:
            folder = dialog('--file-selection', '--directory', '--title=Wallpaper folder',
                            '--filename=' + (config.get('folder') or str(Path.home())) + '/')
            if folder is None:
                return
        images(folder)
        minutes = args.minutes
        if minutes is None:
            value = dialog('--entry', '--title=OmaWallSwitcher',
                           '--text=Minutes between wallpapers (1–1440)',
                           '--entry-text=' + str(config.get('minutes', 5)))
            if value is None:
                return
            minutes = int(value)
        if not 1 <= minutes <= 1440:
            raise ValueError('Interval must be between 1 and 1440 minutes.')
        config.update({'folder': str(Path(folder).expanduser().resolve()), 'minutes': minutes, 'paused': False})
        save(config)
    elif args.action == 'lock-screen':
        if args.enabled is None:
            raise ValueError('Choose true or false with --enabled.')
        config['lockScreenSupport'] = args.enabled == 'true'
        save(config)
    elif args.action == 'fit':
        if args.fit is None:
            raise ValueError('Choose a fitting mode with --fit.')
        config['fit'] = args.fit
        save(config)
    elif args.action == 'toggle':
        config['paused'] = not config.get('paused', False)
        save(config)
    else:
        if not config.get('folder'):
            raise ValueError('Choose a wallpaper folder first.')
        files = images(config['folder'])
        current = Path(args.current) if args.current else None
        index = (files.index(current) + 1) % len(files) if current in files else 0
        selected = [str(files[(index + offset) % len(files)])
                    for offset in range(max(1, args.screens))]
        print(json.dumps({'paths': selected, 'count': len(files)}))


def report_error(error):
    print(str(error), file=sys.stderr)
    # notify-send bodies support markup; paths and decoder errors are plain text.
    try:
        subprocess.run(['notify-send', 'OmaWallSwitcher', html.escape(str(error))], check=False)
    except OSError:
        pass


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        report_error(error)
        sys.exit(1)
