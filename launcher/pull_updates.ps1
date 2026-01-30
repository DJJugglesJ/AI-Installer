# Auto-generated wrapper for AI Hub action: pull_updates
$ArgsList = @('--action', 'pull_updates') + $args
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $ScriptDir 'aihub_menu.ps1') @ArgsList
