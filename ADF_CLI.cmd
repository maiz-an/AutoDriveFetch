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
set PYTHON_URL_32=https://www.python.org/ftp/python/3.12.9/python-3.12.9.exe
set INSTALLER=%temp%\python-installer.exe
set SOURCE_FOLDER=%~dp0Source
set PYTHON_SCRIPT=%SOURCE_FOLDER%\gdrive_backup_setup.py
set SCRIPT_DL_URL=https://raw.githubusercontent.com/maiz-an/AutoDriveFetch/main/Source/gdrive_backup_setup.py
set VERSION_URL=https://raw.githubusercontent.com/maiz-an/AutoDriveFetch/main/version.txt
set MAX_RETRIES=3

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
set UPDATE_RESULT=!errorlevel!
if !UPDATE_RESULT! neq 0 (
    echo [WARNING] Script update failed – using existing version. >> "%DEBUG_LOG%"
    timeout /t 2 >nul
)

:: ------------------------------------------------------------------
:: 3. LAUNCH THE MAIN APPLICATION
:: ------------------------------------------------------------------
echo.
echo Loading...
timeout /t 2 /nobreak >nul
cls

:: Run Python script and capture exit code
python -u "!PYTHON_SCRIPT!"
set PY_EXIT=!errorlevel!
echo %date% %time% - Python script exited with code !PY_EXIT! >> "%DEBUG_LOG%"

