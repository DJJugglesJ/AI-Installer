@echo off
setlocal
set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..
set PYTHONPATH=%PROJECT_ROOT%
python -m modules.runtime.hardware.gpu_diagnostics %*
endlocal
