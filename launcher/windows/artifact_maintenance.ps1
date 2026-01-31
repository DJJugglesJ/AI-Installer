# Auto-generated wrapper for AI Hub action: artifact_maintenance
$ArgsList = @('--action', 'artifact_maintenance') + $args
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $ScriptDir 'aihub_menu.ps1') @ArgsList
