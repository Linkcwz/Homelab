@echo off
REM Restart Windows Explorer (the shell). Worker script.
REM Always launched hidden via Run-Restart-Explorer-Hidden.vbs so no console flashes.
taskkill /f /im explorer.exe >nul 2>&1
start "" explorer.exe
