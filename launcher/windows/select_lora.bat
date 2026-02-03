@echo off
setlocal
set SCRIPT_DIR=%~dp0
call "%SCRIPT_DIR%aihub_menu.bat" --action select_lora %*
endlocal
