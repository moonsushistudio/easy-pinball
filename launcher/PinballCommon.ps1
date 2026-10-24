# Shared paths and helpers for Easy Pinball.
$ErrorActionPreference = 'Stop'

$script:Root       = Split-Path -Parent $PSScriptRoot          # the Easy Pinball folder
$script:LauncherDir = $PSScriptRoot
# Set EASYPINBALL_VPX_DIR when Visual Pinball X is installed somewhere else.
$script:VPRoot     = if ($env:EASYPINBALL_VPX_DIR) { $env:EASYPINBALL_VPX_DIR } else { 'C:\vPinball\VisualPinball' }
$script:VPX        = Join-Path $VPRoot 'VPinballX64.exe'
$script:TablesDir  = Join-Path $VPRoot 'Tables'
$script:RomsDir    = Join-Path $VPRoot 'VPinMAME\roms'
$script:VpxIni     = Join-Path $env:APPDATA 'VPinballX\VPinballX.ini'
$script:MediaDir   = Join-Path $Root 'media'
$script:BackupDir  = Join-Path $Root 'backup'
$script:GamesFile  = Join-Path $LauncherDir 'games.json'
$script:PinMameKey = 'HKCU:\Software\Freeware\Visual PinMame'

Add-Type -Namespace MyPinball -Name Native -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
[DllImport("user32.dll")] public static extern int GetSystemMetrics(int nIndex);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
[DllImport("user32.dll")] public static extern uint GetDpiForSystem();
'@ -ErrorAction SilentlyContinue
[void][MyPinball.Native]::SetProcessDPIAware()

function Get-ScreenSize {
    # Physical pixels of the primary monitor (SM_CXSCREEN / SM_CYSCREEN once DPI aware).
    [pscustomobject]@{ Width = [MyPinball.Native]::GetSystemMetrics(0); Height = [MyPinball.Native]::GetSystemMetrics(1) }
}

function Get-Displays {
    Add-Type -Path (Join-Path $PSScriptRoot 'Displays.cs') -ErrorAction SilentlyContinue
    [MyPinball.Displays]::All()
}

function Get-Games {
    # Assigning first unrolls the array (PowerShell 5 emits a JSON array as one object).
    $games = Get-Content $GamesFile -Raw | ConvertFrom-Json
    $games
}

function Save-Games($Games) {
    # One game per line keeps the file easy to read and edit by hand.
    $lines = @($Games | ForEach-Object { '  ' + ($_ | ConvertTo-Json -Compress -Depth 4) })
    "[`n" + ($lines -join ",`n") + "`n]" | Set-Content $GamesFile -Encoding utf8
}

# --- Finding tables: the Virtual Pinball Spreadsheet database ---------------
$script:VpsDbFile = Join-Path $LauncherDir 'vpsdb.json'
$script:VpsDbUrl  = 'https://virtualpinballspreadsheet.github.io/vps-db/db/vpsdb.json'
$script:CardColors = '#2f9e44', '#c2410c', '#6d28d9', '#334155', '#15803d', '#b45309', '#a16207', '#be123c', '#db2777', '#0e7490'

function Open-VpsDb {
    # Downloaded again once a week; an older copy is fine when offline.
    if ($script:VpsLoaded) { return }
    $have = Test-Path $VpsDbFile
    if (-not $have -or (Get-Item $VpsDbFile).LastWriteTime -lt (Get-Date).AddDays(-7)) {
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
            $tmp = "$VpsDbFile.download"
            [Net.WebClient]::new().DownloadFile($VpsDbUrl, $tmp)
            Move-Item $tmp $VpsDbFile -Force
        } catch {
            if (-not $have) { throw "Couldn't download the table list ($($_.Exception.InnerException.Message))" }
        }
    }
    Add-Type -Path (Join-Path $PSScriptRoot 'VpsDb.cs') -ReferencedAssemblies System.Web.Extensions -ErrorAction SilentlyContinue
    [void][MyPinball.VpsDb]::Load($VpsDbFile)
    $script:VpsLoaded = $true
    Add-VpsLinks
}

