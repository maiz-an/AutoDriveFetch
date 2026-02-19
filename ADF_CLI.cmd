@echo off
setlocal enabledelayedexpansion

:: ---------- CONFIGURATION ----------
set "PORTABLE_ZIP_URL=https://www.python.org/ftp/python/3.12.9/python-3.12.9-embed-amd64.zip"
set "PORTABLE_ZIP=%temp%\PortablePython.zip"
set "PORTABLE_DIR=%~dp0PortablePython"
set "PORTABLE_PYTHON=%PORTABLE_DIR%\python.exe"
set SOURCE_FOLDER=%~dp0Source
set PYTHON_SCRIPT=%SOURCE_FOLDER%\ADF_CLI.py
set SCRIPT_DL_URL=https://raw.githubusercontent.com/maiz-an/AutoDriveFetch/main/Source/ADF_CLI.py
set VERSION_URL=https://raw.githubusercontent.com/maiz-an/AutoDriveFetch/main/version.txt
set MAX_RETRIES=3

:: ---------- DEBUG LOG ----------
set "DEBUG_LOG=%temp%\autodrivefetch_debug.log"
echo %date% %time% - Session started >> "%DEBUG_LOG%"

:: ---------- IF ELEVATED, PAUSE AT START ----------
if "%1"=="elevated" (
    echo.
    echo ====================================================
    echo Running with Administrator privileges.
    echo This window will pause at each step for debugging.
    echo ====================================================
    echo.
    pause
)

:: ---------- CHANGE TO SCRIPT DIRECTORY ----------
cd /d "%~dp0" || (
    echo [ERROR] Cannot change to script directory.
    pause
    exit /b 1
)

:: ---------- ELEVATE TO ADMIN (if not already) ----------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator Access...
    powershell -Command "Start-Process '%~f0' -ArgumentList 'elevated' -Verb RunAs -WorkingDirectory '%~dp0' -Wait"
    exit /b
)

:: ---------- CREATE SOURCE FOLDER ----------
echo [1] Creating Source folder...
if not exist "!SOURCE_FOLDER!" (
    mkdir "!SOURCE_FOLDER!" >> "%DEBUG_LOG%" 2>&1
    if !errorlevel! neq 0 (
        echo [ERROR] Failed to create Source folder.
        pause
        exit /b 1
    ) else (
        echo [OK] Source folder created.
    )
) else (
    echo [OK] Source folder already exists.
)
pause

:: ---------- CHECK / DOWNLOAD PORTABLE PYTHON ----------
if not exist "!PORTABLE_PYTHON!" (
    echo [2] Portable Python not found. Downloading from python.org...
    set DOWNLOAD_OK=0
    for /l %%i in (1,1,%MAX_RETRIES%) do (
        echo   Attempt %%i of %MAX_RETRIES%...
        
        :: Method 1: PowerShell
        echo     Using PowerShell...
        powershell -Command "try { Invoke-WebRequest -Uri '%PORTABLE_ZIP_URL%' -OutFile '%PORTABLE_ZIP%' -UseBasicParsing } catch { exit 1 }" >> "%DEBUG_LOG%" 2>&1
        if !errorlevel! equ 0 (
            if exist "%PORTABLE_ZIP%" (
                for %%A in ("%PORTABLE_ZIP%") do set SIZE=%%~zA
                if !SIZE! gtr 10000000 (
                    set DOWNLOAD_OK=1
                    echo     [OK] Download successful.
                    goto :EXTRACT
                ) else (
                    echo     [WARNING] File too small (!SIZE! bytes), retrying...
                    del "%PORTABLE_ZIP%" 2>nul
                )
            )
        ) else (
            echo     PowerShell failed.
        )
        
        :: Method 2: curl
        echo     Trying curl...
        curl -L -o "%PORTABLE_ZIP%" "%PORTABLE_ZIP_URL%" >> "%DEBUG_LOG%" 2>&1
        if !errorlevel! equ 0 (
            if exist "%PORTABLE_ZIP%" (
                for %%A in ("%PORTABLE_ZIP%") do set SIZE=%%~zA
                if !SIZE! gtr 10000000 (
                    set DOWNLOAD_OK=1
                    echo     [OK] Download successful via curl.
                    goto :EXTRACT
                ) else (
                    echo     [WARNING] File too small (!SIZE! bytes), retrying...
                    del "%PORTABLE_ZIP%" 2>nul
                )
            )
        ) else (
            echo     curl failed.
        )
        
        timeout /t 2 >nul
    )
    
    if !DOWNLOAD_OK! equ 0 (
        echo [ERROR] Failed to download Portable Python after %MAX_RETRIES% attempts.
        echo Please download manually from:
        echo %PORTABLE_ZIP_URL%
        echo and extract to "%PORTABLE_DIR%"
        pause
        exit /b 1
    )
    
    :EXTRACT
    echo [3] Extracting Portable Python...
    if exist "!PORTABLE_DIR!" (
        echo   Removing old PortablePython folder...
        rmdir /s /q "!PORTABLE_DIR!" 2>nul
    )
    mkdir "!PORTABLE_DIR!" >> "%DEBUG_LOG%" 2>&1
    
    :: Try PowerShell Expand-Archive
    powershell -Command "Expand-Archive -Path '%PORTABLE_ZIP%' -DestinationPath '%PORTABLE_DIR%' -Force" >> "%DEBUG_LOG%" 2>&1
    if !errorlevel! neq 0 (
        echo   PowerShell Expand-Archive failed, trying COM fallback...
        powershell -Command "$shell = New-Object -ComObject Shell.Application; $zip = $shell.NameSpace('%PORTABLE_ZIP%'); $dest = $shell.NameSpace('%PORTABLE_DIR%'); $dest.CopyHere($zip.Items(), 16)" >> "%DEBUG_LOG%" 2>&1
        if !errorlevel! neq 0 (
            echo [ERROR] Extraction failed.
            pause
            exit /b 1
        )
    )
    del "%PORTABLE_ZIP%" 2>nul
    echo [OK] Portable Python extracted.
) else (
    echo [2] Portable Python already present.
)
pause

