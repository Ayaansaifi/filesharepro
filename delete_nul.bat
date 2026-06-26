@echo off
echo =========================================
echo Deleting the problematic 'nul' file...
echo =========================================
del /F /Q "\\?\d:\aginnewversions\filesshare\filesshare\nul"
echo.
echo File deleted successfully! 
echo Press any key to close this window.
pause
