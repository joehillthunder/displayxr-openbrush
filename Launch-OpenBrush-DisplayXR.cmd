@echo off
rem Launch Open Brush on DisplayXR. The options and notes are in
rem Launch-OpenBrush-DisplayXR.ps1, e.g.  Launch-OpenBrush-DisplayXR.cmd -Runtime dev -Fullscreen
where pwsh >nul 2>nul || (echo This needs PowerShell 7: winget install Microsoft.PowerShell & exit /b 1)
pwsh -NoProfile -File "%~dp0Launch-OpenBrush-DisplayXR.ps1" %*
