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

$pythonCommand = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCommand) {
    Write-Error "Python 3.6 or newer is required to run the AI Hub web launcher."
    exit 1
}

$versionParts = (python -c "import sys; print('{}.{}'.format(sys.version_info[0], sys.version_info[1]))").Split('.')
$pyMajor = [int]$versionParts[0]
$pyMinor = [int]$versionParts[1]

if (($pyMajor -lt 3) -or (($pyMajor -eq 3) -and ($pyMinor -lt 6))) {
    Write-Error "Python $pyMajor.$pyMinor is not supported. Please upgrade to Python 3.6 or newer (3.7+ recommended)."
    exit 1
}

if (($pyMajor -eq 3) -and ($pyMinor -eq 6)) {
    Write-Output "Python 3.6 detected; ensuring dataclasses backport is installed..."
    python -m pip show dataclasses | Out-Null
    if ($LASTEXITCODE -ne 0) {
        python -m pip install dataclasses
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to install the dataclasses backport required for Python 3.6."
            exit 1
        }
    } else {
        Write-Output "dataclasses backport already installed."
    }
}

Push-Location $ProjectRoot
$env:PYTHONPATH = "$ProjectRoot;$($env:PYTHONPATH)"
$env:AIHUB_WEB_HOST = $HostValue
$env:AIHUB_WEB_PORT = $PortValue
python -m modules.runtime.web_launcher --host $HostValue --port $PortValue
Pop-Location
