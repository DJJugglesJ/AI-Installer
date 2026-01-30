# Auto-generated wrapper for AI Hub action: run_kobold
$ArgsList = @('--action', 'run_kobold') + $args
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $ScriptDir 'aihub_menu.ps1') @ArgsList
