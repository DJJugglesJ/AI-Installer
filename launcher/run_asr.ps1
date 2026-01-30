# Auto-generated wrapper for AI Hub action: run_asr
$ArgsList = @('--action', 'run_asr') + $args
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $ScriptDir 'aihub_menu.ps1') @ArgsList
