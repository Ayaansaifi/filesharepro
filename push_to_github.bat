@echo off
echo ==========================================
echo Pushing FileShare Pro to GitHub...
echo ==========================================
echo.

echo 1. Adding files...
git add -A

echo 2. Committing changes...
git commit -m "v1.3.0: Add Meme generator, advance PDF and Image tools, update privacy policy"

echo 3. Pushing to origin main...
git push origin main

echo.
echo ==========================================
echo DONE! Press any key to exit.
echo ==========================================
pause
