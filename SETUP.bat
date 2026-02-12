@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

:: ---------- AUTO-ELEVATE TO ADMIN with UNC Path Support ----------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    
    :: Convert to UNC path if on a mapped drive
    set "SCRIPT_PATH=%~f0"
    set "SCRIPT_DIR=%~dp0"
    if "!SCRIPT_PATH:~1,2!"==":" (
        for /f "tokens=2 delims=\" %%a in ('net use !SCRIPT_PATH:~0,2! 2^>nul ^| find "\\"') do (
            set "UNC_PATH=\\%%a!SCRIPT_PATH:~2!"
            set "UNC_DIR=\\%%a!SCRIPT_DIR:~2!"
        )
    )
    if defined UNC_PATH (
        powershell -Command "Start-Process -FilePath '%UNC_PATH%' -Verb RunAs"
    ) else (
        powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    )
    exit /b
)

:: Ensure we're in the correct directory (works even with UNC)
cd /d "%~dp0" || (
    echo ERROR: Cannot access script directory.
    pause
    exit /b 1
)
:: ---------- NOW RUNNING AS ADMIN ----------

title Auto Drive Fetch Setup

:: ========== CONFIGURATION ==========
set PYTHON_URL=https://www.python.org/ftp/python/3.12.9/python-3.12.9-amd64.exe
set INSTALLER=%temp%\python-installer.exe
set PYTHON_SCRIPT=Source\gdrive_backup_setup.py
:: Google Drive file ID for the Python script
set SCRIPT_DL_ID=1TfNKgA-X6Omniqtc3yQEJ0F_EX2NmCqq
:: URL with escaped & (^&) to prevent batch from breaking
set SCRIPT_DL_URL=https://drive.usercontent.google.com/download?id=%SCRIPT_DL_ID%^&confirm=t
:: =====================================

:: ------------------------------------------------------------------
:: 1. CHECK IF PYTHON IS ALREADY INSTALLED AND IN PATH
:: ------------------------------------------------------------------
python --version >nul 2>&1
if %errorlevel% equ 0 (
    echo Python is already installed.
    goto :CHECK_SCRIPT
)

:: ------------------------------------------------------------------
:: 2. PYTHON NOT FOUND – DOWNLOAD AND INSTALL SILENTLY
:: ------------------------------------------------------------------
echo Python not found. Downloading installer (25 MB)...
echo.

:: Download using PowerShell (most reliable)
powershell -Command "& { $wc = New-Object System.Net.WebClient; $wc.DownloadFile('%PYTHON_URL%', '%INSTALLER%') }" >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Download failed. Check internet connection or try again.
    pause
    exit /b 1
)
echo Download complete.

:: ------------------------------------------------------------------
:: 3. SILENT INSTALL WITH FULL PATH CONFIGURATION
:: ------------------------------------------------------------------
echo Installing Python 3.12.9 (this may take a minute)...
start /wait "" "%INSTALLER%" /quiet InstallAllUsers=1 PrependPath=1 Include_test=0
if %errorlevel% neq 0 (
    echo ❌ Installation failed. Error code: %errorlevel%
    pause
    exit /b 1
)
echo Python installed successfully.

:: ------------------------------------------------------------------
:: 4. CLEAN UP INSTALLER
:: ------------------------------------------------------------------
del "%INSTALLER%" >nul 2>&1

:: ------------------------------------------------------------------
:: 5. FORCE PATH UPDATE FOR CURRENT SESSION
:: ------------------------------------------------------------------
echo Updating environment variables for this session...

:: Add Python installation paths to the current process's PATH
for /f "tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\Python\PythonCore\3.12\InstallPath" /ve 2^>nul') do set "PYTHON_HOME=%%b"
if defined PYTHON_HOME (
    set "PATH=%PYTHON_HOME%;%PYTHON_HOME%\Scripts;%PATH%"
) else (
    :: Fallback – try default location
    set "PATH=C:\Program Files\Python312\;C:\Program Files\Python312\Scripts;%PATH%"
)

:: Also notify the system that environment changed (broadcast WM_SETTINGCHANGE)
powershell -Command "& { [Environment]::SetEnvironmentVariable('Path', [Environment]::GetEnvironmentVariable('Path', 'Machine'), 'Machine'); [Environment]::SetEnvironmentVariable('Path', [Environment]::GetEnvironmentVariable('Path', 'User'), 'User') }" >nul 2>&1

echo Python is now available in PATH.

:: ------------------------------------------------------------------
:: 6. VERIFY INSTALLATION
:: ------------------------------------------------------------------
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Python still not recognized. You may need to restart your PC once.
    pause
    exit /b 1
)
echo Python ready: 
python --version

:: ------------------------------------------------------------------
:: 7. CHECK IF PYTHON SCRIPT EXISTS – DOWNLOAD IF MISSING
:: ------------------------------------------------------------------
:CHECK_SCRIPT
if not exist "%PYTHON_SCRIPT%" (
    echo.
    echo ⚠  %PYTHON_SCRIPT% not found.
    echo 📁 Creating Source folder and downloading required script...
    if not exist "Source" mkdir Source
    
    echo Downloading gdrive_backup_setup.py with progress bar...
    powershell -Command "& { try { $wc = New-Object System.Net.WebClient; Write-Progress -Activity 'Downloading gdrive_backup_setup.py' -Status 'Connecting...' -PercentComplete 0; $wc.DownloadFile('%SCRIPT_DL_URL%', '%PYTHON_SCRIPT%'); Write-Progress -Activity 'Downloading gdrive_backup_setup.py' -Status 'Complete' -PercentComplete 100; Start-Sleep -Milliseconds 500; Write-Progress -Activity 'Downloading gdrive_backup_setup.py' -Completed } catch { Write-Error $_.Exception.Message; exit 1 } }"
    
    if %errorlevel% neq 0 (
        echo ❌ Failed to download gdrive_backup_setup.py.
        echo    Please download it manually from:
        echo    https://drive.google.com/file/d/%SCRIPT_DL_ID%/view
        echo    and place it in: %~dp0%PYTHON_SCRIPT%
        pause
        exit /b 1
    ) else (
        echo ✅ Download complete.
    )
)

:: ------------------------------------------------------------------
:: 8. LAUNCH THE ACTUAL BACKUP SCRIPT
:: ------------------------------------------------------------------
:RUN_SCRIPT
echo.
echo Launching Auto Drive Fetch Setup...
echo.

if not exist "%PYTHON_SCRIPT%" (
    echo ❌ ERROR: %PYTHON_SCRIPT% still missing after download attempt.
    pause
    exit /b 1
)

python -u "%PYTHON_SCRIPT%"
pause
exit /b 0