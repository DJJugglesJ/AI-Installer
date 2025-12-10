[CmdletBinding()]
param(
  [ValidateSet('install','menu','web','status','lint','test','setup','help')]
  [string]$Task,
  [string[]]$TaskArgs = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-AIHubProjectRoot {
  if (-not $script:AIHubProjectRoot) {
    if (-not $PSScriptRoot) {
      throw 'Unable to determine script root; ensure tools/windows.ps1 is executed as a file.'
    }

    $resolvedRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
    $script:AIHubProjectRoot = $resolvedRoot.ProviderPath
  }

  return $script:AIHubProjectRoot
}

function Get-AIHubPython {
  param([switch]$PreferVenv)
  $projectRoot = Get-AIHubProjectRoot
  if ($Env:AIHUB_PYTHON) { return $Env:AIHUB_PYTHON }
  $venvPython = Join-Path $projectRoot '.venv/Scripts/python.exe'
  if ($PreferVenv -and (Test-Path $venvPython)) { return $venvPython }
  $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
  if ($pythonCmd) { return $pythonCmd.Source }
  $pyCmd = Get-Command py -ErrorAction SilentlyContinue
  if ($pyCmd) { return "$($pyCmd.Source) -3" }
  throw 'Python 3 was not found. Install Python 3.x or set AIHUB_PYTHON to the executable path.'
}

function Invoke-AIHubSetup {
  [CmdletBinding()]
  param(
    [switch]$Force,
    [switch]$SkipInstall
  )

  $projectRoot = Get-AIHubProjectRoot
  $python = Get-AIHubPython -PreferVenv:$true
  $venvRoot = Join-Path $projectRoot '.venv'

  if ($Force -and (Test-Path $venvRoot)) {
    Remove-Item -Recurse -Force $venvRoot
  }

  if (-not (Test-Path $venvRoot)) {
    Push-Location $projectRoot
    & (Get-AIHubPython) -m venv .venv
    Pop-Location
  }

  if (-not $SkipInstall) {
    Push-Location $projectRoot
    & $python -m pip install --upgrade pip
    & $python -m pip install -r requirements.txt
    Pop-Location
  }

  return (Join-Path $venvRoot 'Scripts/python.exe')
}

function Invoke-AIHubInstall {
  [CmdletBinding()]
  param(
    [switch]$Headless,
    [string]$Config,
    [string]$Install,
    [string]$Gpu,
    [string[]]$ExtraArgs = @()
  )

  $projectRoot = Get-AIHubProjectRoot
  $installScript = Join-Path $projectRoot 'install.ps1'
  $args = @()
  if ($Headless) { $args += '--headless' }
  if ($Config) { $args += @('--config', $Config) }
  if ($Install) { $args += @('--install', $Install) }
  if ($Gpu) { $args += @('--gpu', $Gpu) }
  $args += $ExtraArgs
  & $installScript @args
}

function Invoke-AIHubMenu {
  [CmdletBinding()]
  param([string[]]$ExtraArgs = @())
  $projectRoot = Get-AIHubProjectRoot
  $menuScript = Join-Path $projectRoot 'launcher/aihub_menu.ps1'
  & $menuScript @ExtraArgs
}

function Start-AIHubWebLauncher {
  [CmdletBinding()]
  param(
    [string]$Host = '127.0.0.1',
    [int]$Port = 3939,
    [string[]]$ExtraArgs = @()
  )
  $projectRoot = Get-AIHubProjectRoot
  $webScript = Join-Path $projectRoot 'launcher/start_web_launcher.ps1'
  $env:AIHUB_WEB_HOST = $Host
  $env:AIHUB_WEB_PORT = $Port
  & $webScript @ExtraArgs
}

function Show-AIHubStatus {
  [CmdletBinding()]
  param()

  $projectRoot = Get-AIHubProjectRoot
  . (Join-Path $projectRoot 'launcher/windows/paths.ps1')
  $configFile = Get-AIHubConfigFile
  $stateFile = Get-AIHubStatePath
  $logFile = Get-AIHubLogPath

  $configText = if (Test-Path $configFile) { Get-Content $configFile } else { '<no installer.conf found>' }
  $stateText = if (Test-Path $stateFile) { Get-Content $stateFile } else { '<no config.yaml found>' }
  $logTail = if (Test-Path $logFile) { Get-Content $logFile -Tail 40 } else { '<no install.log found>' }

  Write-Host "AI Hub status (PowerShell parity)" -ForegroundColor Cyan
  Write-Host "Project root: $projectRoot"
  Write-Host "Config file: $configFile"
  Write-Host "State file:  $stateFile"
  Write-Host "Log file:    $logFile"
  Write-Host "`nConfig contents:`n----------------"; $configText | ForEach-Object { Write-Host $_ }
  Write-Host "`nState contents:`n----------------"; $stateText | ForEach-Object { Write-Host $_ }
  Write-Host "`nLog tail:`n---------"; $logTail | ForEach-Object { Write-Host $_ }
}

function Invoke-AIHubLint {
  [CmdletBinding()]
  param([switch]$SkipInstall)
  $python = Invoke-AIHubSetup -SkipInstall:$SkipInstall
  $projectRoot = Get-AIHubProjectRoot
  Push-Location $projectRoot
  & $python -m compileall launcher modules tests
  Pop-Location
}

function Invoke-AIHubTests {
  [CmdletBinding()]
  param([switch]$SkipInstall)
  $python = Invoke-AIHubSetup -SkipInstall:$SkipInstall
  $projectRoot = Get-AIHubProjectRoot
  Push-Location $projectRoot
  & $python -m pytest tests
  Pop-Location
}

function Show-HelperUsage {
  Write-Host "AI Hub PowerShell helpers" -ForegroundColor Cyan
  Write-Host "Usage: pwsh -File tools/windows.ps1 -Task <task> -- <task args>" -ForegroundColor Cyan
  Write-Host "Tasks:" -ForegroundColor Cyan
  Write-Host "  setup   : Create/refresh the virtual environment and install requirements." -ForegroundColor Gray
  Write-Host "  lint    : Run Python bytecode compilation across launcher/modules/tests (syntax parity)." -ForegroundColor Gray
  Write-Host "  test    : Run pytest against the tests/ suite." -ForegroundColor Gray
  Write-Host "  install : Call install.ps1 with --headless/--config/--install/--gpu passthrough." -ForegroundColor Gray
  Write-Host "  menu    : Launch launcher/aihub_menu.ps1 (same as aihub_menu.sh)." -ForegroundColor Gray
  Write-Host "  web     : Start launcher/start_web_launcher.ps1 with -Host/-Port." -ForegroundColor Gray
  Write-Host "  status  : Show installer.conf, config.yaml, and log tail (parity with ai_hub_launcher.sh)." -ForegroundColor Gray
}

if ($Task) {
  $taskMap = @{
    'install' = 'Invoke-AIHubInstall'
    'menu'    = 'Invoke-AIHubMenu'
    'web'     = 'Start-AIHubWebLauncher'
    'status'  = 'Show-AIHubStatus'
    'lint'    = 'Invoke-AIHubLint'
    'test'    = 'Invoke-AIHubTests'
    'setup'   = 'Invoke-AIHubSetup'
    'help'    = 'Show-HelperUsage'
  }

  $target = $taskMap[$Task]
  if (-not $target) { throw "Unknown task '$Task'. Use -Task help for available options." }
  & $target @TaskArgs
}
