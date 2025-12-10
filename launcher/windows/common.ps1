# Common helpers for PowerShell-based AI Hub actions

function Get-AIHubLogPath {
  if ($Env:AIHUB_LOG_PATH) { return $Env:AIHUB_LOG_PATH }
  if ($IsWindows -and $Env:LOCALAPPDATA) {
    return (Join-Path $Env:LOCALAPPDATA "AIHub/logs/install.log")
  }
  return (Join-Path $Env:USERPROFILE ".config/aihub/install.log")
}

function Ensure-Path {
  param([string]$Path)
  $parent = Split-Path $Path -Parent
  if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
  if (-not (Test-Path $Path)) { New-Item -ItemType File -Path $Path -Force | Out-Null }
}

function Write-LogLine {
  param(
    [string]$Message,
    [string]$Level = "INFO",
    [string]$LogPath = $null
  )
  $path = if ($LogPath) { $LogPath } else { Get-AIHubLogPath }
  $stamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  $line = "[$stamp][$Level] $Message"
  Write-Host $line
  Add-Content -Path $path -Value $line
}

function Invoke-AIHubShellAction {
  param(
    [string]$ActionName,
    [string]$ScriptName,
    [string[]]$AdditionalArgs = @(),
  )

  $projectRoot = Resolve-Path "$PSScriptRoot/../.."
  $scriptPath = Join-Path $projectRoot "modules/shell/$ScriptName"
  $logPath = Get-AIHubLogPath
  # Preserve caller-provided AIHUB_LOG_PATH overrides so log redirection is
  # consistent across shell and PowerShell entry points.
  $Env:AIHUB_LOG_PATH = $logPath
  Ensure-Path $logPath

  if (-not (Test-Path $scriptPath)) {
    Write-LogLine "Script not found: $scriptPath" "ERROR" -LogPath $logPath
    return 1
  }

  $bash = Get-Command bash -ErrorAction SilentlyContinue
  if (-not $bash) {
    Write-LogLine "Bash was not found. Install WSL or Git Bash to run '$ActionName'." "ERROR" -LogPath $logPath
    return 1
  }

  Write-LogLine "Starting $ActionName via $ScriptName" "INFO" -LogPath $logPath

  Push-Location $projectRoot
  try {
    & $bash.Path $scriptPath @AdditionalArgs 2>&1 | ForEach-Object {
      $msg = $_
      if ($msg -ne $null) { Write-LogLine $msg "STREAM" -LogPath $logPath }
    }
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
      Write-LogLine "$ActionName exited with code $exitCode" "ERROR" -LogPath $logPath
    } else {
      Write-LogLine "$ActionName completed" "INFO" -LogPath $logPath
    }
    return $exitCode
  } finally {
    Pop-Location
  }
}
