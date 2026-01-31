$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path "$ScriptDir/../.."
$env:PYTHONPATH = $ProjectRoot
python -m modules.runtime.hardware.gpu_diagnostics @args
