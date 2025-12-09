[CmdletBinding()]
param(
  [switch]$Headless,
  [string]$Config,
  [string]$Install,
  [string]$Gpu,
  [switch]$Help
)

function Show-Usage {
  Write-Host "Usage: install.ps1 [--headless] [--config <file>] [--install <target>] [--gpu <mode>] [--help]" -ForegroundColor Cyan
  Write-Host """  --headless         Run without prompts (defaults are applied)."""
  Write-Host """  --config <file>    Optional config file persisted to %APPDATA%\\AIHub\\config."""
  Write-Host """  --install <target> Install a component directly (e.g., webui, kobold, sillytavern, loras, models)."""
  Write-Host """  --gpu <mode>       Force GPU mode (nvidia|amd|intel|cpu) and install matching tooling."""
  Write-Host """  --help             Show this help."""
}

if ($Help) { Show-Usage; exit 0 }

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path "$ScriptDir"
$LogDir = if ($Env:LOCALAPPDATA) { Join-Path $Env:LOCALAPPDATA "AIHub/logs" } else { Join-Path $env:USERPROFILE ".config/aihub" }
$ConfigDir = if ($Env:APPDATA) { Join-Path $Env:APPDATA "AIHub/config" } else { Join-Path $env:USERPROFILE ".config/aihub" }
$LogPath = Join-Path $LogDir "install.log"
$ConfigPath = if ($Config) { $Config } else { Join-Path $ConfigDir "installer.conf" }

function Ensure-Path($Path) {
  if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
}

Ensure-Path $LogDir
Ensure-Path $ConfigDir
if (-not (Test-Path $LogPath)) { New-Item -ItemType File -Path $LogPath -Force | Out-Null }

function Write-Log {
  param([string]$Message, [string]$Level = "INFO")
  $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $line = "[$stamp][$Level] $Message"
  Write-Host $line
  Add-Content -Path $LogPath -Value $line
}

Write-Log "AI Hub Windows installer starting (headless=$($Headless.IsPresent), install=$Install, gpu=$Gpu)."
Write-Log "Log path: $LogPath"
Write-Log "Config path: $ConfigPath"

function Get-PackageManager {
  if (Get-Command winget -ErrorAction SilentlyContinue) { return "winget" }
  if (Get-Command choco -ErrorAction SilentlyContinue) { return "choco" }
  return $null
}

$PackageManager = Get-PackageManager
if (-not $PackageManager) {
  Write-Log "Neither winget nor choco found. Please install one of them and re-run." "ERROR"
  exit 1
}
Write-Log "Using package manager: $PackageManager"

function Test-Command($Name) { return [bool](Get-Command $Name -ErrorAction SilentlyContinue) }

function Install-Package {
  param([string]$WingetId, [string]$ChocoId, [string]$Label)
  $pkgId = if ($PackageManager -eq "winget") { $WingetId } else { $ChocoId }
  if (-not $pkgId) { Write-Log "No package id supplied for $Label; skipping." "WARN"; return }
  try {
    if ($PackageManager -eq "winget") {
      Write-Log "Installing $Label via winget ($pkgId) ..."
      winget install --id $pkgId --exact --accept-package-agreements --accept-source-agreements --silent | Out-Null
    } else {
      Write-Log "Installing $Label via choco ($pkgId) ..."
      choco install $pkgId -y --no-progress | Out-Null
    }
    Write-Log "$Label installation attempted; verify presence after completion."
  } catch {
    Write-Log "Failed to install $Label ($pkgId): $_" "ERROR"
  }
}

$Deps = @(
  @{ Cmd = "git"; Label = "Git"; Winget = "Git.Git"; Choco = "git" },
  @{ Cmd = "python"; Label = "Python"; Winget = "Python.Python.3"; Choco = "python" },
  @{ Cmd = "node"; Label = "Node.js"; Winget = "OpenJS.NodeJS.LTS"; Choco = "nodejs-lts" },
  @{ Cmd = "npm"; Label = "npm"; Winget = "OpenJS.NodeJS.LTS"; Choco = "nodejs-lts" },
  @{ Cmd = "aria2c"; Label = "aria2"; Winget = "aria2.aria2"; Choco = "aria2" },
  @{ Cmd = "wget"; Label = "wget"; Winget = "GnuWin32.Wget"; Choco = "wget" }
)

foreach ($dep in $Deps) {
  if (Test-Command $dep.Cmd) {
    Write-Log "$($dep.Label) present: $(& $dep.Cmd --version 2>$null | Select-Object -First 1)"
  } else {
    Install-Package -WingetId $dep.Winget -ChocoId $dep.Choco -Label $dep.Label
  }
}

