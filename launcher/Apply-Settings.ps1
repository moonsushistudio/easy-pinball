# Writes one consistent set of VPX / PinMAME / B2S settings for a landscape
# monitor (plus an optional second one for the backglass), keyboard + mouse,
# and a near top-down camera.
param(
    [double]$Inclination = 25,   # legacy camera tilt in degrees (0 = straight down, VPX desktop default is ~50)
    [double]$FOV = 40,
    [double]$Layback = 0,
    [double]$DayNight = 0.8,    # room light on the table for every table: 0.1 = night ... 0.9 = daylight; tables default near 0.5
    # Table sound effects (flippers, ball, bumpers) in percent. PinMAME's music and speech
    # are already at its 0 dB maximum, so effects are turned down to balance them.
    [ValidateRange(0, 100)][int]$EffectsVolume = 50,
    # Where the backglass goes: Auto = the second screen if there is one, else beside the table.
    [ValidateSet('Auto', 'Beside', 'Second')][string]$Backglass = 'Auto'
)
. "$PSScriptRoot\PinballCommon.ps1"

# Tilt, brightness and effects volume keep what is already set (e.g. from the launcher's
# Settings screen) unless given on the command line; the defaults above are for a fresh setup.
$inv = [Globalization.CultureInfo]::InvariantCulture
$saved = @{
    Inclination   = Get-IniValue $VpxIni 'TableOverride' 'ViewDTLookAt'
    DayNight      = Get-IniValue $VpxIni 'Player' 'EmissionScale'
    EffectsVolume = Get-IniValue $VpxIni 'Player' 'SoundVolume'
}
foreach ($name in $saved.Keys) {
    $n = 0.0
    if (-not $PSBoundParameters.ContainsKey($name) -and [double]::TryParse($saved[$name], [Globalization.NumberStyles]::Float, $inv, [ref]$n)) {
        Set-Variable $name $(if ($name -eq 'EffectsVolume') { [int]$n } else { $n })
    }
}

$screen = Get-ScreenSize
$W = $screen.Width; $H = $screen.Height
$second = Get-Displays | Where-Object { -not $_.Primary } | Sort-Object Number | Select-Object -First 1
if ($Backglass -eq 'Second' -and -not $second) { Write-Warning 'No second screen found, so the backglass goes beside the table.' }
$onSecond = $second -and $Backglass -ne 'Beside'
New-Item -ItemType Directory -Force $BackupDir | Out-Null

# --- one-time backups of whatever was there before -----------------------
$iniBackup = Join-Path $BackupDir 'VPinballX.ini.original'
if (-not (Test-Path $iniBackup) -and (Test-Path $VpxIni)) { Copy-Item $VpxIni $iniBackup }
$regBackup = Join-Path $BackupDir 'VisualPinMame.original.reg'
if (-not (Test-Path $regBackup)) { & reg.exe export 'HKCU\Software\Freeware\Visual PinMame' $regBackup /y | Out-Null }
$resFile = Join-Path $TablesDir 'ScreenRes.txt'
$resBackup = Join-Path $BackupDir 'ScreenRes.txt.original'
if (-not (Test-Path $resBackup) -and (Test-Path $resFile)) { Copy-Item $resFile $resBackup }

# --- VPX player: borderless window covering the monitor ------------------
Set-IniValues $VpxIni 'Player' @{
    BGSet               = 0       # desktop view
    Display             = 0
    FullScreen          = 0       # borderless window, lets the DMD / backglass windows sit on top
    WindowPosX          = 0
    WindowPosY          = 0
    Width               = $W
    Height              = $H
    PlaySound           = 1
    PlayMusic           = 1
    SoundVolume         = $EffectsVolume
    # Mouse: left button = left flipper, right button = right flipper, middle button = plunger.
    EnableMouseInPlayer = 1
    JoyLFlipKey         = 25
    JoyRFlipKey         = 26
    JoyPlungerKey       = 27
    CaptureExternalDMD  = 0
    OverrideTableEmissionScale = 1
    EmissionScale       = $DayNight
    NumberOfTimesToShowTouchMessage = 0
}

