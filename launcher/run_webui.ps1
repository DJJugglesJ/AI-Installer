# Auto-generated wrapper for AI Hub action: run_webui
$ArgsList = @('--action', 'run_webui') + $args
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $ScriptDir 'aihub_menu.ps1') @ArgsList
