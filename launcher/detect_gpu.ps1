# Lightweight GPU detection helper for Windows/WSL users
$ArgsList = @('--detect-gpu') + $args
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $ScriptDir 'aihub_menu.ps1') @ArgsList
