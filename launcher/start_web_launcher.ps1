# Start the AI Hub web launcher (Windows/PowerShell)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path "$ScriptDir/.."
. "$ProjectRoot/launcher/windows/paths.ps1"
$Env:AIHUB_LOG_PATH = Get-AIHubLogPath
$Env:AIHUB_CONFIG_DIR = Get-AIHubConfigRoot
$Env:CONFIG_FILE = Get-AIHubConfigFile
$Env:CONFIG_STATE_FILE = Get-AIHubStatePath
$HostValue = $Env:AIHUB_WEB_HOST
if (-not $HostValue) { $HostValue = "127.0.0.1" }
$PortValue = $Env:AIHUB_WEB_PORT
if (-not $PortValue) { $PortValue = 3939 }

Push-Location $ProjectRoot
$env:PYTHONPATH = "$ProjectRoot;$($env:PYTHONPATH)"
$env:AIHUB_WEB_HOST = $HostValue
$env:AIHUB_WEB_PORT = $PortValue
python -m modules.runtime.web_launcher --host $HostValue --port $PortValue
Pop-Location
