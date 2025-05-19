@echo off
echo Current directory: %CD%
echo Setting up PATH for Flutter and Git...

REM -- Flutter SDK bin
set "PATH=C:\src\flutter\bin;%PATH%"
REM -- Git cmd
set "PATH=C:\Program Files\Git\cmd;%PATH%"
REM -- Dart Pub Cache
set "PATH=C:\Users\cursa\AppData\Local\Pub\Cache\bin;%PATH%"
set "PATH=C:\Users\cursa\AppData\Roaming\Pub\Cache\bin;%PATH%"
REM -- Standard Windows paths (often useful)
set "PATH=C:\Windows\System32;%PATH%"
set "PATH=C:\Windows;%PATH%"
set "PATH=C:\Windows\System32\Wbem;%PATH%"
set "PATH=C:\Windows\System32\WindowsPowerShell\v1.0\;%PATH%"

echo.
echo Updated PATH:
echo %PATH%
echo.
echo Running: flutter build bundle
flutter build bundle > flutter_bundle_log.txt 2>&1
SET flutter_exit_code=%ERRORLEVEL%
echo.
echo 'flutter build bundle' command finished with exit code: %flutter_exit_code%.
echo Please check flutter_bundle_log.txt in the current directory (%CD%) for output.
echo.

IF %flutter_exit_code% EQU 0 (
    echo 'flutter build bundle' seems to have succeeded.
    echo You can now try to build the APK using Gradle from the 'android' subdirectory.
    echo Example commands:
    echo   cd android
    echo   .\gradlew assembleDebug  (for a debug APK)
    echo   .\gradlew assembleRelease (for a release APK, may require signing configuration)
    echo   .\gradlew app:installDebug (to build and install debug APK on a connected device/emulator)
) ELSE (
    echo 'flutter build bundle' seems to have failed. Please review flutter_bundle_log.txt.
)
echo.
pause 