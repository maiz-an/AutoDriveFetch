@echo off
setlocal enabledelayedexpansion

:: ---------- DEBUG LOG ----------
set "DEBUG_LOG=%temp%\autodrivefetch_debug.log"
echo %date% %time% - Session started > "%DEBUG_LOG%"

:: Change to the directory of the batch file for portability
cd /d "%~dp0" || (
    echo [ERROR] Cannot change to batch directory >> "%DEBUG_LOG%"
    pause
    exit /b 1
)

:: ---------- ELEVATE TO ADMIN ----------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator Access...
    powershell -Command "Start-Process '%~f0' -Verb RunAs -WorkingDirectory '%~dp0'"
    exit /b
)

:: ---------- CONFIGURATION ----------
set PYTHON_URL=https://www.python.org/ftp/python/3.12.9/python-3.12.9-amd64.exe
set INSTALLER=%temp%\python-installer.exe
set SOURCE_FOLDER=%~dp0Source
set PYTHON_SCRIPT=%SOURCE_FOLDER%\gdrive_backup_setup.py
set SCRIPT_DL_URL=https://raw.githubusercontent.com/maiz-an/AutoDriveFetch/main/Source/gdrive_backup_setup.py
set VERSION_URL=https://raw.githubusercontent.com/maiz-an/AutoDriveFetch/main/version.txt

:: ---------- CREATE SOURCE FOLDER ----------
if not exist "!SOURCE_FOLDER!" (
    echo Creating Source folder...
    mkdir "!SOURCE_FOLDER!" >> "%DEBUG_LOG%" 2>&1
    if !errorlevel! neq 0 (
        echo [ERROR] Could not create Source folder >> "%DEBUG_LOG%"
        pause
        exit /b 1
    ) else (
        echo Source folder created. >> "%DEBUG_LOG%"
    )
)

:: ------------------------------------------------------------------
:: 1. CHECK / INSTALL PYTHON
:: ------------------------------------------------------------------
call :CHECK_PYTHON
if %errorlevel% neq 0 (
    echo [ERROR] Python setup failed >> "%DEBUG_LOG%"
    pause
    exit /b 1
)

:: ------------------------------------------------------------------
:: 2. DOWNLOAD OR UPDATE PYTHON SCRIPT
:: ------------------------------------------------------------------
call :UPDATE_SCRIPT
if %errorlevel% neq 0 (
    echo [ERROR] Script update failed – but we will try to run existing script >> "%DEBUG_LOG%"
)

:: ------------------------------------------------------------------
:: 3. LAUNCH THE MAIN APPLICATION
:: ------------------------------------------------------------------
echo.
echo Loading...
timeout /t 2 /nobreak >nul
cls
python -u "!PYTHON_SCRIPT!"
echo %date% %time% - Python script exited with code !errorlevel! >> "%DEBUG_LOG%"

:: ------------------------------------------------------------------
:: 4. FINAL MESSAGE
:: ------------------------------------------------------------------
echo.
echo ============================================================
echo          SETUP PROCESS COMPLETED
echo ============================================================
echo    Debug log: %DEBUG_LOG%
echo    Check it if something went wrong.
echo ============================================================
pause
exit /b 0

:: ------------------------------------------------------------------
::  FUNCTIONS
:: ------------------------------------------------------------------

:CHECK_PYTHON
python --version >nul 2>&1
if %errorlevel% equ 0 (
    echo Python is already installed. >> "%DEBUG_LOG%"
    exit /b 0
)

:: Check per-user Python
set "PYTHON_PER_USER=%USERPROFILE%\AppData\Local\Programs\Python\Python312\python.exe"
if exist "!PYTHON_PER_USER!" (
    echo Found Python in per-user location. >> "%DEBUG_LOG%"
    set "PATH=%USERPROFILE%\AppData\Local\Programs\Python\Python312\Scripts;%USERPROFILE%\AppData\Local\Programs\Python\Python312;!PATH!"
    exit /b 0
)

:: Download and install Python
echo Downloading Python installer...
powershell -Command "& { $wc = New-Object System.Net.WebClient; $wc.DownloadFile('%PYTHON_URL%', '%INSTALLER%') }" >> "%DEBUG_LOG%" 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Python download failed >> "%DEBUG_LOG%"
    exit /b 1
)

echo Installing Python 3.12.9 for current user...
start /wait "" "%INSTALLER%" /quiet InstallAllUsers=0 PrependPath=1 Include_test=0
if %errorlevel% neq 0 (
    echo [ERROR] Python installation failed >> "%DEBUG_LOG%"
    exit /b 1
)
del "%INSTALLER%" >nul 2>&1

set "PATH=%USERPROFILE%\AppData\Local\Programs\Python\Python312\Scripts;%USERPROFILE%\AppData\Local\Programs\Python\Python312;!PATH!"
echo Python installed successfully. >> "%DEBUG_LOG%"
exit /b 0

:UPDATE_SCRIPT
if not exist "!PYTHON_SCRIPT!" (
    echo Script not found – downloading latest... >> "%DEBUG_LOG%"
    call :DOWNLOAD_SCRIPT
    exit /b !errorlevel!
)

:: ---- VERSION CHECK ----
echo Checking for updates... >> "%DEBUG_LOG%"

