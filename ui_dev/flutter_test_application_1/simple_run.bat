@echo off
echo ===== Flutter Direct Runner =====
echo.

set FLUTTER_ROOT=C:\flutter
set DART_EXE=%FLUTTER_ROOT%\bin\cache\dart-sdk\bin\dart.exe
set FLUTTER_TOOLS=%FLUTTER_ROOT%\bin\cache\flutter_tools.snapshot
set PACKAGES=%FLUTTER_ROOT%\packages\flutter_tools\.dart_tool\package_config.json

REM Step 1: Run pub get
echo Running pub get...
"%DART_EXE%" --packages="%PACKAGES%" "%FLUTTER_TOOLS%" pub get

REM Step 2: Build for Android
echo.
echo Building for Android...
"%DART_EXE%" --packages="%PACKAGES%" "%FLUTTER_TOOLS%" build apk

echo.
echo Done! The build output is in build\app\outputs\flutter-apk
echo You can install the APK using:
echo adb install build\app\outputs\flutter-apk\app-release.apk
echo.
