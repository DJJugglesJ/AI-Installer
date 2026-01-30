# Auto-generated wrapper for AI Hub action: manifest_browser
$ArgsList = @('--action', 'manifest_browser') + $args
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $ScriptDir 'aihub_menu.ps1') @ArgsList
