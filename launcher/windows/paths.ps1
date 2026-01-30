# Path helpers for AI Hub (Windows)

function Get-AIHubConfigRoot {
  if ($Env:AIHUB_CONFIG_DIR) { return $Env:AIHUB_CONFIG_DIR }
  if ($IsWindows -and $Env:APPDATA) { return (Join-Path $Env:APPDATA "AIHub/config") }
  return (Join-Path $Env:USERPROFILE ".config/aihub")
}

function Get-AIHubConfigFile {
  if ($Env:AIHUB_CONFIG_FILE) { return $Env:AIHUB_CONFIG_FILE }
  if ($Env:CONFIG_FILE) { return $Env:CONFIG_FILE }
  return (Join-Path (Get-AIHubConfigRoot) "installer.conf")
}

function Get-AIHubStatePath {
  if ($Env:CONFIG_STATE_FILE) { return $Env:CONFIG_STATE_FILE }
  if ($Env:AIHUB_CONFIG_STATE) { return $Env:AIHUB_CONFIG_STATE }
  return (Join-Path (Get-AIHubConfigRoot) "config.yaml")
}

function Get-AIHubLogPath {
  if ($Env:AIHUB_LOG_PATH) { return $Env:AIHUB_LOG_PATH }
  $logRoot = Get-AIHubLogRoot
  $logDate = if ($Env:AIHUB_LOG_DATE) { $Env:AIHUB_LOG_DATE } else { (Get-Date).ToUniversalTime().ToString("yyyyMMdd") }
  return (Join-Path $logRoot "install-$logDate.log")
}

function Get-AIHubLogRoot {
  if ($Env:AIHUB_LOG_DIR) { return $Env:AIHUB_LOG_DIR }
  $configRoot = Get-AIHubConfigRoot
  $parent = Split-Path $configRoot -Parent
  if ((Split-Path $configRoot -Leaf) -eq "config") {
    return (Join-Path $parent "logs")
  }
  return (Join-Path $configRoot "logs")
}