function Add-VpsLinks {
    # Hand-written games.json entries get the same direct download links as games added
    # from the database; their own title, blurb, colour, match and ROMs are kept.
    $games = @(Get-Games)
    $added = 0
    foreach ($g in $games | Where-Object { -not $_.vps }) {
        $v = Find-VpsGames ((Get-TitleWords $g.title) -join ' ') | Where-Object { Find-ListedGame $_ @($g) } | Select-Object -First 1
        if (-not $v) { continue }
        $g | Add-Member -Force -NotePropertyMembers @{ vps = $v.Id; tableUrl = $v.TableUrl; tableBy = $v.TableBy; romUrls = $v.RomUrls; b2sUrl = $v.B2sUrl }
        $added++
    }
    if ($added) { Save-Games $games }
}

function Find-VpsGames([string]$Query) { [MyPinball.VpsDb]::Search($Query, 60) }

function Get-TitleWords([string]$Title) {
    # Lower-case words of the main title: "The Addams Family" -> addams, family;
    # "Indiana Jones - The Pinball Adventure" -> indiana, jones (files often drop the subtitle).
    $main = ($Title -split '\s+-\s+|:')[0]
    $words = @($main.ToLower() -split '[^a-z0-9]+' | Where-Object { $_ })
    if ($words.Count -gt 1 -and $words[0] -eq 'the') { $words = $words[1..($words.Count - 1)] }
    $words
}

function Find-ListedGame($Vps, $Games) {
    # The games.json entry for a database machine: added from it, or the same title and year.
    $key = (Get-TitleWords $Vps.Name) -join ' '
    $Games | Where-Object { $_.vps -eq $Vps.Id -or (((Get-TitleWords $_.title) -join ' ') -eq $key -and $_.year -eq $Vps.Year) } | Select-Object -First 1
}

function Add-GameFromVps($Vps) {
    # Adds a machine from the database to games.json and returns its id.
    $games = @(Get-Games)
    $same = Find-ListedGame $Vps $games
    if ($same) { return $same.id }
    $words = @(Get-TitleWords $Vps.Name)
    $id = (-join $words) + $Vps.Year
    for ($n = 2; $games.id -contains $id; $n++) { $id = (-join $words) + $Vps.Year + "-$n" }
    $kind = @{ SS = 'Solid state'; EM = 'Electro-mechanical'; PM = 'Pure mechanical'; DG = 'Digital' }[$Vps.Type]
    $blurb = @(
        (@($kind, $Vps.Mpu) | Where-Object { $_ }) -join ', '
        if ($Vps.Designers) { "Designed by $($Vps.Designers)" }
        if ($Vps.Themes) { "Themes: $($Vps.Themes)" }
    ) | Where-Object { $_ }
    if (-not $blurb) { $blurb = "$($Vps.Maker), $($Vps.Year)" }
    $games += [pscustomobject]@{
        id = $id; title = $Vps.Name; maker = $Vps.Maker; year = $Vps.Year
        match = $words -join '\W*'; roms = @($Vps.Roms)
        blurb = ($blurb -join '. ') + '.'; color = $CardColors[[Math]::Abs($id.GetHashCode()) % $CardColors.Count]
        vps = $Vps.Id; tableUrl = $Vps.TableUrl; tableBy = $Vps.TableBy; romUrls = $Vps.RomUrls; b2sUrl = $Vps.B2sUrl
    }
    Save-Games $games
    $id
}

function Remove-Game([string]$Id) {
    Save-Games @(Get-Games | Where-Object { $_.id -ne $Id })
}

Add-Type -Path (Join-Path $PSScriptRoot 'VpxScan.cs') -ErrorAction SilentlyContinue

