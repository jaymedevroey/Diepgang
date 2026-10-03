@echo off
rem Windows-release-export naar builds\windows\Diepgang.exe.
rem Bewust NIET headless: de shader-baker heeft een GPU nodig. Er verschijnt kort een editorvenster.
setlocal
cd /d "%~dp0.."
if not exist builds\windows mkdir builds\windows
call tools\godot.cmd --path game --export-release "Windows Desktop" ../builds/windows/Diepgang.exe
if errorlevel 1 (
  echo Export mislukt 1>&2
  exit /b 1
)
copy /y docs\playtest-m3.md builds\windows\LEESMIJ.txt >nul
echo Klaar: builds\windows\Diepgang.exe
