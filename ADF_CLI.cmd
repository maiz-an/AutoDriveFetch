@echo off
setlocal enabledelayedexpansion

:: ---------- DEBUG LOG ----------
set "DEBUG_LOG=%temp%\autodrivefetch_debug.log"
echo %date% %time% - Session started >> "%DEBUG_LOG%"
echo Script path: %~f0 >> "%DEBUG_LOG%"
echo Current directory: %cd% >> "%DEBUG_LOG%"
echo Arguments: %* >> "%DEBUG_LOG%"

:: If we are the elevated instance, show a pause so the window stays open
if "%1"=="elevated" (
    echo.
    echo ====================================================
    echo Running with Administrator privileges...
    echo This window will pause at the beginning for debugging.
    echo ====================================================
    echo.
    pause
)

:: ---------- CHANGE DIRECTORY ----------
echo [TRACE] Changing to batch directory: %~dp0
cd /d "%~dp0" || (
    echo [ERROR] Cannot change to batch directory >> "%DEBUG_LOG%"
    echo Cannot change to batch directory. Press any key to exit.
    pause
    exit /b 1
)
echo [TRACE] Current directory after cd: %cd%
pause

:: ---------- ELEVATE TO ADMIN ----------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [TRACE] Not admin. Requesting elevation...
    powershell -Command "Start-Process '%~f0' -ArgumentList 'elevated' -Verb RunAs -WorkingDirectory '%~dp0'"
    echo [TRACE] Elevation requested. This window will now close.
    pause
    exit /b
)
echo [TRACE] Already running as admin.
pause

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

echo [TRACE] Configuration set.
pause

:: ---------- CREATE SOURCE FOLDER ----------
if not exist "!SOURCE_FOLDER!" (
    echo [TRACE] Creating Source folder: !SOURCE_FOLDER!
    mkdir "!SOURCE_FOLDER!" >> "%DEBUG_LOG%" 2>&1
    if !errorlevel! neq 0 (
        echo [ERROR] Could not create Source folder >> "%DEBUG_LOG%"
        echo Failed to create Source folder. Press any key to exit.
        pause
        exit /b 1
    ) else (
        echo Source folder created. >> "%DEBUG_LOG%"
    )
) else (
    echo [TRACE] Source folder already exists.
)
pause