# Calibration / physics demo tables that ship with the installer; not games.
$script:HiddenTables = 'Elasticity|Calibration|Rubber objects|AutoSave|^blankTable|^exampleTable'
$script:ScanCacheFile = Join-Path $LauncherDir 'scan-cache.json'

function Get-TableInfo([IO.FileInfo]$File) {
    # Reading a 300 MB table takes ~1 s, so remember results by path + size + date.
    if (-not $script:ScanCache) {
        $script:ScanCache = @{}
        if (Test-Path $ScanCacheFile) {
            # Entries from an older scanner (another vN| prefix) are dropped and scanned again.
            (Get-Content $ScanCacheFile -Raw | ConvertFrom-Json).PSObject.Properties | Where-Object Name -like 'v3|*' |
                ForEach-Object { $script:ScanCache[$_.Name] = $_.Value }
        }
    }
    $key = "v3|$($File.FullName)|$($File.Length)|$($File.LastWriteTimeUtc.Ticks)"
    if (-not $script:ScanCache.ContainsKey($key)) {
        $info = [MyPinball.VpxScan]::Scan($File.FullName)
        $script:ScanCache[$key] = [pscustomobject]@{
            GameName = $info.GameName; UsesPinMame = $info.UsesPinMame
            DmdOption = $info.DmdOption; DmdOffValue = $info.DmdOffValue
        }
        $script:ScanCache | ConvertTo-Json | Set-Content $ScanCacheFile -Encoding utf8
    }
    $script:ScanCache[$key]
}

function Set-TableDefaults([IO.FileInfo]$File) {
    # The DMD shows in its own window (top-left), so switch off the copy some tables
    # draw inside the 3D scene; from straight above it lands on top of the playfield.
    # Only set when absent, so a choice made in the F12 menu sticks.
    $info = Get-TableInfo $File
    if (-not $info.DmdOption) { return }
    $ini = [IO.Path]::ChangeExtension($File.FullName, '.ini')
    $pattern = "^\s*$([regex]::Escape($info.DmdOption))\s*="
    if ((Test-Path $ini) -and (Select-String -Path $ini -Pattern $pattern -Quiet)) { return }
    Set-IniValues $ini 'TableOption' @{ $info.DmdOption = $info.DmdOffValue }
}

# --- Scores -----------------------------------------------------------------
Add-Type -Path (Join-Path $PSScriptRoot 'HighScores.cs') -ErrorAction SilentlyContinue
$script:ScoresFile = Join-Path $Root 'scores.json'
$script:OffsetsFile = Join-Path $LauncherDir 'score-offsets.json'

function Get-RomScores([string]$Rom) {
    # The machine's own high-score board and the last game's score, read from PinMAME's NVRAM.
    $nv = Join-Path $VPRoot "VPinMAME\nvram\$Rom.nv"
    if (-not $Rom -or -not (Test-Path $nv)) { return $null }
    $blocks = @([MyPinball.HighScores]::Read($nv))
    $main = $blocks | Where-Object { $_.Entries.Count -ge 3 } | Sort-Object { $_.Entries.Count } -Descending | Select-Object -First 1
    if (-not $main) { return $null }
    # The grand champion is a one-entry block stored right after the main board.
    $mainEnd = $main.Offset + $main.Entries.Count * $main.EntrySize + 2
    $champ = $blocks | Where-Object { $_.Entries.Count -eq 1 -and $_.Offset -ge $mainEnd -and $_.Offset -le $mainEnd + 4 } | Select-Object -First 1
    # Where the player scores live is learned once per ROM (see ReadLastScores).
    $offsets = @{}
    if (Test-Path $OffsetsFile) { (Get-Content $OffsetsFile -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $offsets[$_.Name] = [int]$_.Value } }
    $known = if ($offsets.ContainsKey($Rom)) { $offsets[$Rom] } else { -1 }
    $at = -1
    $last = [MyPinball.HighScores]::ReadLastScores($nv, $main.EntrySize - 3, $known, [ref]$at)
    if ($at -ge 0 -and $at -ne $known) {
        $offsets[$Rom] = $at
        $offsets | ConvertTo-Json | Set-Content $OffsetsFile -Encoding utf8
    }
    [pscustomobject]@{
        Champion = if ($champ) { $champ.Entries[0] } else { $null }
        Board    = @($main.Entries)
        Last     = if ($last) { ($last | Measure-Object -Maximum).Maximum } else { 0 }
        Saved    = (Get-Item $nv).LastWriteTime
    }
}

