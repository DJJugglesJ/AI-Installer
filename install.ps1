[CmdletBinding()]
param(
  [switch]$Headless,
  [string]$Config,
  [string]$Install,
  [string]$Gpu,
  [switch]$Help,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$RemainingArgs
)

function Show-Usage {
  Write-Host "Usage: install.ps1 [--headless] [--config <file>] [--install <target>] [--gpu <mode>] [--help]" -ForegroundColor Cyan
  Write-Host '  --headless         Run without prompts (defaults are applied).'
  Write-Host '  --config <file>    Optional config file persisted to %APPDATA%\AIHub\config.'
  Write-Host '  --install <target> Install a component directly (e.g., webui, kobold, sillytavern, loras, models).'
  Write-Host '  --gpu <mode>       Force GPU mode (nvidia|amd|intel|cpu) and install matching tooling.'
  Write-Host '  --help             Show this help.'
}

function Parse-ExtraArgs {
  param([string[]]$Args)
  $parsed = @{}
  for ($i = 0; $i -lt $Args.Count; $i++) {
    $arg = $Args[$i]
    switch ($arg) {
      '--headless' { $parsed['Headless'] = $true }
      '--config' {
        if ($i + 1 -lt $Args.Count) { $parsed['Config'] = $Args[$i + 1]; $i++ }
      }
      '--install' {
        if ($i + 1 -lt $Args.Count) { $parsed['Install'] = $Args[$i + 1]; $i++ }
      }
      '--gpu' {
        if ($i + 1 -lt $Args.Count) { $parsed['Gpu'] = $Args[$i + 1]; $i++ }
      }
      '--help' { $parsed['Help'] = $true }
      default { }
    }
  }
  return $parsed
}

$extra = Parse-ExtraArgs -Args $RemainingArgs
if ($extra.ContainsKey('Help')) { $Help = $true }
if ($extra.ContainsKey('Headless')) { $Headless = $true }
if ($extra.ContainsKey('Config')) { $Config = $extra['Config'] }
if ($extra.ContainsKey('Install')) { $Install = $extra['Install'] }
if ($extra.ContainsKey('Gpu')) { $Gpu = $extra['Gpu'] }

if ($Help) { Show-Usage; exit 0 }

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path "$ScriptDir"
$LogDir = if ($Env:LOCALAPPDATA) { Join-Path $Env:LOCALAPPDATA "AIHub/logs" } else { Join-Path $env:USERPROFILE ".config/aihub" }
$ConfigDir = if ($Env:APPDATA) { Join-Path $Env:APPDATA "AIHub/config" } else { Join-Path $env:USERPROFILE ".config/aihub" }
$ConfigPath = $null
$LogPath = Join-Path $LogDir "install.log"

function Ensure-Directory {
  param([string]$Path)
  if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
}

Ensure-Directory $LogDir
Ensure-Directory $ConfigDir
if (-not (Test-Path $LogPath)) { New-Item -ItemType File -Path $LogPath -Force | Out-Null }

$Env:AIHUB_LOG_PATH = $LogPath
$Env:AIHUB_CONFIG_DIR = $ConfigDir

function Write-Log {
  param([string]$Message, [string]$Level = "INFO")
  $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $line = "[$stamp][$Level] $Message"
  Write-Host $line
  Add-Content -Path $LogPath -Value $line
}

function Resolve-ConfigPath {
  if ($Config) {
    if (Test-Path $Config) {
      return Join-Path $ConfigDir (Split-Path $Config -Leaf)
    }
    return $Config
  }
  return Join-Path $ConfigDir "installer.conf"
}

$ConfigPath = Resolve-ConfigPath
Write-Log "AI Hub Windows installer starting (headless=$($Headless.IsPresent -or $Headless), install=$Install, gpu=$Gpu)."
Write-Log "Log path: $LogPath"
Write-Log "Config path: $ConfigPath"

function Persist-ConfigFile {
  if ($Config -and (Test-Path $Config)) {
    try {
      Copy-Item -Path $Config -Destination $ConfigPath -Force
      Write-Log "Config file '$Config' copied to $ConfigPath"
    } catch {
      Write-Log "Failed to copy config file: $_" "ERROR"
    }
  } elseif (-not (Test-Path $ConfigPath)) {
    try {
      New-Item -ItemType File -Path $ConfigPath -Force | Out-Null
      Write-Log "Created default config placeholder at $ConfigPath"
    } catch {
      Write-Log "Unable to create config file at $ConfigPath: $_" "ERROR"
    }
  } else {
    Write-Log "Using existing config at $ConfigPath"
  }
}

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