:: ---------- VERIFY PORTABLE PYTHON ----------
echo [4] Verifying Portable Python...
if not exist "!PORTABLE_PYTHON!" (
    echo [ERROR] python.exe not found in "%PORTABLE_DIR%"
    dir "%PORTABLE_DIR%"
    pause
    exit /b 1
)
echo [OK] Portable Python found at !PORTABLE_PYTHON!
pause

:: ---------- UPDATE SCRIPT ----------
echo [5] Checking for script updates...
call :UPDATE_SCRIPT
if %errorlevel% neq 0 (
    echo [WARNING] Script update failed – using existing version.
    timeout /t 2 >nul
) else (
    echo [OK] Script up to date.
)
pause

:: ---------- LAUNCH MAIN APPLICATION ----------
echo [6] Launching Auto Drive Fetch...
timeout /t 2 /nobreak >nul
cls

"!PORTABLE_PYTHON!" -u "!PYTHON_SCRIPT!"
set PY_EXIT=!errorlevel!
echo %date% %time% - Python script exited with code !PY_EXIT! >> "%DEBUG_LOG%"

if !PY_EXIT! neq 0 (
    echo.
    echo [91m[ERROR] Python script crashed with code !PY_EXIT![0m
    echo Check the debug log: %DEBUG_LOG%
    pause
) else (
    echo.
    echo [OK] Python script finished successfully.
)

:: ---------- FINAL MESSAGE ----------
echo.
echo ============================================================
echo          SETUP PROCESS COMPLETED
echo ============================================================
echo    Debug log: %DEBUG_LOG%
echo    Press any key to close this window.
echo ============================================================
pause
exit /b 0

:: ------------------------------------------------------------------
::  FUNCTIONS
:: ------------------------------------------------------------------

:UPDATE_SCRIPT
if not exist "!PYTHON_SCRIPT!" (
    echo   Script not found – downloading latest...
    call :DOWNLOAD_SCRIPT
    exit /b !errorlevel!
)

:: ---- VERSION CHECK ----
echo   Checking for updates...
set LOCAL_VERSION=
for /f "delims=" %%i in ('"!PORTABLE_PYTHON!" -c "import sys; sys.path.insert(0, r'%SOURCE_FOLDER%'); import ADF_CLI; print(ADF_CLI.__version__)" 2^>nul') do set LOCAL_VERSION=%%i
if "!LOCAL_VERSION!"=="" (
    echo   [WARNING] Could not determine local version.
    set "LOCAL_VERSION=0.0.0"
)
echo   Local version: !LOCAL_VERSION!

set REMOTE_VERSION=
call :FETCH_REMOTE_VERSION
if "!REMOTE_VERSION!"=="" (
    echo   [WARNING] Could not fetch remote version. Skipping update.
    exit /b 0
)
echo   Remote version: !REMOTE_VERSION!

powershell -Command "$local='!LOCAL_VERSION!'; $remote='!REMOTE_VERSION!'; try { if ([System.Version]$local -lt [System.Version]$remote) { exit 0 } else { exit 1 } } catch { exit 2 }"
set COMPARE_RESULT=!errorlevel!
if !COMPARE_RESULT! equ 2 (
    echo   [WARNING] Version comparison failed. Skipping update.
    exit /b 0
)
if !COMPARE_RESULT! equ 0 (
    echo   New version available. Updating...
    goto :DO_UPDATE
)
echo   You have the latest version.
exit /b 0

:DO_UPDATE
set TEMP_SCRIPT=!temp!\ADF_CLI.tmp.py
call :DOWNLOAD_SCRIPT_TO "!TEMP_SCRIPT!"
if !errorlevel! neq 0 (
    echo   [ERROR] Download of new script failed.
    pause
    exit /b 1
)

move /y "!TEMP_SCRIPT!" "!PYTHON_SCRIPT!" >nul 2>&1
if !errorlevel! neq 0 (
    copy /y "!TEMP_SCRIPT!" "!PYTHON_SCRIPT!" >nul 2>&1
    if !errorlevel! neq 0 (
        echo   [ERROR] Could not replace script.
        del "!TEMP_SCRIPT!" 2>nul
        pause
        exit /b 1
    ) else (
        echo   Update successful (copy).
        del "!TEMP_SCRIPT!" 2>nul
    )
) else (
    echo   Update successful (move).
)

timeout /t 1 /nobreak >nul
for /f "delims=" %%i in ('"!PORTABLE_PYTHON!" -c "import sys; sys.path.insert(0, r'%SOURCE_FOLDER%'); import ADF_CLI; print(ADF_CLI.__version__)" 2^>nul') do set NEW_VERSION=%%i
if "!NEW_VERSION!"=="!REMOTE_VERSION!" (
    echo   Verified: script is now version !NEW_VERSION!.
) else (
    echo   [ERROR] Script update verification failed!
    pause
    exit /b 1
)
timeout /t 1 /nobreak >nul
exit /b 0

:FETCH_REMOTE_VERSION
set "REMOTE_VERSION="
set RETRY_COUNT=0

:RETRY_VERSION
set /a RETRY_COUNT+=1
if !RETRY_COUNT! gtr %MAX_RETRIES% exit /b 1

for /f "delims=" %%i in ('powershell -NoProfile -Command "try { $r = Invoke-WebRequest -Uri '%VERSION_URL%?cachebust=%RANDOM%' -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop; if ($r.StatusCode -eq 200) { $r.Content.Trim() } } catch { }" 2^>nul') do set REMOTE_VERSION=%%i
if not "!REMOTE_VERSION!"=="" exit /b 0

for /f "delims=" %%i in ('powershell -NoProfile -Command "try { $c = New-Object System.Net.WebClient; $c.DownloadString('%VERSION_URL%').Trim() } catch { }" 2^>nul') do set REMOTE_VERSION=%%i
if not "!REMOTE_VERSION!"=="" exit /b 0

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

powershell -NoProfile -Command "try { Invoke-WebRequest -Uri '%SCRIPT_DL_URL%' -OutFile '%OUT_FILE%' -UseBasicParsing -ErrorAction Stop } catch { exit 1 }" >> "%DEBUG_LOG%" 2>&1
if !errorlevel! equ 0 (
    if exist "%OUT_FILE%" (
        for %%A in ("%OUT_FILE%") do set SIZE=%%~zA
        if !SIZE! gtr 1000 exit /b 0
    )
)

powershell -NoProfile -Command "try { (New-Object System.Net.WebClient).DownloadFile('%SCRIPT_DL_URL%', '%OUT_FILE%') } catch { exit 1 }" >> "%DEBUG_LOG%" 2>&1
if !errorlevel! equ 0 (
    if exist "%OUT_FILE%" (
        for %%A in ("%OUT_FILE%") do set SIZE=%%~zA
        if !SIZE! gtr 1000 exit /b 0
    )
)

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