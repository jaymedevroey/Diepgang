@echo off
rem Start de vastgepinde Godot 4.7.2 (console-variant, zodat output zichtbaar is).
rem Gebruik: tools\godot.cmd [godot-argumenten]   bv. tools\godot.cmd --path game --editor
set "GODOT_EXE=%LOCALAPPDATA%\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%GODOT_EXE%" (
  echo Godot 4.7.2 niet gevonden op %GODOT_EXE% 1>&2
  exit /b 1
)
"%GODOT_EXE%" %*
