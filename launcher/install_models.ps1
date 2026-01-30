# Auto-generated wrapper for AI Hub action: install_models
$ArgsList = @('--action', 'install_models') + $args
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $ScriptDir 'aihub_menu.ps1') @ArgsList
