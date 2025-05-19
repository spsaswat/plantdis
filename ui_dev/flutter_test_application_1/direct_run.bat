@echo off
REM This script is a workaround for Flutter bat file encoding issues
REM It runs a Dart script that handles building Flutter apps

SETLOCAL
cls
echo ========== Flutter Direct Runner ==========

REM Flutter and Dart paths
SET FLUTTER_ROOT=C:\flutter
SET DART_SDK=%FLUTTER_ROOT%\bin\cache\dart-sdk
SET DART_EXE=%DART_SDK%\bin\dart.exe

REM Check if Dart executable exists
IF NOT EXIST "%DART_EXE%" (
  echo ERROR: Dart executable not found at %DART_EXE%
  echo Please check your Flutter installation
  exit /b 1
)

REM Run the Dart script that handles building
echo Running Flutter builder script...
"%DART_EXE%" "direct_run.dart"

echo.
echo ========== Process completed ==========
echo If the build was successful, you can install the APK using:
echo adb install build\app\outputs\flutter-apk\app-debug.apk
echo.

pause
