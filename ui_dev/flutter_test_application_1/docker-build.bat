@echo off
echo ===== Flutter Docker Build =====

REM Docker Desktop location
set DOCKER_PATH="C:\Program Files\Docker\Docker\resources\bin\docker.exe"

REM Check if Docker Desktop is running
echo Checking if Docker is running...
%DOCKER_PATH% info >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: Docker does not appear to be running.
    echo Please start Docker Desktop from:
    echo "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    echo.
    echo After Docker Desktop has fully started, try running this script again.
    exit /b 1
)

echo Docker is running! Proceeding with the build...
echo.

echo Step 1: Building the Docker image...
echo This may take some time on first run (~10-15 minutes)
%DOCKER_PATH% build -t flutter_app .

echo.
echo Step 2: Creating an APK using the Docker container...
%DOCKER_PATH% run --rm -v %cd%:/app flutter_app flutter build apk --release

echo.
echo Build complete!
echo The APK file should be at: build\app\outputs\flutter-apk\app-release.apk
echo.
echo To install on connected Android device, run:
echo adb install build\app\outputs\flutter-apk\app-release.apk

pause
