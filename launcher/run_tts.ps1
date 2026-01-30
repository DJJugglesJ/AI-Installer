# Auto-generated wrapper for AI Hub action: run_tts
$ArgsList = @('--action', 'run_tts') + $args
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $ScriptDir 'aihub_menu.ps1') @ArgsList
