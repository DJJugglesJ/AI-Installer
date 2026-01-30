# Auto-generated wrapper for AI Hub action: install_webui
$ArgsList = @('--action', 'install_webui') + $args
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $ScriptDir 'aihub_menu.ps1') @ArgsList
