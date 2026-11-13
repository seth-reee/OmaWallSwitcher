# OmaWallSwitcher

A lightweight wallpaper slideshow for Omarchy 4. Rotate images from a folder,
show a different wallpaper on each monitor, and switch fitting modes with smooth
transitions.

![OmaWallSwitcher controls](preview.png)

## Install

Uses Omarchy's bundled Quickshell, Python 3, Python GObject bindings, and
XDG desktop portal. No additional dialog package or manual setup is required.
Folder selection uses your system's configured file chooser.

```sh
omarchy plugin add https://github.com/seth-reee/OmaWallSwitcher.git --enable
```

Choose the `right` bar section when prompted. Click the wallpaper icon, then
**Choose folder…** to select your images. Type the rotation interval in
**Minutes between wallpapers** (1–1440, default: five minutes). Press Enter or
leave the field to save.

Images cycle in filename order. Add images directly to the selected folder;
subfolders are not included. Supported formats are JPG, JPEG, PNG, WebP, BMP,
and AVIF, depending on your installed Qt image plugins.

## Controls

| Action | Result |
| --- | --- |
| Left-click the bar icon | Open slideshow controls |
| Middle-click the bar icon | Pause or resume |
| Right-click the bar icon | Open the system folder picker |
| Double-left-click empty desktop | Next image on all monitors, even while paused |
| Double-right-click empty desktop | Open Omarchy's theme selector |

The popup includes folder selection, an editable rotation interval, pause/resume,
next image, and four fitting modes:

| Fitting | Behavior |
| --- | --- |
| Normal | Fill the screen, preserving proportions and cropping edges |
| Fit vertical | Match screen height and center horizontally |
| Fit horizontal | Match screen width and center vertically |
| Stretch | Fill the screen without preserving proportions |

Vertical and horizontal fitting add black bars or crop overflow as needed.
Settings apply to all monitors and are saved across restarts. The slideshow
restarts from the first filename when the shell restarts.

## Optional Lock Explorer support

With [Lock Explorer](https://github.com/SirJul1337/omarchy-lock-explorer), each
monitor's lock screen can show its current slideshow wallpaper, including during
the unlock fade.

After installing both plugins, install the compatibility bridge:

```sh
python3 ~/.config/omarchy/plugins/seth.wallpaper-slideshow/integrations/lock-explorer.py
omarchy restart shell
```

Then turn on **Lock Explorer wallpapers** in the OmaWallSwitcher popup.
This option is off by default. Without it, the lock screen uses the normal theme
wallpaper.

Lock Explorer keeps its own cropping, blur, and dim settings. Designs without a
wallpaper stay as designed. If a slideshow wallpaper is unavailable, the lock
screen falls back to the theme wallpaper.

The bridge backs up Lock Explorer's `Service.qml` as
`Service.qml.before-omawallswitcher`. Lock Explorer updates may overwrite the
bridge. After updating, move the old backup out of the plugin folder and rerun
the command above. To stop using slideshow wallpapers, turn off the option.

## Update or remove

Update:

```sh
omarchy plugin update seth.wallpaper-slideshow
omarchy restart shell
```

Disable to reveal the normal Omarchy wallpaper:

```sh
omarchy plugin disable seth.wallpaper-slideshow
```

Remove:

```sh
omarchy plugin remove seth.wallpaper-slideshow
```

Your image folder is never modified. Saved preferences remain in
`~/.config/omarchy/wallpaper-slideshow.json` and can be deleted separately.

## Credits and license

[MIT](LICENSE). Reveal geometry and theme-selector integration adapted from
[Omarchy](https://github.com/basecamp/omarchy). Inspired by
[Omawall](https://github.com/matjam/omawall) and
[wallpaper-omarchy-manager](https://github.com/guiestrela/wallpaper-omarchy-manager).
