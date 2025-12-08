@echo off
setlocal
set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..
set LOG_PATH=%AIHUB_LOG_PATH%
if "%LOG_PATH%"=="" (
  if not "%LOCALAPPDATA%"=="" (
    set LOG_PATH=%LOCALAPPDATA%\AIHub\logs\install.log
  ) else (
    set LOG_PATH=%USERPROFILE%\.config\aihub\install.log
  )
)

for %%P in (%AIHUB_PYTHON%) do if not "%%~P"=="" set PY_CMD=%%~P
if "%PY_CMD%"=="" if exist "%PROJECT_ROOT%\.venv\Scripts\python.exe" set PY_CMD=%PROJECT_ROOT%\.venv\Scripts\python.exe
if "%PY_CMD%"=="" set PY_CMD=python
%PY_CMD% --version >NUL 2>&1
if errorlevel 1 (
  set PY_CMD=py -3
  %PY_CMD% --version >NUL 2>&1
  if errorlevel 1 (
    echo Python was not found. Install Python 3 or run inside WSL2 (Ubuntu recommended).
    exit /b 1
  )
)

for %%D in ("%LOG_PATH%") do set LOG_DIR=%%~dpD
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
if not exist "%LOG_PATH%" type NUL >> "%LOG_PATH%"
set AIHUB_LOG_PATH=%LOG_PATH%

where wsl.exe >NUL 2>&1
if errorlevel 1 (
  echo WSL2 not detected. Shell-heavy actions may require WSL; use --detect-gpu for hardware info.
)

pushd %PROJECT_ROOT%
set PYTHONPATH=%PROJECT_ROOT%;%PYTHONPATH%
%PY_CMD% launcher\aihub_menu.py %*
popd
endlocal
