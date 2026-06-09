@echo off
REM Launch the borderless image viewer. Launched hidden by VBS.
powershell.exe -NoProfile -Sta -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0Borderless-Image-Viewer.ps1" %*