$script:SavedValuesFile = Join-Path $VPRoot 'User\VPReg.stg'

function Get-SavedScores([string]$Store) {
    # Original tables (no ROM) keep their board with VPX's SaveValue, as HighScore1..n
    # and HighScore1Name..n under the table's name, which is usually its cGameName.
    if (-not $Store) { return $null }
    $all = [MyPinball.SavedValues]::Read($SavedValuesFile)
    if (-not $all.ContainsKey($Store)) { return $null }
    $v = $all[$Store]
    $inv = [Globalization.CultureInfo]::InvariantCulture
    $board = @(for ($i = 1; $v.ContainsKey("HighScore$i"); $i++) {
        $n = 0.0
        if (-not [double]::TryParse($v["HighScore$i"], [Globalization.NumberStyles]::Float, $inv, [ref]$n)) { break }
        [MyPinball.ScoreEntry]@{ Initials = "$($v["HighScore${i}Name"])".Trim(); Score = [long]$n }
    })
    if (-not $board) { return $null }
    $games = 0
    [pscustomobject]@{
        Kind     = 'Saved'
        Champion = $board | Sort-Object Score -Descending | Select-Object -First 1
        Board    = $board
        Last     = 0
        Games    = if ([int]::TryParse("$($v['TotalGamesPlayed'])", [ref]$games)) { $games } else { $null }
        Saved    = (Get-Item $SavedValuesFile).LastWriteTime
    }
}

function Get-MachineScores([string]$Rom) {
    $s = Get-RomScores $Rom
    if (-not $s) { $s = Get-SavedScores $Rom }
    $s
}

function Test-FactoryScore($Entry) {
    # Factory boards use names like AAA / BBB and round scores.
    $Entry.Initials -match '^\s*$|^(.)\1*$' -or $Entry.Score % 100000 -eq 0
}

function Get-ScoreBook {
    $book = @{}
    if (Test-Path $ScoresFile) {
        (Get-Content $ScoresFile -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $book[$_.Name] = $_.Value }
    }
    $book
}

