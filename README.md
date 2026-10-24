<p align="center">
  <img src="assets/icon.png" width="128" alt="Easy Pinball icon: a steel ball above two gold flippers">
</p>

<h1 align="center">Easy Pinball</h1>

<p align="center">
  A simple, full-screen game picker and table manager for
  <a href="https://github.com/vpinball/vpinball">Visual Pinball X</a> on Windows.
</p>

---

Easy Pinball is for playing virtual pinball at a desk: one landscape monitor (plus an
optional second one for the backglass), keyboard and mouse, and a near top-down view of
the table. Pick a game, press Enter, play, quit, and you're back in the list with your
score saved.

- **One-screen game picker**: big cards, arrow keys + Enter, or double-click.
- **Find and add tables**: search about 2,300 machines from the
  [Virtual Pinball Spreadsheet](https://virtualpinballspreadsheet.github.io/), open the
  best download page, and import what you downloaded.
- **Import from Downloads**: tables, backglasses, music and ROMs are copied to the right
  folders, zipped or not.
- **Your scores**: best and last score per game, read from the machine's own memory after
  each game.
- **Settings screen**: brightness, camera tilt, effects volume and music volume for every
  table.
- **Sane defaults**: one consistent VPX / PinMAME / DMD / backglass setup, with your
  original settings backed up first.

Easy Pinball does **not** include any tables, ROMs or artwork. See
[Tables and ROMs](#tables-and-roms).

## Requirements

- Windows 10 or 11 (uses the built-in Windows PowerShell 5.1 and .NET Framework, so
  there's nothing else to install)
- [Visual Pinball X](https://github.com/vpinball/vpinball/releases) 10.8 or newer, 64-bit,
  with VPinMAME. The B2S Backglass Server is optional, for backglasses.

Easy Pinball expects VPX in `C:\vPinball\VisualPinball` (the folder that has
`VPinballX64.exe`). If yours is somewhere else, set the `EASYPINBALL_VPX_DIR` environment
variable to that folder.

## Getting started

1. Download this repository (**Code > Download ZIP**, then unzip it) or clone it:

   ```
   git clone https://github.com/moonsushistudio/easy-pinball.git
   ```

2. Create the desktop shortcut:

   ```
   powershell -ExecutionPolicy Bypass -File Install-Shortcut.ps1
   ```

3. Optional, recommended: apply the Easy Pinball settings to VPX and PinMAME (see
   [What Apply-Settings changes](#what-apply-settings-changes)):

   ```
   powershell -ExecutionPolicy Bypass -File launcher\Apply-Settings.ps1
   ```

4. Start **Easy Pinball** from the desktop.

## Controls

| Key / button | Action |
|---|---|
| Left Shift / left mouse button | Left flipper |
| Right Shift / right mouse button | Right flipper |
| Enter / middle mouse button | Plunger |
| 5 | Insert coin |
| 1 | Start game |
| Space | Nudge (Z / slash nudge left / right) |
| Left / Right Ctrl | Magna-save on tables that have it. On many others it cycles the table's color filter, which the table remembers. If a table looks black and white or oddly tinted, tap Left/Right Ctrl during play until it looks right. |
| F12 | Table options and point-of-view adjustment (saved per table) |
| Q | Menu, then **Quit to Editor** returns you to Easy Pinball |

In the launcher: arrow keys and Enter to pick and play, Ctrl+F to add a table, Esc to close.

## Adding a game

1. Press **Add a table** (or Ctrl+F), type part of a name and press Enter. The list comes
   from the Virtual Pinball Spreadsheet, downloaded to `launcher\vpsdb.json` and refreshed
   once a week. The game is added to `launcher\games.json`.
2. Select a game marked **NEEDS TABLE** and press **Find table**. This opens the download
   page of the best version (VPW builds first). Download it and leave it in Downloads,
   zipped or not.
3. If it then says **NEEDS ROM**, press **Find ROM** and download the ROM zip it names.
   Keep it zipped.
4. Press **Import from Downloads**. Tables, backglasses, music and ROMs are copied to the
   right folders. Files already imported are skipped. A backglass downloaded on its own is
   renamed to match its table, which is how the backglass program finds it.

**Remove from my list** takes a game off the list (an installed table stays installed and
shows up as an extra). Any `.vpx` in the Tables folder shows up even if it's not on the
list.

`launcher\games.json` ships with a starter list of classics. Edit it by hand or through
the launcher.

## Scores

After each game the launcher reads the score from the machine's saved memory (PinMAME
NVRAM, `VPinMAME\nvram\<rom>.nv`) and keeps your best and last score per game in
`scores.json`. The machine's own grand champion is shown next to it.

- Works for the ROM-based (Williams/Bally WPC) games.
- Original tables (no ROM) only keep their own high-score board (VPX's `User\VPReg.stg`).
  Any new entry on that board after you play counts as your score. A game that doesn't
  make the board is counted, but its score isn't known.
- If you quit mid-game, the score at that moment counts.
- For a newly added game, finish one game (play to Game Over) before quitting mid-game
  counts. That first finished game is how the launcher learns where the score is stored
  (`launcher\score-offsets.json`).

## Settings

The **Settings** button sets brightness (room light, Night to Daylight), camera tilt
(0 = straight down), sound effects volume (flippers, ball, bumpers) and music and voices
volume for every table, from the next table you start.

Music and voices is PinMAME's volume for every ROM plus VPX's music volume for tables
without a ROM, on a hearing scale (50% is half as loud). 100% is PinMAME's normal
maximum; up to 200% (+6 dB) is a boost, which PinMAME warns may crackle on the loudest
moments. Back it off if you hear that.

Sound effects: Visual Pinball 10.8.0 (the installed version) plays flippers, ball and
bumpers at full volume for any setting above 0
([vpinball#1903](https://github.com/vpinball/vpinball/issues/1903), fixed in 10.8.1), so on
10.8.0 this is an Off / On switch. To hear music and voices over the effects, turn music
above 100% and your PC volume down. On a newer Visual Pinball it becomes a slider again,
down to 10% (VPX's quietest, 20 dB down) and Off.

A table with its own setting keeps it (anything you change with F12 during play is saved
for that table); the Settings screen lists those tables.

## What Apply-Settings changes

`launcher\Apply-Settings.ps1` writes one consistent setup and can be re-run any time (do
that after changing monitors). Tilt, brightness and effects volume keep their current
values (such as those saved from the Settings screen) unless you pass them.

| Option | Meaning |
|---|---|
| `-Inclination` | Camera tilt in degrees, default 25 (0 is straight down) |
| `-FOV` | Field of view, default 40 |
| `-DayNight` | Room light for every table, default 0.8 |
| `-EffectsVolume` | Table sound effects in percent on the same hearing scale as the Settings slider, default 50 (half as loud). On VPX 10.8.0 anything above 0 plays at full volume |
| `-Backglass Auto\|Beside\|Second` | Default Auto: the backglass fills the second screen if there is one, otherwise it sits beside the table |

What it touches:

- `%APPDATA%\VPinballX\VPinballX.ini`: desktop view, a borderless window the size of your
  screen, mouse flippers, and one camera for every table.
- DMD: every ROM's display goes to the virtual DMD window (`VPinMAME\DmdDevice.ini`) in
  the top-left corner, so it shows even on tables that hide PinMAME's own window.
  PinMAME's window is turned off (registry) so there's only one copy.
- `Tables\ScreenRes.txt`: the backglass, if a table has one, goes on the right side of the
  screen or fills the second screen. The table and DMD stay on the main screen.
- Loose files unzipped into `VPinMAME\roms` are moved to `backup\stray-rom-files`
  (PinMAME wants the zips).

Some tables also draw a DMD inside the 3D scene, which lands on top of the playfield in a
top-down view. When a table has an option for it, the launcher turns it off in that
table's `.ini` before the first play. Change it back with F12 if you like.

The first run saves your originals to `backup\` (`VPinballX.ini.original`,
`VisualPinMame.original.reg`, `ScreenRes.txt.original`, `DmdDevice.ini.original`). To undo,
copy them back and import the `.reg` file.

## Project layout

```
Install-Shortcut.ps1       creates the desktop shortcut
assets/                    the icon, and Make-Icon.ps1 that draws it
launcher/
  EasyPinball.ps1          the launcher window (WPF)
  PinballCommon.ps1        paths, table scanning, importing, scores, settings
  Apply-Settings.ps1       one-time / re-runnable VPX + PinMAME setup
  *.cs                     small helpers: displays, high scores, VPS database, .vpx scanning
  games.json               your game list
```

Files made on your PC (`scores.json`, `media\`, `backup\`, and the caches in `launcher\`)
are not part of the repository.

## Tables and ROMs

Easy Pinball is only a launcher. It contains no pinball tables, ROMs, backglasses or
artwork, and it doesn't download any by itself: it opens the download pages in your
browser and you choose what to download. Tables are made by the virtual pinball community
and shared on sites such as [VPUniverse](https://vpuniverse.com/) and
[VPForums](https://www.vpforums.org/). Pinball machine ROMs are copyrighted by their
owners; make sure you have the right to use any ROM you download.

## Credits

- [Visual Pinball X](https://github.com/vpinball/vpinball) and
  [PinMAME](https://github.com/vpinball/pinmame), which do all the real work.
- The [Virtual Pinball Spreadsheet](https://virtualpinballspreadsheet.github.io/) for the
  table database.
- The table authors of the virtual pinball community.

Pinball machine names and trademarks belong to their owners. Easy Pinball isn't
affiliated with or endorsed by any of them, or by the Visual Pinball project.

The Easy Pinball icon is original artwork, drawn in code by
[`assets/Make-Icon.ps1`](assets/Make-Icon.ps1), and is covered by the same license as the
rest of the project.

## License

[MIT](LICENSE) © 2026 Moon Sushi Studio
