@echo off
set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..
set HOST=%AIHUB_WEB_HOST%
if "%HOST%"=="" set HOST=127.0.0.1
set PORT=%AIHUB_WEB_PORT%
if "%PORT%"=="" set PORT=3939

pushd %PROJECT_ROOT%
set PYTHONPATH=%PROJECT_ROOT%;%PYTHONPATH%
set AIHUB_WEB_HOST=%HOST%
set AIHUB_WEB_PORT=%PORT%
python -m modules.runtime.web_launcher --host %HOST% --port %PORT%
popd
