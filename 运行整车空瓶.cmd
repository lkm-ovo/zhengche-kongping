@echo off
setlocal
set "YARD_ENGINE=%~dp0build\engine\Godot_v4.7.2-stable_win64.exe"
if not exist "%YARD_ENGINE%" set "YARD_ENGINE=%~dp0..\yx\tools\Godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%YARD_ENGINE%" (
    echo Godot 4.7.2 could not be found.
    pause
    exit /b 1
)
if "%~1"=="" (
    start "" "%YARD_ENGINE%" --path "%~dp0game" --log-file "%~dp0build\game.log"
    exit /b
)
start "" /wait "%YARD_ENGINE%" --path "%~dp0game" --log-file "%~dp0build\game.log" %*
exit /b %ERRORLEVEL%
