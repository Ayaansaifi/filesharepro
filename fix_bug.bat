@echo off
echo Fixing your computer's system NUL bug...
echo This will ask for Administrator permission. Please click 'Yes'.

powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command \"icacls \\.\NUL /grant Everyone:F; icacls \\.\NUL /reset; Write-Host ''NUL Device Fixed! Press any key to close...''; [Console]::ReadKey()\"' -Verb RunAs"

echo Done. You can close this window now.
