# Auto-generated wrapper for AI Hub action: run_sillytavern
$ArgsList = @('--action', 'run_sillytavern') + $args
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $ScriptDir 'aihub_menu.ps1') @ArgsList