:: ---------- CHECK / DOWNLOAD PORTABLE PYTHON ----------
if not exist "!PORTABLE_PYTHON!" (
    echo [TRACE] Portable Python not found. Will download.
    set DOWNLOAD_OK=0
    for /l %%i in (1,1,%MAX_RETRIES%) do (
        echo [TRACE] Attempt %%i of %MAX_RETRIES% to download...
        powershell -Command "try { Invoke-WebRequest -Uri '%PORTABLE_ZIP_URL%' -OutFile '%PORTABLE_ZIP%' -UseBasicParsing } catch { exit 1 }" >> "%DEBUG_LOG%" 2>&1
        if !errorlevel! equ 0 (
            if exist "%PORTABLE_ZIP%" (
                for %%A in ("%PORTABLE_ZIP%") do set SIZE=%%~zA
                echo [TRACE] Downloaded size: !SIZE! bytes
                if !SIZE! gtr 10000000 (  REM ~10 MB
                    set DOWNLOAD_OK=1
                    echo Download successful. >> "%DEBUG_LOG%"
                    goto :EXTRACT_PYTHON
                ) else (
                    echo [TRACE] Download too small, retrying...
                    del "%PORTABLE_ZIP%" 2>nul
                )
            )
        ) else (
            echo [TRACE] PowerShell download failed, trying curl...
            curl -L -o "%PORTABLE_ZIP%" "%PORTABLE_ZIP_URL%" >> "%DEBUG_LOG%" 2>&1
            if !errorlevel! equ 0 (
                if exist "%PORTABLE_ZIP%" (
                    for %%A in ("%PORTABLE_ZIP%") do set SIZE=%%~zA
                    echo [TRACE] Downloaded size via curl: !SIZE! bytes
                    if !SIZE! gtr 10000000 (
                        set DOWNLOAD_OK=1
                        echo Download successful via curl. >> "%DEBUG_LOG%"
                        goto :EXTRACT_PYTHON
                    )
                )
            )
        )
        timeout /t 2 >nul
    )
    if !DOWNLOAD_OK! equ 0 (
        echo [ERROR] Failed to download Portable Python after %MAX_RETRIES% attempts. >> "%DEBUG_LOG%"
        echo Failed to download Portable Python. Please check your internet connection.
        echo URL attempted: %PORTABLE_ZIP_URL%
        pause
        exit /b 1
    )
    
    :EXTRACT_PYTHON
    echo [TRACE] Extracting Portable Python...
    if exist "!PORTABLE_DIR!" (
        echo [TRACE] Removing old PortablePython folder...
        rmdir /s /q "!PORTABLE_DIR!" 2>nul
        if exist "!PORTABLE_DIR!" (
            echo [ERROR] Could not remove existing PortablePython folder. >> "%DEBUG_LOG%"
            echo Failed to remove old PortablePython folder. Check permissions.
            pause
            exit /b 1
        )
    )
    mkdir "!PORTABLE_DIR!" >> "%DEBUG_LOG%" 2>&1
    if !errorlevel! neq 0 (
        echo [ERROR] Failed to create PortablePython directory. >> "%DEBUG_LOG%"
        echo Failed to create PortablePython directory. Check disk space and permissions.
        pause
        exit /b 1
    )
    
    :: Try PowerShell Expand-Archive first
    echo [TRACE] Using Expand-Archive...
    powershell -Command "Expand-Archive -Path '%PORTABLE_ZIP%' -DestinationPath '%PORTABLE_DIR%' -Force" >> "%DEBUG_LOG%" 2>&1
    if !errorlevel! neq 0 (
        echo [TRACE] Expand-Archive failed, trying Shell.Application...
        powershell -Command "$shell = New-Object -ComObject Shell.Application; $zip = $shell.NameSpace('%PORTABLE_ZIP%'); $dest = $shell.NameSpace('%PORTABLE_DIR%'); $dest.CopyHere($zip.Items(), 16)" >> "%DEBUG_LOG%" 2>&1
        if !errorlevel! neq 0 (
            echo [ERROR] Extraction failed with both methods. >> "%DEBUG_LOG%"
            echo Failed to extract PortablePython.zip. The file may be corrupt.
            pause
            exit /b 1
        )
    )
    del "%PORTABLE_ZIP%" 2>nul
    echo [TRACE] Extraction completed.
    pause
) else (
    echo [TRACE] Portable Python already present.
)
pause

:: ---------- VERIFY PORTABLE PYTHON ----------
if not exist "!PORTABLE_PYTHON!" (
    echo [ERROR] Portable Python still not found after setup. >> "%DEBUG_LOG%"
    echo Portable Python executable not found. Looking in: !PORTABLE_PYTHON!
    echo Contents of !PORTABLE_DIR!:
    dir "!PORTABLE_DIR!"
    pause
    exit /b 1
)
echo [TRACE] Portable Python found at !PORTABLE_PYTHON!
pause

:: ------------------------------------------------------------------
:: 2. DOWNLOAD OR UPDATE PYTHON SCRIPT
:: ------------------------------------------------------------------
echo [TRACE] Calling UPDATE_SCRIPT...
call :UPDATE_SCRIPT
set UPDATE_RESULT=!errorlevel!
if !UPDATE_RESULT! neq 0 (
    echo [WARNING] Script update failed – using existing version. >> "%DEBUG_LOG%"
    echo [TRACE] UPDATE_SCRIPT returned error.
    pause
) else (
    echo [TRACE] UPDATE_SCRIPT completed successfully.
)
pause

:: ------------------------------------------------------------------
:: 3. LAUNCH THE MAIN APPLICATION
:: ------------------------------------------------------------------
echo.
echo Loading...
timeout /t 2 /nobreak >nul
cls

echo [TRACE] Launching: "!PORTABLE_PYTHON!" -u "!PYTHON_SCRIPT!"
"!PORTABLE_PYTHON!" -u "!PYTHON_SCRIPT!"
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

