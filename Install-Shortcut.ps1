# Puts an "Easy Pinball" shortcut (with the Easy Pinball icon) on the desktop and in this folder.
# Run once after downloading: right-click > Run with PowerShell, or
#   powershell -ExecutionPolicy Bypass -File Install-Shortcut.ps1
$ErrorActionPreference = 'Stop'
$shell = New-Object -ComObject WScript.Shell
$targets = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Easy Pinball.lnk'), (Join-Path $PSScriptRoot 'Easy Pinball.lnk')
foreach ($path in $targets) {
    $lnk = $shell.CreateShortcut($path)
    $lnk.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $lnk.Arguments = "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$PSScriptRoot\launcher\EasyPinball.ps1`""
    $lnk.WorkingDirectory = $PSScriptRoot
    $lnk.IconLocation = "$PSScriptRoot\assets\EasyPinball.ico,0"
    $lnk.Description = 'Easy Pinball: a simple game picker for Visual Pinball X'
    $lnk.Save()
    "Created $path"
}