function Test-Command {
  param([string]$Name)
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Install-Package {
  param([string]$WingetId, [string]$ChocoId, [string]$Label)
  $pkgId = if ($PackageManager -eq "winget") { $WingetId } else { $ChocoId }
  if (-not $pkgId) { Write-Log "No package id supplied for $Label; skipping." "WARN"; return $false }
  try {
    if ($PackageManager -eq "winget") {
      Write-Log "Installing $Label via winget ($pkgId) ..."
      winget install --id $pkgId --exact --accept-package-agreements --accept-source-agreements --silent | Out-Null
    } else {
      Write-Log "Installing $Label via choco ($pkgId) ..."
      choco install $pkgId -y --no-progress | Out-Null
    }
    return $true
  } catch {
    Write-Log "Failed to install $Label ($pkgId): $_" "ERROR"
    return $false
  }
}

function Ensure-Dependency {
  param(
    [string]$Command,
    [string]$Label,
    [string]$WingetId,
    [string]$ChocoId
  )

  if (Test-Command $Command) {
    $version = try { & $Command --version 2>$null | Select-Object -First 1 } catch { "(version unavailable)" }
    Write-Log "$Label present: $version"
    return
  }

  $installed = Install-Package -WingetId $WingetId -ChocoId $ChocoId -Label $Label
  if (Test-Command $Command) {
    $version = try { & $Command --version 2>$null | Select-Object -First 1 } catch { "(version unavailable)" }
    Write-Log "$Label installed successfully: $version"
  } elseif ($installed) {
    Write-Log "$Label installation attempted but command still missing." "WARN"
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
  Ensure-Dependency -Command $dep.Cmd -Label $dep.Label -WingetId $dep.Winget -ChocoId $dep.Choco
}

function Ensure-Downloader {
  if (Test-Command 'aria2c' -or Test-Command 'wget' -or Test-Command 'curl') {
    return
  }
  Write-Log "No downloader available after installation attempts." "ERROR"
}

Ensure-Downloader

function Ensure-GpuTooling {
  param([string]$Mode)
  $modeLower = $Mode.ToLower()
  switch -regex ($modeLower) {
    "nvidia" {
      Install-Package -WingetId "Nvidia.CUDA" -ChocoId "cuda" -Label "NVIDIA CUDA toolkit" | Out-Null
      Write-Log "NVIDIA GPU mode selected. CUDA toolkit install requested."
    }
    "amd" {
      Install-Package -WingetId "AdvancedMicroDevicesInc.RadeonSoftware" -ChocoId "radeon-software" -Label "AMD Radeon software" | Out-Null
      Write-Log "AMD GPU mode selected. Radeon software install requested."
    }
    "intel" {
      Install-Package -WingetId "Intel.IntelDriverAndSupportAssistant" -ChocoId "intel-dsa" -Label "Intel driver tools" | Out-Null
      Write-Log "Intel GPU mode selected. Driver support assistant install requested."
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
  foreach ($path in $paths) { Ensure-Directory $path }
  Write-Log "Provisioned workspace directories under $base"
}

Provision-Workspace

function Load-Manifests {
  $manifestDir = Join-Path $ProjectRoot "manifests"
  $manifestIndex = @{}
  if (-not (Test-Path $manifestDir)) { return $manifestIndex }
  Get-ChildItem $manifestDir -Filter *.json | ForEach-Object {
    try {
      $data = Get-Content $_.FullName -Raw | ConvertFrom-Json
      $count = if ($data.items) { $data.items.Count } else { 0 }
      $name = [System.IO.Path]::GetFileNameWithoutExtension($_.Name).ToLower()
      $manifestIndex[$name] = $_.FullName
      Write-Log "Manifest '$($_.Name)' loaded with $count item(s)."
    } catch {
      Write-Log "Failed to parse manifest $($_.Name): $_" "WARN"
    }
  }
  return $manifestIndex
}

$ManifestIndex = Load-Manifests

function Resolve-InstallScript {
  param([string]$Target)
  if (-not $Target) { return $null }
  $name = $Target.ToLower()
  $scriptPath = Join-Path $ProjectRoot "launcher/windows/install_${name}.ps1"
  if (Test-Path $scriptPath) { return $scriptPath }
  return $null
}

function Invoke-InstallTarget {
  param([string]$Target)
  $script = Resolve-InstallScript -Target $Target
  if (-not $script) {
    if ($ManifestIndex.ContainsKey($Target.ToLower())) {
      Write-Log "Install target '$Target' has a manifest but no Windows install wrapper; install manually." "WARN"
    } else {
      Write-Log "Install target '$Target' not recognized; skipping automatic install." "WARN"
    }
    return
  }

  try {
    Write-Log "Invoking install target '$Target' via $script"
    & powershell.exe -ExecutionPolicy Bypass -File $script --headless
  } catch {
    Write-Log "Failed to invoke install target '$Target': $_" "ERROR"
  }
}

if ($Install) {
  Invoke-InstallTarget -Target $Install
}

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
Ensure-Directory $DesktopDir
Ensure-Directory $StartMenuDir

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

Persist-ConfigFile
Write-Log "AI Hub installer completed."
