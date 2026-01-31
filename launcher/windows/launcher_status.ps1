# Auto-generated wrapper for AI Hub action: launcher_status
$ArgsList = @('--action', 'launcher_status') + $args
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $ScriptDir 'aihub_menu.ps1') @ArgsList