function Update-ScoreBook([string]$Id, [string]$Rom, [switch]$JustPlayed) {
    # Remembers your best and last score per game. After a game, a changed last score
    # means a new game was played; on first sight we seed from whatever NVRAM holds.
    $s = Get-MachineScores $Rom
    if (-not $s) { return }
    $book = Get-ScoreBook
    $e = $book[$Id]
    $today = (Get-Date).ToString('yyyy-MM-dd')
    if ($s.Kind -eq 'Saved') {
        # These tables only keep their high-score board, so a game is only seen when
        # it makes the board: new entries since last time (Seen) are yours.
        $seen = ($s.Board | ForEach-Object { "$($_.Score)|$($_.Initials)" }) -join ';'
        if (-not $e) {
            $yours = @($s.Board | Where-Object { -not (Test-FactoryScore $_) })
            $best = if ($yours) { [long]($yours | Measure-Object Score -Maximum).Maximum } else { 0 }
            $e = [pscustomobject]@{ Best = $best; BestDate = $s.Saved.ToString('yyyy-MM-dd'); Last = 0; LastDate = $null; Games = $s.Games; Seen = $seen }
        } elseif ($JustPlayed) {
            $old = [Collections.Generic.List[string]]@("$($e.Seen)" -split ';')
            $new = @($s.Board | Where-Object { -not $old.Remove("$($_.Score)|$($_.Initials)") })
            if (-not $new -and $s.Games -eq $e.Games) { return }
            $e.Seen = $seen; $e.LastDate = $today
            $e.Games = if ($null -ne $s.Games) { $s.Games } else { [int]$e.Games + 1 }
            # 0 = the game didn't make the board, so its score isn't known.
            $e.Last = if ($new) { [long]($new | Measure-Object Score -Maximum).Maximum } else { 0 }
            if ($e.Last -gt $e.Best) { $e.Best = $e.Last; $e.BestDate = $today }
        } else { return }
    } elseif (-not $e) {
        if ($s.Last -le 0) { return }
        $e = [pscustomobject]@{ Best = $s.Last; BestDate = $s.Saved.ToString('yyyy-MM-dd'); Last = $s.Last; LastDate = $s.Saved.ToString('yyyy-MM-dd'); Games = 1; Seen = $s.Last }
    } elseif ($JustPlayed -and $s.Last -gt 0 -and $s.Last -ne $(if ($e.Seen) { $e.Seen } else { $e.Last })) {
        # Seen = the score NVRAM held last time we looked; unchanged means no new game.
        $e | Add-Member -Force Seen $s.Last
        $e.Last = $s.Last; $e.LastDate = $today; $e.Games = [int]$e.Games + 1
        if ($s.Last -gt $e.Best) { $e.Best = $s.Last; $e.BestDate = $today }
    } else { return }
    $book[$Id] = $e
    $book | ConvertTo-Json | Set-Content $ScoresFile -Encoding utf8
}

function Test-Rom([string]$Name) {
    $Name -and ((Test-Path (Join-Path $RomsDir "$Name.zip")) -or (Test-Path (Join-Path $RomsDir "$Name.7z")))
}

function Get-Library {
    # One entry per curated game (installed or not) plus any other tables found.
    $tables = @(Get-ChildItem $TablesDir -Filter *.vpx | Where-Object { $_.BaseName -notmatch $HiddenTables })
    $games = @(Get-Games)
    # Names can be ambiguous ("Star Trek" also matches The Next Generation), so a table
    # whose ROM is one of the game's ROMs is matched first, then by name alone.
    $claimed = @{}; $pick = @{}
    foreach ($byRom in $true, $false) {
        foreach ($g in $games | Where-Object { -not $pick[$_.id] }) {
            $file = $tables | Where-Object {
                # Some file names use _ for spaces (Star_Trek_The_Next_Generation...), and _ isn't \W.
                -not $claimed[$_.FullName] -and ($_.BaseName -replace '_', ' ') -match $g.match -and (-not $byRom -or @($g.roms) -contains (Get-TableInfo $_).GameName)
            } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($file) { $pick[$g.id] = $file; $claimed[$file.FullName] = $true }
        }
    }
    $list = @(foreach ($g in $games) {
        $file = $pick[$g.id]
        $rom = @($g.roms)[0]
        if ($file) {
            $info = Get-TableInfo $file
            if ($info.GameName) { $rom = $info.GameName }
        }
        $romOk = Test-Rom $rom
        [pscustomobject]@{
            Id = $g.id; Title = $g.title; Maker = $g.maker; Year = $g.year; Blurb = $g.blurb; Color = $g.color
            Curated = $true; Table = $file; Rom = $rom; RomOk = $romOk; NeedsRom = $true
            Vps = $g.vps; TableUrl = $g.tableUrl; TableBy = $g.tableBy; RomUrl = $(if ($rom -and $g.romUrls) { $g.romUrls.$rom }); B2sUrl = $g.b2sUrl
        }
    })
    foreach ($t in $tables | Where-Object { -not $claimed[$_.FullName] }) {
        $info = Get-TableInfo $t
        # Original tables often carry PinMAME boilerplate (Leprechaun King loads PinMAME with
        # cGameName "leprechaun" but needs no ROM), so only a real ROM set name is required:
        # name_version, like sttng_l7 or afm_113b.
        $needsRom = $info.UsesPinMame -and $info.GameName -match '^[a-z0-9]+_[a-z0-9]+$'
        $title = ($t.BaseName -replace '\s*\(.*$', '' -replace '[-_]', ' ').Trim()
        $maker = if ($t.BaseName -match '\(([^)]*?)\s*(\d{4})\)') { $Matches[1] } else { 'Original' }
        $year  = if ($t.BaseName -match '\((?:[^)]*?)(\d{4})\)') { [int]$Matches[1] } else { $null }
        $list += [pscustomobject]@{
            Id = 'x-' + ($t.BaseName -replace '[^A-Za-z0-9]', '').ToLower(); Title = $title; Maker = $maker; Year = $year
            Blurb = $t.Name; Color = '#475569'
            Curated = $false; Table = $t; Rom = $info.GameName; RomOk = (Test-Rom $info.GameName); NeedsRom = $needsRom
        }
    }
    $list
}