:: Handle Python errors with visible pause
if !PY_EXIT! neq 0 (
    echo.
    echo [91m[ERROR] Python script crashed with code !PY_EXIT![0m
    echo Check the debug log: %DEBUG_LOG%
    pause
)

:: ------------------------------------------------------------------
:: 4. FINAL MESSAGE (always visible)
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

:: Check per-user Python (64-bit)
set "PYTHON_PER_USER=%USERPROFILE%\AppData\Local\Programs\Python\Python312\python.exe"
if exist "!PYTHON_PER_USER!" (
    echo Found Python in per-user location. >> "%DEBUG_LOG%"
    set "PATH=%USERPROFILE%\AppData\Local\Programs\Python\Python312\Scripts;%USERPROFILE%\AppData\Local\Programs\Python\Python312;!PATH!"
    python --version >nul 2>&1
    if !errorlevel! equ 0 exit /b 0
)

:: Check per-user Python (32-bit fallback)
set "PYTHON_PER_USER_32=%USERPROFILE%\AppData\Local\Programs\Python\Python312-32\python.exe"
if exist "!PYTHON_PER_USER_32!" (
    echo Found Python 32-bit in per-user location. >> "%DEBUG_LOG%"
    set "PATH=%USERPROFILE%\AppData\Local\Programs\Python\Python312-32\Scripts;%USERPROFILE%\AppData\Local\Programs\Python\Python312-32;!PATH!"
    python --version >nul 2>&1
    if !errorlevel! equ 0 exit /b 0
)

:: Download and install Python
echo Downloading Python installer (64-bit)...
set DOWNLOAD_OK=0
for /l %%i in (1,1,%MAX_RETRIES%) do (
    echo Attempt %%i of %MAX_RETRIES%... >> "%DEBUG_LOG%"
    powershell -Command "& { $wc = New-Object System.Net.WebClient; $wc.DownloadFile('%PYTHON_URL%', '%INSTALLER%') }" >> "%DEBUG_LOG%" 2>&1
    if !errorlevel! equ 0 (
        if exist "%INSTALLER%" (
            for %%A in ("%INSTALLER%") do set SIZE=%%~zA
            if !SIZE! gtr 1000000 (
                set DOWNLOAD_OK=1
                echo Download successful (64-bit). >> "%DEBUG_LOG%"
                goto :INSTALL_PYTHON
            ) else (
                echo Installer too small (!SIZE! bytes), retrying... >> "%DEBUG_LOG%"
                del "%INSTALLER%" 2>nul
            )
        )
    )
    timeout /t 2 >nul
)

:: Fallback to 32-bit installer
echo 64-bit download failed, trying 32-bit...
for /l %%i in (1,1,%MAX_RETRIES%) do (
    echo Attempt %%i of %MAX_RETRIES% (32-bit)... >> "%DEBUG_LOG%"
    powershell -Command "& { $wc = New-Object System.Net.WebClient; $wc.DownloadFile('%PYTHON_URL_32%', '%INSTALLER%') }" >> "%DEBUG_LOG%" 2>&1
    if !errorlevel! equ 0 (
        if exist "%INSTALLER%" (
            for %%A in ("%INSTALLER%") do set SIZE=%%~zA
            if !SIZE! gtr 1000000 (
                set DOWNLOAD_OK=1
                echo Download successful (32-bit). >> "%DEBUG_LOG%"
                goto :INSTALL_PYTHON
            ) else (
                echo Installer too small (!SIZE! bytes), retrying... >> "%DEBUG_LOG%"
                del "%INSTALLER%" 2>nul
            )
        )
    )
    timeout /t 2 >nul
)

if !DOWNLOAD_OK! equ 0 (
    echo [ERROR] Python download failed after %MAX_RETRIES% attempts. >> "%DEBUG_LOG%"
    exit /b 1
)

:INSTALL_PYTHON
echo Installing Python 3.12.9 for current user...
start /wait "" "%INSTALLER%" /quiet InstallAllUsers=0 PrependPath=1 Include_test=0
if %errorlevel% neq 0 (
    echo [ERROR] Python installation failed with code %errorlevel%. >> "%DEBUG_LOG%"
    del "%INSTALLER%" 2>nul
    exit /b 1
)
del "%INSTALLER%" >nul 2>&1

:: Refresh PATH and verify installation
set "PATH=%USERPROFILE%\AppData\Local\Programs\Python\Python312\Scripts;%USERPROFILE%\AppData\Local\Programs\Python\Python312;%PATH%"
set "PATH=%USERPROFILE%\AppData\Local\Programs\Python\Python312-32\Scripts;%USERPROFILE%\AppData\Local\Programs\Python\Python312-32;%PATH%"
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Python installed but not recognized in PATH. >> "%DEBUG_LOG%"
    exit /b 1
)
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
    echo [WARNING] Could not determine local version. >> "%DEBUG_LOG%"
    set "LOCAL_VERSION=0.0.0"
)
echo Local version: !LOCAL_VERSION! >> "%DEBUG_LOG%"

:: Get remote version with retries
set REMOTE_VERSION=
call :FETCH_REMOTE_VERSION
if "!REMOTE_VERSION!"=="" (
    echo [WARNING] Could not fetch remote version. Skipping update. >> "%DEBUG_LOG%"
    exit /b 0
)
echo Remote version: !REMOTE_VERSION! >> "%DEBUG_LOG%"

