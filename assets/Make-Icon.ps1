# Draws the Easy Pinball icon from scratch (no outside artwork) and writes
# EasyPinball.ico (16-256 px) and icon.png next to this script.
# Re-run after changing the drawing: powershell -File assets\Make-Icon.ps1
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'

function Get-Color([string]$hex, [int]$alpha = 255) {
    $c = [Drawing.ColorTranslator]::FromHtml($hex)
    [Drawing.Color]::FromArgb($alpha, $c)
}

function Add-RoundedRect($path, [float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $d = 2 * $r
    $path.AddArc($x, $y, $d, $d, 180, 90)
    $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $path.CloseFigure()
}

function Draw-Flipper($g, $brush, [float]$px, [float]$py, [float]$tx, [float]$ty, [float]$pr, [float]$tr) {
    # A flipper is two circles (pivot and tip) joined by their outer tangents.
    $dx = $tx - $px; $dy = $ty - $py
    $len = [Math]::Sqrt($dx * $dx + $dy * $dy)
    $ux = $dx / $len; $uy = $dy / $len
    $a = [Math]::Asin(($pr - $tr) / $len)
    $base = [Math]::Atan2($uy, $ux)
    $pts = foreach ($side in 1, -1) {
        $n = $base + $side * ([Math]::PI / 2 + $a)
        , @(([float]($px + $pr * [Math]::Cos($n))), ([float]($py + $pr * [Math]::Sin($n))), ([float]($tx + $tr * [Math]::Cos($n))), ([float]($ty + $tr * [Math]::Sin($n))))
    }
    $g.FillPolygon($brush, [Drawing.PointF[]]@(
        [Drawing.PointF]::new($pts[0][0], $pts[0][1]), [Drawing.PointF]::new($pts[0][2], $pts[0][3]),
        [Drawing.PointF]::new($pts[1][2], $pts[1][3]), [Drawing.PointF]::new($pts[1][0], $pts[1][1])))
    $g.FillEllipse($brush, $px - $pr, $py - $pr, 2 * $pr, 2 * $pr)
    $g.FillEllipse($brush, $tx - $tr, $ty - $tr, 2 * $tr, 2 * $tr)
}

function New-IconBitmap([int]$size) {
    # Drawn on a 1024 grid, scaled to the requested size.
    $bmp = [Drawing.Bitmap]::new($size, $size, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.PixelOffsetMode = 'HighQuality'
    $g.ScaleTransform($size / 1024, $size / 1024)

    # Tile: the launcher's dark background with a faint gold edge.
    $tile = [Drawing.Drawing2D.GraphicsPath]::new()
    Add-RoundedRect $tile 40 40 944 944 190
    $bg = [Drawing.Drawing2D.LinearGradientBrush]::new([Drawing.PointF]::new(0, 40), [Drawing.PointF]::new(0, 984), (Get-Color '#232A37'), (Get-Color '#0B0D12'))
    $g.FillPath($bg, $tile)
    $g.DrawPath([Drawing.Pen]::new((Get-Color '#F5B301' 140), 16), $tile)

    # Flippers, gold like the PLAY button.
    $gold = [Drawing.SolidBrush]::new((Get-Color '#F5B301'))
    Draw-Flipper $g $gold 230 770 455 860 68 34
    Draw-Flipper $g $gold 794 770 569 860 68 34

    # Ball: a steel sphere lit from the upper left, with a soft shadow below.
    $cx = 512; $cy = 430; $r = 250
    $g.FillEllipse([Drawing.SolidBrush]::new((Get-Color '#000000' 90)), $cx - $r + 18, $cy - $r + 34, 2 * $r, 2 * $r)
    $ball = [Drawing.Drawing2D.GraphicsPath]::new()
    $ball.AddEllipse($cx - $r, $cy - $r, 2 * $r, 2 * $r)
    $shade = [Drawing.Drawing2D.PathGradientBrush]::new($ball)
    $shade.CenterPoint = [Drawing.PointF]::new($cx - 90, $cy - 100)
    $shade.CenterColor = Get-Color '#F4F6FA'
    $shade.SurroundColors = [Drawing.Color[]]@(Get-Color '#4A5262')
    $blend = [Drawing.Drawing2D.Blend]::new(4)
    $blend.Positions = [float[]]@(0, 0.35, 0.75, 1)
    $blend.Factors = [float[]]@(0, 0.55, 0.9, 1)
    $shade.Blend = $blend
    $g.FillPath($shade, $ball)
    $g.DrawEllipse([Drawing.Pen]::new((Get-Color '#1A1F29'), 10), $cx - $r, $cy - $r, 2 * $r, 2 * $r)
    $g.FillEllipse([Drawing.SolidBrush]::new((Get-Color '#FFFFFF' 230)), $cx - 150, $cy - 165, 110, 80)

    $g.Dispose()
    $bmp
}

$sizes = 16, 24, 32, 48, 64, 128, 256
$pngs = foreach ($s in $sizes) {
    $bmp = New-IconBitmap $s
    $ms = [IO.MemoryStream]::new()
    $bmp.Save($ms, [Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    , $ms.ToArray()
}

# ICO file: a header, one directory entry per size, then each size as PNG data.
$out = [IO.MemoryStream]::new()
$w = [IO.BinaryWriter]::new($out)
$w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $dim = if ($sizes[$i] -ge 256) { 0 } else { $sizes[$i] }
    $w.Write([byte]$dim); $w.Write([byte]$dim); $w.Write([byte]0); $w.Write([byte]0)
    $w.Write([uint16]1); $w.Write([uint16]32)
    $w.Write([uint32]$pngs[$i].Length); $w.Write([uint32]$offset)
    $offset += $pngs[$i].Length
}
foreach ($p in $pngs) { $w.Write($p) }
$w.Flush()
[IO.File]::WriteAllBytes((Join-Path $PSScriptRoot 'EasyPinball.ico'), $out.ToArray())

$big = New-IconBitmap 512
$big.Save((Join-Path $PSScriptRoot 'icon.png'), [Drawing.Imaging.ImageFormat]::Png)
$big.Dispose()
