# Windows PowerShell entry point for AI Hub menu actions
[CmdletBinding()]
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path "$ScriptDir/.."
. "$ProjectRoot/launcher/windows/paths.ps1"

function Get-PythonPath {
  if ($Env:AIHUB_PYTHON) { return @($Env:AIHUB_PYTHON) }
  $venvPython = Join-Path $ProjectRoot ".venv/Scripts/python.exe"
  if (Test-Path $venvPython) { return @($venvPython) }
  $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
  if ($pythonCmd) { return @($pythonCmd.Source) }
  $pyCmd = Get-Command py -ErrorAction SilentlyContinue
  if ($pyCmd) { return @($pyCmd.Source, "-3") }
  return @()
}

$PythonPath = Get-PythonPath
if ($PythonPath.Count -eq 0) {
  Write-Host "Python was not found. Install Python 3 or run inside WSL2 (Ubuntu recommended)."
  exit 1
}

$LogPath = Get-AIHubLogPath
$LogDir = Split-Path $LogPath -Parent
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
if (-not (Test-Path $LogPath)) { New-Item -ItemType File -Path $LogPath -Force | Out-Null }
$Env:AIHUB_LOG_PATH = $LogPath
$Env:AIHUB_CONFIG_DIR = Get-AIHubConfigRoot
$Env:CONFIG_FILE = Get-AIHubConfigFile
$Env:CONFIG_STATE_FILE = Get-AIHubStatePath

$wslAvailable = Get-Command wsl.exe -ErrorAction SilentlyContinue
if ($IsWindows -and -not $wslAvailable) {
  Write-Host "WSL2 not detected. Shell-heavy actions may require WSL; use --detect-gpu for hardware info." -ForegroundColor Yellow
}

Push-Location $ProjectRoot
$env:PYTHONPATH = "$ProjectRoot;$($env:PYTHONPATH)"
$argsList = @("launcher/aihub_menu.py") + $ExtraArgs
& $PythonPath @argsList
Pop-Location