# --- Importing downloaded tables / ROMs -----------------------------------
$script:ImportedFile = Join-Path $LauncherDir 'imported.json'
$script:ArchiveExt = '.zip', '.7z', '.rar'

function Get-ArchiveEntries([string]$Path) {
    if ([IO.Path]::GetExtension($Path) -eq '.zip') {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $z = [IO.Compression.ZipFile]::OpenRead($Path)
        try { $z.Entries | ForEach-Object FullName } finally { $z.Dispose() }
    } else {
        & tar.exe -tf $Path 2>$null
    }
}

function Expand-AnyArchive([string]$Path, [string]$Dest) {
    New-Item -ItemType Directory -Force $Dest | Out-Null
    if ([IO.Path]::GetExtension($Path) -eq '.zip') {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [IO.Compression.ZipFile]::ExtractToDirectory($Path, $Dest)
    } else {
        & tar.exe -xf $Path -C $Dest
        if ($LASTEXITCODE) { throw "Could not unpack $([IO.Path]::GetFileName($Path))" }
    }
}

function Get-NameKey([string]$Name) {
    # "The Addams Family (Bally 1992) VPW 2.1" -> "addamsfamily"
    (($Name -replace '\(.*$', '') -replace '^\s*the\s+', '' -replace '[^A-Za-z0-9]', '').ToLower()
}

function Install-TableFiles([string]$Folder, [System.Collections.Generic.List[string]]$Log, [string[]]$KnownRoms) {
    # Puts every .vpx / .directb2s / ROM zip found under $Folder where VPX and PinMAME look for them.
    $vpxs = @(Get-ChildItem $Folder -Recurse -Filter *.vpx)
    $b2s  = @(Get-ChildItem $Folder -Recurse -Filter *.directb2s)
    foreach ($v in $vpxs) {
        $dest = Join-Path $TablesDir $v.Name
        Copy-Item $v.FullName $dest -Force
        $Log.Add("Table installed: $($v.BaseName)")
        # B2S finds a backglass by matching the table's file name.
        if ($b2s.Count -ge 1 -and $vpxs.Count -eq 1) {
            Copy-Item $b2s[0].FullName (Join-Path $TablesDir "$($v.BaseName).directb2s") -Force
            $Log.Add("  + backglass")
        }
        $info = Get-TableInfo (Get-Item $dest)
        if ($info.GameName) { $KnownRoms += $info.GameName }
    }
    if (-not $vpxs) {
        # A backglass on its own: name it after the installed table it belongs to,
        # matched on the title before "(Maker Year)".
        foreach ($b in $b2s) {
            $key = Get-NameKey $b.BaseName
            $table = Get-ChildItem $TablesDir -Filter *.vpx | Where-Object { (Get-NameKey $_.BaseName) -eq $key } |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1
            $name = if ($table) { "$($table.BaseName).directb2s" } else { $b.Name }
            Copy-Item $b.FullName (Join-Path $TablesDir $name) -Force
            $Log.Add("Backglass copied: $name")
        }
    }
    foreach ($z in Get-ChildItem $Folder -Recurse -Include *.zip, *.7z) {
        if ($KnownRoms -contains $z.BaseName -or $z.Directory.Name -eq 'roms') {
            Copy-Item $z.FullName (Join-Path $RomsDir $z.Name) -Force
            $Log.Add("ROM installed: $($z.BaseName)")
        }
    }
    $music = Get-ChildItem $Folder -Recurse -Directory -Filter music | Select-Object -First 1
    if ($music) { Copy-Item (Join-Path $music.FullName '*') (Join-Path $VPRoot 'Music') -Recurse -Force; $Log.Add("  + music") }
}

