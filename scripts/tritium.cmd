@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "DEFAULT_REPO_ROOT=%%~fI"

if defined TRITIUM_HOME (
    set "TRITIUM_HOME_PATH=%TRITIUM_HOME%"
) else (
set "TRITIUM_HOME_PATH=%USERPROFILE%\.tritium-os"
)

set "REPO_ROOT=%TRITIUM_REPO_ROOT%"
if exist "%DEFAULT_REPO_ROOT%\runtime\cli\tritium.js" (
    set "REPO_ROOT=%DEFAULT_REPO_ROOT%"
)
if not defined REPO_ROOT if exist "%TRITIUM_HOME_PATH%\state\repo-root" (
    for /f "usebackq delims=" %%I in ("%TRITIUM_HOME_PATH%\state\repo-root") do if not defined REPO_ROOT set "REPO_ROOT=%%I"
)

if not exist "%REPO_ROOT%\runtime\cli\tritium.js" (
    echo error: unable to locate Tritium repo root 1>&2
    echo re-run scripts\install.ps1 from a Tritium checkout or set TRITIUM_REPO_ROOT 1>&2
    exit /b 1
)

node "%REPO_ROOT%\runtime\cli\tritium.js" %*
exit /b %ERRORLEVEL%
