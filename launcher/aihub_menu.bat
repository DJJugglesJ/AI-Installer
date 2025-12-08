@echo off
setlocal
set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..
set LOG_PATH=%AIHUB_LOG_PATH%
if "%LOG_PATH%"=="" set LOG_PATH=%USERPROFILE%\.config\aihub\install.log
if not exist "%LOG_PATH%" (
  if not exist "%USERPROFILE%\.config\aihub" mkdir "%USERPROFILE%\.config\aihub"
  type NUL >> "%LOG_PATH%"
)

pushd %PROJECT_ROOT%
set PYTHONPATH=%PROJECT_ROOT%;%PYTHONPATH%
python launcher\aihub_menu.py %*
popd
endlocal
