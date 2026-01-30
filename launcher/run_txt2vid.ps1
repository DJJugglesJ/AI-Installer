# Auto-generated wrapper for AI Hub action: run_txt2vid
$ArgsList = @('--action', 'run_txt2vid') + $args
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $ScriptDir 'aihub_menu.ps1') @ArgsList