function Import-Downloads([string[]]$Folders = @((Join-Path $env:USERPROFILE 'Downloads'))) {
    $log = [System.Collections.Generic.List[string]]::new()
    $seen = @{}
    if (Test-Path $ImportedFile) { (Get-Content $ImportedFile -Raw | ConvertFrom-Json) | ForEach-Object { $seen[$_] = $true } }

    $knownRoms = @(Get-Games | ForEach-Object { $_.roms }) +
                 @(Get-ChildItem $TablesDir -Filter *.vpx | ForEach-Object { (Get-TableInfo $_).GameName } | Where-Object { $_ })
    $files = foreach ($f in $Folders) { Get-ChildItem $f -File -ErrorAction SilentlyContinue }
    foreach ($f in $files) {
        $ext = $f.Extension.ToLower()
        if ($ext -notin (@('.vpx', '.directb2s') + $ArchiveExt)) { continue }
        $key = "$($f.FullName)|$($f.Length)|$($f.LastWriteTimeUtc.Ticks)"
        if ($seen[$key]) { continue }
        try {
            if ($ext -in '.vpx', '.directb2s') {
                $tmp = Join-Path $env:TEMP "mypinball-$([guid]::NewGuid())"
                New-Item -ItemType Directory $tmp | Out-Null
                Copy-Item $f.FullName $tmp
                Install-TableFiles $tmp $log $knownRoms
                Remove-Item $tmp -Recurse -Force
            } else {
                $entries = @(Get-ArchiveEntries $f.FullName)
                $hasTable = $entries -match '\.(vpx|directb2s)$'
                if ($hasTable) {
                    $tmp = Join-Path $env:TEMP "mypinball-$([guid]::NewGuid())"
                    Expand-AnyArchive $f.FullName $tmp
                    Install-TableFiles $tmp $log $knownRoms
                    Remove-Item $tmp -Recurse -Force
                } elseif ($knownRoms -contains $f.BaseName -or
                          ($f.BaseName -match '^[a-z0-9]+_[a-z0-9]+$' -and -not ($entries -match '/'))) {
                    # ROM sets stay zipped: PinMAME reads roms\<name>.zip directly.
                    Copy-Item $f.FullName (Join-Path $RomsDir $f.Name) -Force
                    $log.Add("ROM installed: $($f.BaseName)")
                } else { continue }
            }
            $seen[$key] = $true
        } catch {
            $log.Add("Problem with $($f.Name): $($_.Exception.Message)")
        }
    }
    ConvertTo-Json @($seen.Keys) | Set-Content $ImportedFile -Encoding utf8
    $log
}

