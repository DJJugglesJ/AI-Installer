@echo off
setlocal ENABLEDELAYEDEXPANSION

rem --- Locate project root ---
set "SCRIPT_DIR=%~dp0"
rem Go one level up from the script directory
pushd "%SCRIPT_DIR%.."
set "PROJECT_ROOT=%CD%"
popd

rem --- Host/port defaults ---
if not defined AIHUB_WEB_HOST set "AIHUB_WEB_HOST=127.0.0.1"
if not defined AIHUB_WEB_PORT set "AIHUB_WEB_PORT=3939"

set "HOST=%AIHUB_WEB_HOST%"
set "PORT=%AIHUB_WEB_PORT%"

rem --- Check Python presence ---
where python >nul 2>&1
if errorlevel 1 (
  echo Python 3.6 or newer is required to run the AI Hub web launcher.
  exit /b 1
)

rem --- Detect Python major/minor version safely ---
for /f "tokens=1,2" %%i in ('
  python -c "import sys; print(sys.version_info[0], sys.version_info[1])"
') do (
  set "PY_MAJOR=%%i"
  set "PY_MINOR=%%j"
)

if not defined PY_MAJOR (
  echo Failed to detect Python version.
  exit /b 1
)

rem --- Version checks (using delayed expansion) ---
if !PY_MAJOR! LSS 3 (
  echo Python !PY_MAJOR!.!PY_MINOR! is not supported. Please upgrade to Python 3.6 or newer ^(3.7+ recommended^).
  exit /b 1
)

if !PY_MAJOR! EQU 3 if !PY_MINOR! LSS 6 (
  echo Python !PY_MAJOR!.!PY_MINOR! is not supported. Please upgrade to Python 3.6 or newer ^(3.7+ recommended^).
  exit /b 1
)

rem --- Python 3.6 dataclasses backport ---
if !PY_MAJOR! EQU 3 if !PY_MINOR! EQU 6 (
  echo Python 3.6 detected; ensuring dataclasses backport is installed...
  python -m pip show dataclasses >nul 2>&1
  if errorlevel 1 (
    python -m pip install dataclasses
    if errorlevel 1 (
      echo Failed to install the dataclasses backport required for Python 3.6.
      exit /b 1
    )
  ) else (
    echo dataclasses backport already installed.
  )
)

rem --- Start web launcher ---
pushd "%PROJECT_ROOT%"
set "PYTHONPATH=%PROJECT_ROOT%;%PYTHONPATH%"
set "AIHUB_WEB_HOST=%HOST%"
set "AIHUB_WEB_PORT=%PORT%"

rem NOTE: use the server module, not the package root
python -m modules.runtime.web_launcher.server serve --host %HOST% --port %PORT%

popd
endlocal
