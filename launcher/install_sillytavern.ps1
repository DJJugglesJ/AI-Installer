# Auto-generated wrapper for AI Hub action: install_sillytavern
$ArgsList = @('--action', 'install_sillytavern') + $args
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $ScriptDir 'aihub_menu.ps1') @ArgsList
