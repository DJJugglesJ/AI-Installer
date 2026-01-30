# Auto-generated wrapper for AI Hub action: health_summary
$ArgsList = @('--action', 'health_summary') + $args
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $ScriptDir 'aihub_menu.ps1') @ArgsList
