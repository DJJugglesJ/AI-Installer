# Auto-generated wrapper for AI Hub action: install_kobold
$ArgsList = @('--action', 'install_kobold') + $args
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $ScriptDir 'aihub_menu.ps1') @ArgsList
