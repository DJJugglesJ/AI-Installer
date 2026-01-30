# Auto-generated wrapper for AI Hub action: run_img2vid
$ArgsList = @('--action', 'run_img2vid') + $args
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $ScriptDir 'aihub_menu.ps1') @ArgsList
