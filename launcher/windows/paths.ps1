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
  if ($IsWindows -and $Env:LOCALAPPDATA) {
    return (Join-Path $Env:LOCALAPPDATA "AIHub/logs/install.log")
  }
  return (Join-Path (Get-AIHubConfigRoot) "install.log")
}
