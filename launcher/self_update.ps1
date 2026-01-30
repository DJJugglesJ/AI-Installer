# Auto-generated wrapper for AI Hub action: self_update
$ArgsList = @('--action', 'self_update') + $args
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $ScriptDir 'aihub_menu.ps1') @ArgsList