# --- Camera: same near-overhead view for every table ---------------------
# Legacy mode auto-fits the whole table to the screen; LookAt is the tilt in degrees.
$view = @{}
foreach ($p in 'DT', 'FSS') {
    $view["View${p}Mode"]     = 0
    $view["View${p}LookAt"]   = $Inclination
    $view["View${p}FOV"]      = $FOV
    $view["View${p}Layback"]  = $Layback
    $view["View${p}Rotation"] = 0
    $view["View${p}ScaleX"]   = 1
    $view["View${p}ScaleY"]   = 1
    $view["View${p}ScaleZ"]   = 1
    $view["View${p}PlayerX"]  = 0
    $view["View${p}PlayerY"]  = 0
    $view["View${p}PlayerZ"]  = 0
}
Set-IniValues $VpxIni 'TableOverride' $view

# --- Screen layout: DMD on the left of the table, backglass on the right --
# A top-down table fills the middle ~third of a landscape screen.
$side   = [int]($W * 0.36)                 # free space beside the table
$margin = [int]($W * 0.012)
# DMD hugs the top-left corner: desktop-mode tables draw their own small DMD
# there, and this window sits on top of it so you only see one.
$dmdW = [int]($side * 0.97); $dmdH = [int]($dmdW / 4)
$dmd = @{ x = [int]($W * 0.005); y = [int]($H * 0.005); w = $dmdW; h = $dmdH }
$bgW = $side - 2 * $margin; $bgH = [int]($bgW * 3 / 4)
$bg  = @{ x = $W - $side + $margin; y = [int]($H * 0.06); w = $bgW; h = $bgH }

# DMD: PinMAME hands every frame to DmdDevice (the "virtual DMD" window), which
# shows up even on tables whose script hides PinMAME's own window. PinMAME's
# window stays off so there is never a second copy.
$dmdValues = @{
    showwindmd = 0; showpindmd = 1; cabinet_mode = 1; dmd_antialias = 50
    dmd_pos_x = $dmd.x; dmd_pos_y = $dmd.y; dmd_width = $dmd.w; dmd_height = $dmd.h
    dmd_doublesize = 0; sound = 1; samples = 1
}
# Per-ROM keys are copied from 'default' the first time a ROM runs, so update every one that exists.
$romKeys = Get-ChildItem $PinMameKey | Where-Object PSChildName -ne 'globals' | ForEach-Object PSChildName
foreach ($k in $romKeys) {
    foreach ($name in $dmdValues.Keys) { Set-ItemProperty "$PinMameKey\$k" $name $dmdValues[$name] -Type DWord }
}

$dmdIni = Join-Path $VPRoot 'VPinMAME\DmdDevice.ini'
$dmdIniBackup = Join-Path $BackupDir 'DmdDevice.ini.original'
if (-not (Test-Path $dmdIniBackup)) { Copy-Item $dmdIni $dmdIniBackup }
# The virtual DMD is a WPF window, so it is placed in Windows-scaled units, not pixels.
$scale = [MyPinball.Native]::GetDpiForSystem() / 96
Set-IniValues $dmdIni 'virtualdmd' @{
    enabled = 'true'; stayontop = 'true'; ignorear = 'false'; useregistry = 'false'; hideGrip = 'true'
    left = [int]($dmd.x / $scale); top = [int]($dmd.y / $scale)
    width = [int]($dmd.w / $scale); height = [int]($dmd.h / $scale)
}
Set-IniValues $dmdIni 'pinup' @{ enabled = 'false' }   # no PinUP Player in this setup

# B2S backglass (only used when a table has a .directb2s next to it). The display
# line is the n of \\.\DISPLAYn and the position is relative to that screen.
$res = if ($onSecond) { @($W, $H, $second.Width, $second.Height, $second.Number, 0, 0) }
       else { @($W, $H, $bg.w, $bg.h, 1, $bg.x, $bg.y) }
@($res + @(0, 0, 0, 0, 0)) | Set-Content $resFile -Encoding ascii

# --- Tidy the ROM folder: PinMAME wants the zips, not extracted files ----
$stray = Get-ChildItem $RomsDir | Where-Object { $_.Extension -ne '.zip' -and $_.Name -ne 'dir.txt' }
if ($stray) {
    $dest = Join-Path $BackupDir 'stray-rom-files'
    New-Item -ItemType Directory -Force $dest | Out-Null
    $stray | Move-Item -Destination $dest -Force
}

$where = if ($onSecond) { "on screen $($second.Number) ($($second.Width)x$($second.Height))" } else { 'beside the table' }
"Settings applied for ${W}x${H}: camera tilt $Inclination deg, FOV $FOV, backglass $where."