:UPDATE_SCRIPT
echo [TRACE] Inside UPDATE_SCRIPT
if not exist "!PYTHON_SCRIPT!" (
    echo Script not found – downloading latest... >> "%DEBUG_LOG%"
    call :DOWNLOAD_SCRIPT
    if !errorlevel! neq 0 (
        echo [ERROR] Failed to download script.
        pause
        exit /b 1
    )
    exit /b !errorlevel!
)

:: ---- VERSION CHECK ----
echo Checking for updates... >> "%DEBUG_LOG%"
echo [TRACE] Getting local version using portable python...

:: Get local version using portable python
set LOCAL_VERSION=
for /f "delims=" %%i in ('"!PORTABLE_PYTHON!" -c "import sys; sys.path.insert(0, r'%SOURCE_FOLDER%'); import ADF_CLI; print(ADF_CLI.__version__)" 2^>nul') do set LOCAL_VERSION=%%i
if "!LOCAL_VERSION!"=="" (
    echo [WARNING] Could not determine local version. >> "%DEBUG_LOG%"
    echo [TRACE] Local version detection returned empty.
    set "LOCAL_VERSION=0.0.0"
)
echo Local version: !LOCAL_VERSION! >> "%DEBUG_LOG%"
echo [TRACE] Local version: !LOCAL_VERSION!
pause

:: Get remote version with retries
set REMOTE_VERSION=
echo [TRACE] Fetching remote version...
call :FETCH_REMOTE_VERSION
if "!REMOTE_VERSION!"=="" (
    echo [WARNING] Could not fetch remote version. Skipping update. >> "%DEBUG_LOG%"
    echo [TRACE] Remote version fetch failed.
    pause
    exit /b 0
)
echo Remote version: !REMOTE_VERSION! >> "%DEBUG_LOG%"
echo [TRACE] Remote version: !REMOTE_VERSION!
pause

:: Compare versions
echo [TRACE] Comparing versions...
powershell -Command "$local='!LOCAL_VERSION!'; $remote='!REMOTE_VERSION!'; try { if ([System.Version]$local -lt [System.Version]$remote) { exit 0 } else { exit 1 } } catch { exit 2 }"
set COMPARE_RESULT=!errorlevel!
if !COMPARE_RESULT! equ 2 (
    echo [WARNING] Version comparison failed. Skipping update. >> "%DEBUG_LOG%"
    echo [TRACE] Version comparison error.
    pause
    exit /b 0
)
if !COMPARE_RESULT! equ 0 (
    echo New version available. Updating... >> "%DEBUG_LOG%"
    echo [TRACE] New version available.
    pause
    goto :DO_UPDATE
)
echo You have the latest version. >> "%DEBUG_LOG%"
echo [TRACE] Already up-to-date.
pause
exit /b 0

:DO_UPDATE
echo [TRACE] Inside DO_UPDATE
set TEMP_SCRIPT=!temp!\ADF_CLI.tmp.py
call :DOWNLOAD_SCRIPT_TO "!TEMP_SCRIPT!"
if !errorlevel! neq 0 (
    echo [ERROR] Download of new script failed. >> "%DEBUG_LOG%"
    echo [TRACE] Download failed.
    pause
    exit /b 1
)

:: Replace script with move/copy fallback
echo [TRACE] Moving temp script to final location...
move /y "!TEMP_SCRIPT!" "!PYTHON_SCRIPT!" >nul 2>&1
if !errorlevel! neq 0 (
    echo Move failed – trying copy... >> "%DEBUG_LOG%"
    copy /y "!TEMP_SCRIPT!" "!PYTHON_SCRIPT!" >nul 2>&1
    if !errorlevel! neq 0 (
        echo [ERROR] Could not replace script. Check permissions. >> "%DEBUG_LOG%"
        del "!TEMP_SCRIPT!" 2>nul
        pause
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
for /f "delims=" %%i in ('"!PORTABLE_PYTHON!" -c "import sys; sys.path.insert(0, r'%SOURCE_FOLDER%'); import ADF_CLI; print(ADF_CLI.__version__)" 2^>nul') do set NEW_VERSION=%%i
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