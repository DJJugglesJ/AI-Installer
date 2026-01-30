# Auto-generated wrapper for AI Hub action: install_loras
$ArgsList = @('--action', 'install_loras') + $args
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $ScriptDir 'aihub_menu.ps1') @ArgsList