:: Compare versions
powershell -Command "$local='!LOCAL_VERSION!'; $remote='!REMOTE_VERSION!'; try { if ([System.Version]$local -lt [System.Version]$remote) { exit 0 } else { exit 1 } } catch { exit 2 }"
set COMPARE_RESULT=!errorlevel!
if !COMPARE_RESULT! equ 2 (
    echo [WARNING] Version comparison failed. Skipping update. >> "%DEBUG_LOG%"
    exit /b 0
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

:: Replace script with move/copy fallback
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

:: --- VERIFY THE UPDATE ---
echo Verifying updated script... >> "%DEBUG_LOG%"
timeout /t 1 /nobreak >nul
for /f "delims=" %%i in ('python -c "import sys; sys.path.insert(0, r'%~dp0Source'); import gdrive_backup_setup; print(gdrive_backup_setup.__version__)" 2^>nul') do set NEW_VERSION=%%i
if "!NEW_VERSION!"=="!REMOTE_VERSION!" (
    echo Verified: script is now version !NEW_VERSION!. >> "%DEBUG_LOG%"
) else (
    echo [ERROR] Script update verification failed! Got version !NEW_VERSION! >> "%DEBUG_LOG%"
    pause
    exit /b 1
)

:: Small delay to let antivirus release file locks
timeout /t 1 /nobreak >nul
exit /b 0

:FETCH_REMOTE_VERSION
set "REMOTE_VERSION="
set RETRY_COUNT=0

:RETRY_VERSION
set /a RETRY_COUNT+=1
if !RETRY_COUNT! gtr %MAX_RETRIES% exit /b 1

:: Method 1: PowerShell Invoke-WebRequest with cache busting
for /f "delims=" %%i in ('powershell -NoProfile -Command "try { $r = Invoke-WebRequest -Uri '%VERSION_URL%?cachebust=%RANDOM%' -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop; if ($r.StatusCode -eq 200) { $r.Content.Trim() } } catch { }" 2^>nul') do set REMOTE_VERSION=%%i
if not "!REMOTE_VERSION!"=="" exit /b 0

:: Method 2: PowerShell WebClient
for /f "delims=" %%i in ('powershell -NoProfile -Command "try { $c = New-Object System.Net.WebClient; $c.DownloadString('%VERSION_URL%').Trim() } catch { }" 2^>nul') do set REMOTE_VERSION=%%i
if not "!REMOTE_VERSION!"=="" exit /b 0

:: Method 3: curl if available
where curl >nul 2>&1
if !errorlevel! equ 0 (
    for /f "delims=" %%i in ('curl -s --max-time 10 "%VERSION_URL%"') do set REMOTE_VERSION=%%i
    if not "!REMOTE_VERSION!"=="" exit /b 0
)

timeout /t 2 >nul
goto :RETRY_VERSION

:DOWNLOAD_SCRIPT
call :DOWNLOAD_SCRIPT_TO "!PYTHON_SCRIPT!"
exit /b !errorlevel!

:DOWNLOAD_SCRIPT_TO
set "OUT_FILE=%~1"
set RETRY_COUNT=0

:RETRY_DOWNLOAD
set /a RETRY_COUNT+=1
if !RETRY_COUNT! gtr %MAX_RETRIES% exit /b 1

:: Method 1: PowerShell Invoke-WebRequest
powershell -NoProfile -Command "try { Invoke-WebRequest -Uri '%SCRIPT_DL_URL%' -OutFile '%OUT_FILE%' -UseBasicParsing -ErrorAction Stop } catch { exit 1 }" >> "%DEBUG_LOG%" 2>&1
if !errorlevel! equ 0 (
    if exist "%OUT_FILE%" (
        for %%A in ("%OUT_FILE%") do set SIZE=%%~zA
        if !SIZE! gtr 1000 exit /b 0
    )
)

:: Method 2: PowerShell WebClient
powershell -NoProfile -Command "try { (New-Object System.Net.WebClient).DownloadFile('%SCRIPT_DL_URL%', '%OUT_FILE%') } catch { exit 1 }" >> "%DEBUG_LOG%" 2>&1
if !errorlevel! equ 0 (
    if exist "%OUT_FILE%" (
        for %%A in ("%OUT_FILE%") do set SIZE=%%~zA
        if !SIZE! gtr 1000 exit /b 0
    )
)

:: Method 3: curl
where curl >nul 2>&1
if !errorlevel! equ 0 (
    curl -s -L --max-time 30 "%SCRIPT_DL_URL%" -o "%OUT_FILE%" >> "%DEBUG_LOG%" 2>&1
    if !errorlevel! equ 0 (
        if exist "%OUT_FILE%" (
            for %%A in ("%OUT_FILE%") do set SIZE=%%~zA
            if !SIZE! gtr 1000 exit /b 0
        )
    )
)

timeout /t 2 >nul
goto :RETRY_DOWNLOAD