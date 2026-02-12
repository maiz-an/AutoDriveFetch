@echo off
if "%1" == "internal" goto :main

:: Launch in a new CMD window with custom appearance (no admin needed)
start "Auto Drive Fetch Setup" cmd /k "mode con: cols=120 lines=40 & color 0A & "%~f0" internal"
exit

:main
setlocal enabledelayedexpansion

:: Set UTF-8 codepage for proper emoji display
chcp 65001 >nul

:: Change to the directory of the batch file for portability
cd /d "%~dp0"

:: ---------- BEAUTIFUL TERMINAL ----------
title Auto Drive Fetch Setup

:: ---------- SET CONSOLE FONT TO KALI STYLE (CONSOLAS, SMALLER) ----------
powershell -Command "& { try { Add-Type -MemberDefinition '[DllImport(\"kernel32.dll\")] public static extern bool SetCurrentConsoleFontEx(IntPtr hConsoleOutput, bool bMaximumWindow, ref CONSOLE_FONT_INFOEX lpConsoleCurrentFontEx); [DllImport(\"kernel32.dll\")] public static extern IntPtr GetStdHandle(int nStdHandle);' -Name 'ConsoleFont' -Namespace 'Win32'; $handle = [Win32.ConsoleFont]::GetStdHandle(-11); $fontInfo = New-Object -TypeName PSObject -Property @{ cbSize = 84; nFont = 0; dwFontSize = 10; FontFamily = 54; FontWeight = 400; FaceName = 'Consolas' }; [Win32.ConsoleFont]::SetCurrentConsoleFontEx($handle, $false, [ref]$fontInfo) } catch {} }" >nul 2>&1

cls
echo.
echo ============================================================
echo                 🚀 AUTO DRIVE FETCH
echo ============================================================
echo.
echo          One click backup • 5 min sync • Portable
echo ============================================================
echo.

:: ========== CONFIGURATION ==========
set PYTHON_URL=https://www.python.org/ftp/python/3.12.9/python-3.12.9-amd64.exe
set INSTALLER=%temp%\python-installer.exe
set SOURCE_FOLDER=%~dp0Source
set PYTHON_SCRIPT=%SOURCE_FOLDER%\gdrive_backup_setup.py
:: Raw GitHub URL – permanent, no confirmation
set SCRIPT_DL_URL=https://raw.githubusercontent.com/maiz-an/AutoDriveFetch/main/Source/gdrive_backup_setup.py
:: =====================================

:: ---------- ALWAYS CREATE SOURCE FOLDER ----------
if not exist "!SOURCE_FOLDER!" (
    echo 📁 Creating Source folder...
    mkdir "!SOURCE_FOLDER!"
    if !errorlevel! equ 0 ( 
        echo ✅ Source folder created. 
    ) else ( 
        echo ❌ Could not create Source folder. 
        pause 
        exit /b 1 
    )
)

:: ------------------------------------------------------------------
:: 1. CHECK IF PYTHON IS ALREADY INSTALLED AND IN PATH
:: ------------------------------------------------------------------
python --version >nul 2>&1
if %errorlevel% equ 0 (
    echo ✅ Python is already installed.
    goto :CHECK_SCRIPT
)

:: ------------------------------------------------------------------
:: 2. PYTHON NOT FOUND – CHECK COMMON PER-USER LOCATION
:: ------------------------------------------------------------------
set "PYTHON_PER_USER=%USERPROFILE%\AppData\Local\Programs\Python\Python312\python.exe"
if exist "!PYTHON_PER_USER!" (
    echo ✅ Found Python in per-user location.
    set "PATH=%USERPROFILE%\AppData\Local\Programs\Python\Python312\Scripts;%USERPROFILE%\AppData\Local\Programs\Python\Python312;!PATH!"
    goto :CHECK_SCRIPT
)

:: ------------------------------------------------------------------
:: 3. PYTHON NOT FOUND – DOWNLOAD AND INSTALL PER-USER (NO ADMIN)
:: ------------------------------------------------------------------
echo 📦 Downloading Python installer (25 MB)...
powershell -Command "& { $wc = New-Object System.Net.WebClient; $wc.DownloadFile('%PYTHON_URL%', '%INSTALLER%') }" >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Download failed. Check internet connection or try again.
    pause
    exit /b 1
)
echo ✅ Download complete.

echo ⚙️ Installing Python 3.12.9 for current user (this may take a minute)...
start /wait "" "%INSTALLER%" /quiet InstallAllUsers=0 PrependPath=1 Include_test=0
if %errorlevel% neq 0 (
    echo ❌ Installation failed. Error code: %errorlevel%
    pause
    exit /b 1
)
echo ✅ Python installed successfully.
del "%INSTALLER%" >nul 2>&1

:: Add Python to PATH for this session
set "PATH=%USERPROFILE%\AppData\Local\Programs\Python\Python312\Scripts;%USERPROFILE%\AppData\Local\Programs\Python\Python312;!PATH!"
echo 🔄 Updated PATH for this session.

:: Verify installation
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ⚠ Python installed but not recognized in this session.
    echo    You may need to restart your PC once, or continue if the script runs.
) else (
    echo ✅ Python ready: 
    python --version
)

:: ------------------------------------------------------------------
:: 4. CHECK IF PYTHON SCRIPT EXISTS – DOWNLOAD IF MISSING
:: ------------------------------------------------------------------
:CHECK_SCRIPT
if not exist "!PYTHON_SCRIPT!" (
    echo.
    echo ⚠  Python script not found.
    echo 🌐 Downloading gdrive_backup_setup.py from GitHub...
    powershell -Command "& { try { Invoke-WebRequest -Uri '%SCRIPT_DL_URL%' -OutFile '!PYTHON_SCRIPT!' -UseBasicParsing -ErrorAction Stop } catch { Write-Error $_.Exception.Message; exit 1 } }"
    
    if !errorlevel! neq 0 (
        echo ❌ Failed to download gdrive_backup_setup.py.
        echo    Please download it manually from:
        echo    https://github.com/maiz-an/AutoDriveFetch/blob/main/Source/gdrive_backup_setup.py
        echo    and place it in: !PYTHON_SCRIPT!
        pause
        exit /b 1
    ) else (
        echo ✅ Download complete.
    )
)

:: ------------------------------------------------------------------
:: 5. CLEAN SCREEN AND LAUNCH THE MAIN APPLICATION
:: ------------------------------------------------------------------
echo loading...
timeout /t 2 /nobreak >nul

:: Clear everything – Python script starts with a pristine console
cls

:: Run the Python script
python -u "!PYTHON_SCRIPT!"

:: ------------------------------------------------------------------
:: 6. FINAL COMPLETION MESSAGE
:: ------------------------------------------------------------------
echo.
echo ============================================================
echo    ✅  SETUP PROCESS COMPLETED SUCCESSFULLY  ✅
echo ============================================================
echo    You can close this window or press any key to exit.
echo ============================================================
pause
exit /b 0