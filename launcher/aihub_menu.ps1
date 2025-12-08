# Windows PowerShell entry point for AI Hub menu actions
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path "$ScriptDir/.."
$LogPath = $Env:AIHUB_LOG_PATH
if (-not $LogPath) {
  $LogPath = Join-Path $Env:USERPROFILE ".config/aihub/install.log"
}
$LogDir = Split-Path $LogPath -Parent
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
if (-not (Test-Path $LogPath)) { New-Item -ItemType File -Path $LogPath -Force | Out-Null }

Push-Location $ProjectRoot
$env:PYTHONPATH = "$ProjectRoot;$($env:PYTHONPATH)"
python launcher/aihub_menu.py @args
Pop-Location