:: Get local version
set LOCAL_VERSION=
for /f "delims=" %%i in ('python -c "import sys; sys.path.insert(0, r'%~dp0Source'); import gdrive_backup_setup; print(gdrive_backup_setup.__version__)" 2^>nul') do set LOCAL_VERSION=%%i
if "!LOCAL_VERSION!"=="" (
    echo [WARNING] Could not determine local version – forcing update. >> "%DEBUG_LOG%"
    set "FORCE_UPDATE=1"
) else (
    echo Local version: !LOCAL_VERSION! >> "%DEBUG_LOG%"
)

:: Get remote version (multiple methods)
set REMOTE_VERSION=
call :FETCH_REMOTE_VERSION
if "!REMOTE_VERSION!"=="" (
    echo [WARNING] Could not fetch remote version – skipping update. >> "%DEBUG_LOG%"
    if "!FORCE_UPDATE!"=="1" (
        echo Force update enabled, but remote version unknown – aborting. >> "%DEBUG_LOG%"
    )
    exit /b 0
)
echo Remote version: !REMOTE_VERSION! >> "%DEBUG_LOG%"

:: Compare versions
if "!FORCE_UPDATE!"=="1" goto :DO_UPDATE
powershell -Command "$local='!LOCAL_VERSION!'; $remote='!REMOTE_VERSION!'; try { if ([System.Version]$local -lt [System.Version]$remote) { exit 0 } else { exit 1 } } catch { exit 2 }"
set COMPARE_RESULT=!errorlevel!
if !COMPARE_RESULT! equ 2 (
    echo [WARNING] Version comparison failed – forcing update. >> "%DEBUG_LOG%"
    goto :DO_UPDATE
)
if !COMPARE_RESULT! equ 0 (
    echo New version available. Updating... >> "%DEBUG_LOG%"
    goto :DO_UPDATE
)
echo You have the latest version. >> "%DEBUG_LOG%"
exit /b 0

:DO_UPDATE
set TEMP_SCRIPT=!temp!\gdrive_backup_setup.tmp.py
call :DOWNLOAD_SCRIPT_TO "!TEMP_SCRIPT!"
if !errorlevel! neq 0 (
    echo [ERROR] Download of new script failed. >> "%DEBUG_LOG%"
    exit /b 1
)
:: Attempt move, then copy as fallback
move /y "!TEMP_SCRIPT!" "!PYTHON_SCRIPT!" >nul 2>&1
if !errorlevel! neq 0 (
    echo Move failed – trying copy... >> "%DEBUG_LOG%"
    copy /y "!TEMP_SCRIPT!" "!PYTHON_SCRIPT!" >nul 2>&1
    if !errorlevel! neq 0 (
        echo [ERROR] Could not replace script. Check permissions. >> "%DEBUG_LOG%"
        del "!TEMP_SCRIPT!" 2>nul
        exit /b 1
    ) else (
        echo Update successful (copy). >> "%DEBUG_LOG%"
        del "!TEMP_SCRIPT!" 2>nul
    )
) else (
    echo Update successful (move). >> "%DEBUG_LOG%"
)
exit /b 0

:FETCH_REMOTE_VERSION
:: Method 1: PowerShell Invoke-WebRequest
for /f "delims=" %%i in ('powershell -NoProfile -Command "try { (Invoke-WebRequest -Uri '%VERSION_URL%' -UseBasicParsing -TimeoutSec 10).Content.Trim() } catch { }" 2^>nul') do set REMOTE_VERSION=%%i
if not "!REMOTE_VERSION!"=="" exit /b 0
:: Method 2: PowerShell WebClient
for /f "delims=" %%i in ('powershell -NoProfile -Command "try { (New-Object System.Net.WebClient).DownloadString('%VERSION_URL%').Trim() } catch { }" 2^>nul') do set REMOTE_VERSION=%%i
if not "!REMOTE_VERSION!"=="" exit /b 0
:: Method 3: curl if available
where curl >nul 2>&1
if !errorlevel! equ 0 (
    for /f "delims=" %%i in ('curl -s --max-time 10 "%VERSION_URL%"') do set REMOTE_VERSION=%%i
)
exit /b 0

:DOWNLOAD_SCRIPT
call :DOWNLOAD_SCRIPT_TO "!PYTHON_SCRIPT!"
exit /b !errorlevel!

:DOWNLOAD_SCRIPT_TO
set "OUT_FILE=%~1"
:: Method 1: PowerShell Invoke-WebRequest
powershell -NoProfile -Command "try { Invoke-WebRequest -Uri '%SCRIPT_DL_URL%' -OutFile '%OUT_FILE%' -UseBasicParsing -ErrorAction Stop } catch { exit 1 }" >> "%DEBUG_LOG%" 2>&1
if !errorlevel! equ 0 exit /b 0
:: Method 2: PowerShell WebClient
powershell -NoProfile -Command "try { (New-Object System.Net.WebClient).DownloadFile('%SCRIPT_DL_URL%', '%OUT_FILE%') } catch { exit 1 }" >> "%DEBUG_LOG%" 2>&1
if !errorlevel! equ 0 exit /b 0
:: Method 3: curl
where curl >nul 2>&1
if !errorlevel! equ 0 (
    curl -s -L --max-time 30 "%SCRIPT_DL_URL%" -o "%OUT_FILE%" >> "%DEBUG_LOG%" 2>&1
    if !errorlevel! equ 0 exit /b 0
)
exit /b 1