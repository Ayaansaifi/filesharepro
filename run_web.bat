@echo off
setlocal
set FLUTTER_ROOT=C:\Users\ADMIN\flutter
if exist "%FLUTTER_ROOT%\bin\flutter.bat" (
  set PATH=%FLUTTER_ROOT%\bin;%PATH%
) else (
  echo Flutter not found at %FLUTTER_ROOT%
  echo Install: git clone -b stable https://github.com/flutter/flutter.git %FLUTTER_ROOT%
  pause
  exit /b 1
)
cd /d "%~dp0"
flutter config --enable-web
flutter pub get
flutter run -d chrome --target=lib/main_web.dart --web-port=7357 --web-browser-flag "--disable-web-security"
pause
