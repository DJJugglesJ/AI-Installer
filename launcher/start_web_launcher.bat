@echo off
set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..
set HOST=%AIHUB_WEB_HOST%
if "%HOST%"=="" set HOST=127.0.0.1
set PORT=%AIHUB_WEB_PORT%
if "%PORT%"=="" set PORT=3939

where python >nul 2>&1
if %ERRORLEVEL% neq 0 (
  echo Python 3.6 or newer is required to run the AI Hub web launcher.
  exit /b 1
)

for /f "tokens=1,2 delims=." %%i in ('python -c "import sys; print(str(sys.version_info[0]) + '.' + str(sys.version_info[1]))"') do (
  set PY_MAJOR=%%i
  set PY_MINOR=%%j
)

if %PY_MAJOR% LSS 3 (
  echo Python %PY_MAJOR%.%PY_MINOR% is not supported. Please upgrade to Python 3.6 or newer (3.7+ recommended).
  exit /b 1
)

if %PY_MAJOR%==3 if %PY_MINOR% LSS 6 (
  echo Python %PY_MAJOR%.%PY_MINOR% is not supported. Please upgrade to Python 3.6 or newer (3.7+ recommended).
  exit /b 1
)

if %PY_MAJOR%==3 if %PY_MINOR%==6 (
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

pushd %PROJECT_ROOT%
set PYTHONPATH=%PROJECT_ROOT%;%PYTHONPATH%
set AIHUB_WEB_HOST=%HOST%
set AIHUB_WEB_PORT=%PORT%
python -m modules.runtime.web_launcher --host %HOST% --port %PORT%
popd
