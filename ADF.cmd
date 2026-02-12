@echo off
setlocal enabledelayedexpansion

:: Change to the directory of the batch file for portability
cd /d "%~dp0"

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator Access...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: ---------- SIMPLE TERMINAL ----------
title Auto Drive Fetch Setup
cls
echo.
echo ============================================================
echo                 AUTO DRIVE FETCH
echo ============================================================
echo.
echo          One click backup - 5 min sync - Portable
echo ============================================================
echo.

:: ========== CONFIGURATION ==========
set PYTHON_URL=https://www.python.org/ftp/python/3.12.9/python-3.12.9-amd64.exe
set INSTALLER=%temp%\python-installer.exe
set SOURCE_FOLDER=%~dp0Source
set PYTHON_SCRIPT=%SOURCE_FOLDER%\gdrive_backup_setup.py
set SCRIPT_DL_URL=https://raw.githubusercontent.com/maiz-an/AutoDriveFetch/main/Source/gdrive_backup_setup.py
:: =====================================

:: ---------- CREATE SOURCE FOLDER ----------
if not exist "!SOURCE_FOLDER!" (
    echo Creating Source folder...
    mkdir "!SOURCE_FOLDER!"
    if !errorlevel! equ 0 ( 
        echo Source folder created. 
    ) else ( 
        echo Could not create Source folder. 
        pause 
        exit /b 1 
    )
)

:: ------------------------------------------------------------------
:: 1. CHECK PYTHON
:: ------------------------------------------------------------------
python --version >nul 2>&1
if %errorlevel% equ 0 (
    echo Python is already installed.
    goto :CHECK_SCRIPT
)

:: ------------------------------------------------------------------
:: 2. CHECK PER-USER PYTHON
:: ------------------------------------------------------------------
set "PYTHON_PER_USER=%USERPROFILE%\AppData\Local\Programs\Python\Python312\python.exe"
if exist "!PYTHON_PER_USER!" (
    echo Found Python in per-user location.
    set "PATH=%USERPROFILE%\AppData\Local\Programs\Python\Python312\Scripts;%USERPROFILE%\AppData\Local\Programs\Python\Python312;!PATH!"
    goto :CHECK_SCRIPT
)

:: ------------------------------------------------------------------
:: 3. DOWNLOAD & INSTALL PYTHON
:: ------------------------------------------------------------------
echo Downloading Python installer (25 MB)...
powershell -Command "& { $wc = New-Object System.Net.WebClient; $wc.DownloadFile('%PYTHON_URL%', '%INSTALLER%') }" >nul 2>&1
if %errorlevel% neq 0 (
    echo Download failed. Check internet connection.
    pause
    exit /b 1
)
echo Download complete.

echo Installing Python 3.12.9 for current user...
start /wait "" "%INSTALLER%" /quiet InstallAllUsers=0 PrependPath=1 Include_test=0
if %errorlevel% neq 0 (
    echo Installation failed. Error code: %errorlevel%
    pause
    exit /b 1
)
echo Python installed successfully.
del "%INSTALLER%" >nul 2>&1

set "PATH=%USERPROFILE%\AppData\Local\Programs\Python\Python312\Scripts;%USERPROFILE%\AppData\Local\Programs\Python\Python312;!PATH!"
echo Updated PATH for this session.

python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Python installed but not recognized in this session.
) else (
    echo Python ready: 
    python --version
)

:: ------------------------------------------------------------------
:: 4. DOWNLOAD PYTHON SCRIPT IF MISSING
:: ------------------------------------------------------------------
:CHECK_SCRIPT
if not exist "!PYTHON_SCRIPT!" (
    echo.
    echo Python script not found.
    echo Downloading gdrive_backup_setup.py from GitHub...
    powershell -Command "& { try { Invoke-WebRequest -Uri '%SCRIPT_DL_URL%' -OutFile '!PYTHON_SCRIPT!' -UseBasicParsing -ErrorAction Stop } catch { Write-Error $_.Exception.Message; exit 1 } }"
    if !errorlevel! neq 0 (
        echo Failed to download.
        echo Please download manually from:
        echo https://github.com/maiz-an/AutoDriveFetch/blob/main/Source/gdrive_backup_setup.py
        echo and place it in: !PYTHON_SCRIPT!
        pause
        exit /b 1
    ) else (
        echo Download complete.
    )
)

:: ------------------------------------------------------------------
:: 5. LAUNCH THE MAIN APPLICATION
:: ------------------------------------------------------------------
echo.
echo Loading...
timeout /t 2 /nobreak >nul

:: Clear screen – Python script starts with pristine console
cls

:: Run the Python script
python -u "!PYTHON_SCRIPT!"

:: ------------------------------------------------------------------
:: 6. FINAL MESSAGE
:: ------------------------------------------------------------------
echo.
echo ============================================================
echo          SETUP PROCESS COMPLETED SUCCESSFULLY
echo ============================================================
echo    You can close this window or press any key to exit.
echo ============================================================
pause
exit /b 0