# --- Music volume -------------------------------------------------------------
# PinMAME's "volume" is an attenuation in whole dB per ROM (0 = its normal maximum,
# -32 = quietest), shown as a percentage. Since PinMAME 3.x it can go above 0 dB as a boost
# (it warns that this may crackle), which is the only way to make music and voices louder
# than the effects on VPX 10.8.0; 200% (+6 dB) is the top.
function Get-MusicVolume {
    $db = (Get-ItemProperty "$PinMameKey\default" -ErrorAction SilentlyContinue).volume
    if ($null -eq $db) { return 100 }
    $db = [int64]$db
    if ($db -gt [int]::MaxValue) { $db -= 4294967296 }   # a negative DWORD reads back unsigned
    if ($db -le -32) { return 0 }
    [int][Math]::Round(100 * [Math]::Pow(10, [Math]::Min(6, $db) / 20))
}

function Set-MusicVolume([int]$Percent) {
    $db = if ($Percent -le 0) { -32 } else { [Math]::Max(-32, [Math]::Min(6, [int][Math]::Round(20 * [Math]::Log10($Percent / 100)))) }
    # Per-ROM keys are copied from 'default' the first time a ROM runs, so set every one.
    Get-ChildItem $PinMameKey | Where-Object PSChildName -ne 'globals' | ForEach-Object { Set-ItemProperty $_.PSPath volume $db -Type DWord }
    # Music that tables without a ROM play themselves; VPX caps it at 100.
    Set-IniValues $VpxIni 'Player' @{ MusicVolume = [Math]::Min(100, $Percent) }
}

# --- Effects volume -----------------------------------------------------------
# VPX turns [Player] SoundVolume (0-100) into loudness with its legacy curve of 10 dB per
# tenfold step: 50 is only -3 dB, 5 is -13 dB and 1 (-20 dB) is the quietest before 0 = off.
# The Settings slider uses the same hearing scale as music (50% = -6 dB), so the value
# VPX gets is percent^2 / 100: 50% -> 25, 10% -> 1.
function ConvertTo-VpxVolume([int]$Percent) {
    if ($Percent -le 0) { return 0 }
    [Math]::Max(1, [int][Math]::Round($Percent * $Percent / 100))
}

function ConvertFrom-VpxVolume([double]$Value) {
    [int][Math]::Round(10 * [Math]::Sqrt([Math]::Max(0, [Math]::Min(100, $Value))))
}

# --- INI editing that keeps VPX's comments and layout intact ---------------
function Get-IniValue([string]$Path, [string]$Section, [string]$Key) {
    # $null when the file, section or key is missing or the value is blank (VPX's default).
    if (-not (Test-Path $Path)) { return $null }
    $in = $false
    foreach ($line in Get-Content $Path) {
        if ($line -match '^\s*\[(.+)\]') { $in = $Matches[1].Trim() -eq $Section; continue }
        if ($in -and $line -match "^\s*$([regex]::Escape($Key))\s*=\s*(.*?)\s*$") {
            if ($Matches[1]) { return $Matches[1] } else { return $null }
        }
    }
    $null
}

function Set-IniValues {
    param([string]$Path, [string]$Section, [hashtable]$Values)
    $lines = [System.Collections.Generic.List[string]]::new()
    if (Test-Path $Path) { $lines.AddRange([string[]](Get-Content $Path)) }

    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i].Trim() -eq "[$Section]") { $start = $i; break } }
    if ($start -lt 0) {
        if ($lines.Count -and $lines[$lines.Count - 1].Trim()) { $lines.Add('') }
        $lines.Add("[$Section]"); $start = $lines.Count - 1
    }
    $end = $lines.Count
    for ($i = $start + 1; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^\s*\[') { $end = $i; break } }

    foreach ($key in $Values.Keys) {
        $line = "$key = $($Values[$key])"
        $found = $false
        for ($i = $start + 1; $i -lt $end; $i++) {
            if ($lines[$i] -match "^\s*$([regex]::Escape($key))\s*=") { $lines[$i] = $line; $found = $true; break }
        }
        if (-not $found) { $lines.Insert($start + 1, $line); $end++ }
    }
    [IO.File]::WriteAllLines($Path, $lines, [Text.UTF8Encoding]::new($false))
}