function Ensure-GpuTooling {
  param([string]$Mode)
  $modeLower = $Mode.ToLower()
  switch -regex ($modeLower) {
    "nvidia" {
      Install-Package -WingetId "Nvidia.CUDA" -ChocoId "cuda" -Label "NVIDIA CUDA toolkit"
    }
    "amd" {
      Install-Package -WingetId "AdvancedMicroDevicesInc.RadeonSoftware" -ChocoId "radeon-software" -Label "AMD Radeon software"
    }
    "intel" {
      Install-Package -WingetId "Intel.IntelDriverAndSupportAssistant" -ChocoId "intel-dsa" -Label "Intel driver tools"
    }
    default {
      Write-Log "CPU mode requested; skipping GPU tooling install." "WARN"
    }
  }
}

if ($Gpu) {
  Ensure-GpuTooling -Mode $Gpu
} else {
  try {
    $gpuInfo = Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name -ErrorAction Stop
    if ($gpuInfo) {
      $vendor = ($gpuInfo -join " ")
      Write-Log "Detected GPU: $vendor"
      if ($vendor -match "NVIDIA") { Ensure-GpuTooling -Mode "nvidia" }
      elseif ($vendor -match "AMD|Radeon") { Ensure-GpuTooling -Mode "amd" }
      elseif ($vendor -match "Intel") { Ensure-GpuTooling -Mode "intel" }
    }
  } catch {
    Write-Log "GPU detection failed: $_" "WARN"
  }
}

function Provision-Workspace {
  $base = Join-Path $Env:USERPROFILE "AI"
  $paths = @(
    $base,
    Join-Path $base "WebUI",
    Join-Path $base "KoboldAI",
    Join-Path $base "SillyTavern",
    Join-Path $base "LoRAs",
    Join-Path $base "oobabooga",
    Join-Path $base "oobabooga/lora",
    Join-Path $base "oobabooga/models",
    Join-Path $base "ai-hub",
    Join-Path $base "ai-hub/models"
  )
  foreach ($path in $paths) { Ensure-Path $path }
  Write-Log "Provisioned workspace directories under $base"
}

Provision-Workspace

function Load-Manifests {
  $manifestDir = Join-Path $ProjectRoot "manifests"
  if (-not (Test-Path $manifestDir)) { return }
  Get-ChildItem $manifestDir -Filter *.json | ForEach-Object {
    try {
      $data = Get-Content $_.FullName -Raw | ConvertFrom-Json
      $count = if ($data.items) { $data.items.Count } else { 0 }
      Write-Log "Manifest '$($_.Name)' loaded with $count item(s)."
    } catch {
      Write-Log "Failed to parse manifest $($_.Name): $_" "WARN"
    }
  }
}

Load-Manifests

function New-AIHubShortcut {
  param([string]$Destination, [string]$TargetScript)
  try {
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($Destination)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-ExecutionPolicy Bypass -File \"$TargetScript\""
    $shortcut.WorkingDirectory = $ProjectRoot
    $shortcut.IconLocation = "shell32.dll,220"
    $shortcut.Save()
    Write-Log "Shortcut created at $Destination"
  } catch {
    Write-Log "Failed to create shortcut at $Destination: $_" "ERROR"
  }
}

$DesktopDir = [Environment]::GetFolderPath("Desktop")
$StartMenuDir = [Environment]::GetFolderPath("Programs")
Ensure-Path $DesktopDir
Ensure-Path $StartMenuDir

$webLauncher = Join-Path $ProjectRoot "launcher/start_web_launcher.ps1"
$menuLauncher = Join-Path $ProjectRoot "launcher/aihub_menu.ps1"
$target = if (Test-Path $webLauncher) { $webLauncher } elseif (Test-Path $menuLauncher) { $menuLauncher } else { $null }

if ($target) {
  $desktopShortcut = Join-Path $DesktopDir "AI Hub Launcher.lnk"
  $startMenuShortcut = Join-Path $StartMenuDir "AI Hub Launcher.lnk"
  New-AIHubShortcut -Destination $desktopShortcut -TargetScript $target
  New-AIHubShortcut -Destination $startMenuShortcut -TargetScript $target
} else {
  Write-Log "No launcher script found; skipping shortcut creation." "WARN"
}

try {
  if (-not (Test-Path $ConfigPath)) { New-Item -ItemType File -Path $ConfigPath -Force | Out-Null }
  Write-Log "Config persisted at $ConfigPath"
} catch {
  Write-Log "Unable to persist config at $ConfigPath: $_" "ERROR"
}

Write-Log "AI Hub installer completed."
