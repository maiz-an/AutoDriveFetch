#!/usr/bin/env python3
# -*- coding: utf-8 -*-
r"""
Google Drive Auto Backup – Persistent Parent Folder + Folder Picker + ALWAYS Permanent Install
- First run: asks for parent folder name, saves to settings.json
- Subsequent runs: loads saved parent folder name
- Native Windows folder picker for selecting local backup folder
- ALWAYS installs permanently to %LOCALAPPDATA%\.systembackup
- Adds Windows Defender & Firewall exclusions for the system folder
- Perfect centering, JSON logging, portable.
"""

import os
import sys
import zipfile
import subprocess
import shutil
import getpass
import ctypes
import json
import datetime
import re
import tempfile
from pathlib import Path

# ---------- PATH CONFIGURATION ----------
SCRIPT_DIR = Path(__file__).parent.resolve()
ROOT_DIR = SCRIPT_DIR.parent.resolve()

RCLONE_ZIP = SCRIPT_DIR / "Rclone.zip"
RCLONE_DIR = SCRIPT_DIR / "rclone"
RCLONE_EXE = RCLONE_DIR / "rclone.exe"
RCLONE_CONFIG = SCRIPT_DIR / "rclone.conf"

# Settings file – stores parent folder name etc.
SETTINGS_FILE = SCRIPT_DIR / "settings.json"

LOG_FILE = ROOT_DIR / "log.json"
DRIVEBACKUP_ROOT = ROOT_DIR / "DriveBackup"
SYNC_SCRIPT_NAME = ROOT_DIR / "sync_{}.bat"
LOOP_SCRIPT_NAME = ROOT_DIR / "sync_loop_{}.vbs"
SHORTCUT_NAME = "Google Drive Sync - {}.lnk"

# Permanent installation location
INSTALL_DIR = Path(os.environ['LOCALAPPDATA']) / ".systembackup"

# ========================================

# ---------- PERFECT UI ----------
ENABLE_ANSI = False
try:
    kernel32 = ctypes.windll.kernel32
    kernel32.SetConsoleMode(kernel32.GetStdHandle(-11), 7)
    ENABLE_ANSI = True
except:
    pass

def c(text, color=None, bold=False):
    if not ENABLE_ANSI or not color:
        return text
    codes = {
        'red': '31', 'green': '32', 'yellow': '33', 'blue': '34',
        'magenta': '35', 'cyan': '36', 'white': '37'
    }
    style = '1;' if bold else ''
    return f"\033[{style}{codes.get(color, '0')}m{text}\033[0m"

def strip_ansi(text):
    return re.sub(r'\033\[[0-9;]*m', '', text)

WATERMARK = "⚡ Powered by Maiz"
WIDTH = 70

def center_text(text, width=WIDTH):
    plain = strip_ansi(text)
    if len(plain) >= width:
        return text
    left_pad = (width - len(plain)) // 2
    return ' ' * left_pad + text

def print_header(title):
    print("="*WIDTH)
    print(center_text(f"{c('🚀', 'cyan')}  {c(title, 'cyan', bold=True)}"))
    print(center_text(c(WATERMARK, 'magenta', bold=True)))
    print("="*WIDTH)

def print_subheader(text):
    print(center_text(c(text, 'cyan')))

def print_footer():
    print("="*WIDTH)
    print(center_text(c(WATERMARK, 'magenta', bold=True)))
    print("="*WIDTH)

def print_step(step, description):
    print(f"\n{c('•', 'cyan')}  {c(f'Step {step}:', 'white', bold=True)} {description}")
    log_event("STEP", f"Step {step}: {description}")

def print_success(msg):
    print(f"   {c('✓', 'green', bold=True)} {c(msg, 'green')}")
    log_event("SUCCESS", msg)

def print_error(msg):
    print(f"   {c('✗', 'red', bold=True)} {c(msg, 'red')}")
    log_event("ERROR", msg)

def print_info(msg):
    print(f"   {c('ℹ', 'yellow')} {msg}")
    log_event("INFO", msg)

def print_warning(msg):
    print(f"   {c('⚠', 'yellow', bold=True)} {c(msg, 'yellow')}")
    log_event("WARNING", msg)

def print_separator():
    print("\n" + "─"*WIDTH)

# ---------- JSON LOGGING ----------
def log_event(event_type, message, details=None):
    entry = {
        "timestamp": datetime.datetime.now().isoformat(),
        "event": event_type,
        "message": message
    }
    if details:
        entry["details"] = details

    logs = []
    if LOG_FILE.exists():
        try:
            with open(LOG_FILE, 'r', encoding='utf-8') as f:
                logs = json.load(f)
                if not isinstance(logs, list):
                    logs = []
        except:
            logs = []
    logs.append(entry)
    try:
        with open(LOG_FILE, 'w', encoding='utf-8') as f:
            json.dump(logs, f, indent=2, ensure_ascii=False)
    except:
        pass

# ---------- SETTINGS MANAGEMENT ----------
def load_parent_folder():
    if SETTINGS_FILE.exists():
        try:
            with open(SETTINGS_FILE, 'r', encoding='utf-8') as f:
                settings = json.load(f)
                return settings.get("parent_folder")
        except:
            pass
    return None

def save_parent_folder(folder_name):
    settings = {}
    if SETTINGS_FILE.exists():
        try:
            with open(SETTINGS_FILE, 'r', encoding='utf-8') as f:
                settings = json.load(f)
        except:
            settings = {}
    settings["parent_folder"] = folder_name
    with open(SETTINGS_FILE, 'w', encoding='utf-8') as f:
        json.dump(settings, f, indent=2)

# ---------- FOLDER PICKER (MODERN, BULLETPROOF) ----------
def pick_local_folder():
    """
    Open modern Windows folder picker using multiple methods.
    Returns Path object or None if cancelled/failed.
    """
    # Method 1: Shell.Application COM (most reliable, modern)
    ps_shell = """
$shell = New-Object -ComObject Shell.Application
$folder = $shell.BrowseForFolder(0, 'Select the folder you want to back up to Google Drive', 0, 0)
if ($folder) {
    $folder.Self.Path
}
"""
    try:
        result = subprocess.run(
            ["powershell", "-NoProfile", "-Command", ps_shell],
            capture_output=True, text=True, check=True, timeout=30
        )
        output = result.stdout.strip()
        if output and Path(output).exists():
            return Path(output)
    except Exception as e:
        pass

    # Method 2: OpenFileDialog hack (modern fallback)
    ps_open = """
Add-Type -AssemblyName System.Windows.Forms
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.ValidateNames = $false
$dialog.CheckFileExists = $false
$dialog.CheckPathExists = $true
$dialog.FileName = "Select Folder"
$dialog.Title = "Select the folder you want to back up to Google Drive"
if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    [System.IO.Path]::GetDirectoryName($dialog.FileName)
}
"""
    try:
        result = subprocess.run(
            ["powershell", "-NoProfile", "-Command", ps_open],
            capture_output=True, text=True, check=True, timeout=30
        )
        output = result.stdout.strip()
        if output and Path(output).exists():
            return Path(output)
    except:
        pass

    # Method 3: Classic FolderBrowserDialog (ancient fallback)
    ps_classic = """
Add-Type -AssemblyName System.Windows.Forms
$folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
$folderBrowser.Description = 'Select the folder you want to back up to Google Drive'
$folderBrowser.ShowNewFolderButton = $true
$result = $folderBrowser.ShowDialog()
if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
    $folderBrowser.SelectedPath
}
"""
    try:
        result = subprocess.run(
            ["powershell", "-NoProfile", "-Command", ps_classic],
            capture_output=True, text=True, check=True, timeout=30
        )
        output = result.stdout.strip()
        if output and Path(output).exists():
            return Path(output)
    except:
        pass

    return None

# ---------- RCLONE.ZIP DOWNLOADER (WITH SPINNER) ----------
def download_rclone_zip():
    """
    Download Rclone.zip from Google Drive with live spinner animation.
    Uses only standard library – no external dependencies.
    """
    if RCLONE_ZIP.exists():
        return True

    print_step("dl", "Rclone.zip not found – attempting download")
    print_info("Source: Google Drive (your shared link)")
    
    file_id = "16QfRsPGhQKBJPg1p2ovdhv1R2IhOvp7R"
    gdrive_url = f"https://drive.usercontent.google.com/download?id={file_id}&confirm=t"
    
    # ----- HELPER: SPINNER ANIMATION -----
    def spinner_task(download_func, *args, **kwargs):
        """Run download in thread with animated spinner."""
        import threading, time, sys
        
        result = [False]
        exception = [None]
        
        def target():
            try:
                download_func(*args, **kwargs)
                result[0] = True
            except Exception as e:
                exception[0] = e
        
        thread = threading.Thread(target=target)
        thread.daemon = True
        thread.start()
        
        spinner = ['|', '/', '-', '\\']
        idx = 0
        while thread.is_alive():
            sys.stdout.write(f"\r   {c('⏳', 'yellow')} Downloading... {spinner[idx % 4]}")
            sys.stdout.flush()
            idx += 1
            time.sleep(0.1)
        
        thread.join()
        sys.stdout.write("\r" + " " * 50 + "\r")
        sys.stdout.flush()
        
        if exception[0]:
            raise exception[0]
        return result[0]
    
    # ----- METHOD 1: urllib.request -----
    try:
        import urllib.request
        
        def urllib_download():
            urllib.request.urlretrieve(gdrive_url, RCLONE_ZIP)
            if not (RCLONE_ZIP.exists() and RCLONE_ZIP.stat().st_size > 0):
                raise ValueError("Downloaded file is empty or invalid")
        
        success = spinner_task(urllib_download)
        if success:
            size = RCLONE_ZIP.stat().st_size / (1024*1024)
            print_success(f"Download complete (urllib) – {size:.1f} MB")
            return True
    except Exception as e:
        print_warning(f"urllib download failed: {e}")
        if RCLONE_ZIP.exists():
            RCLONE_ZIP.unlink()
    
    # ----- METHOD 2: PowerShell WebClient -----
    try:
        def powershell_download():
            ps_cmd = f"""
$url = '{gdrive_url}'
$output = '{RCLONE_ZIP}'
$wc = New-Object System.Net.WebClient
$wc.DownloadFile($url, $output)
"""
            subprocess.run(
                ["powershell", "-NoProfile", "-Command", ps_cmd],
                capture_output=True, check=True, timeout=120
            )
            if not (RCLONE_ZIP.exists() and RCLONE_ZIP.stat().st_size > 0):
                raise ValueError("Downloaded file is empty or invalid")
        
        success = spinner_task(powershell_download)
        if success:
            size = RCLONE_ZIP.stat().st_size / (1024*1024)
            print_success(f"Download complete (PowerShell) – {size:.1f} MB")
            return True
    except Exception as e:
        print_warning(f"PowerShell download failed: {e}")
        if RCLONE_ZIP.exists():
            RCLONE_ZIP.unlink()
    
    # ----- ALL METHODS FAILED -----
    print_error("Could not download Rclone.zip automatically.")
    print_info("Please download it manually from:")
    print_info(f"   https://drive.google.com/file/d/{file_id}/view")
    print_info(f"   Then place it in: {SCRIPT_DIR}")
    return False

# ---------- CORE LOGIC ----------
def extract_rclone():
    if RCLONE_EXE.exists():
        return True
    
    if not RCLONE_ZIP.exists():
        if not download_rclone_zip():
            return False
    
    print("Extracting rclone...")
    try:
        with zipfile.ZipFile(RCLONE_ZIP) as zf:
            zf.extractall(RCLONE_DIR)
        for f in RCLONE_DIR.rglob("rclone.exe"):
            shutil.move(str(f), str(RCLONE_EXE))
            break
        for item in RCLONE_DIR.iterdir():
            if item != RCLONE_EXE:
                shutil.rmtree(item, ignore_errors=True) if item.is_dir() else item.unlink()
        return RCLONE_EXE.exists()
    except Exception as e:
        print_error(f"Extraction failed: {e}")
        return False

def is_config_valid():
    if not RCLONE_CONFIG.exists():
        return False
    result = subprocess.run(
        [str(RCLONE_EXE), "--config", str(RCLONE_CONFIG), "listremotes"],
        capture_output=True, text=True
    )
    if result.returncode != 0 or "gdrive:" not in result.stdout:
        return False
    test = subprocess.run(
        [str(RCLONE_EXE), "--config", str(RCLONE_CONFIG), "lsd", "gdrive:"],
        capture_output=True
    )
    return test.returncode == 0

def is_admin():
    try:
        return ctypes.windll.shell32.IsUserAnAdmin() != 0
    except:
        return False

def auto_authentication():
    if is_admin():
        print_separator()
        print_header("🔐  GOOGLE DRIVE AUTHENTICATION")
        print_info("Running as Administrator – automatic authentication not available.")
        print_info("Switching to enhanced manual authentication (config will be auto‑copied).\n")
        return False

    print_separator()
    print_header("🔐  GOOGLE DRIVE AUTHENTICATION")
    log_event("AUTH", "Starting automatic authentication (non-admin)")

    print_info("A browser window will open automatically.")
    print_info("Please log in to your Google account and grant access.")
    print_info("This window will continue automatically after success.\n")

    try:
        subprocess.run(
            [str(RCLONE_EXE), "--config", str(RCLONE_CONFIG),
             "config", "create", "gdrive", "drive", "config_is_local=false"],
            check=True
        )
    except subprocess.CalledProcessError:
        print_error("Authentication command failed.")
        log_event("AUTH_FAILED", "Authentication command failed")
        return False

    if is_config_valid():
        print_success("Authentication successful!")
        log_event("AUTH_SUCCESS", "Google Drive authenticated")
        return True
    else:
        print_error("Authentication failed. Config not created.")
        log_event("AUTH_FAILED", "Config still invalid after command")
        return False

def find_and_copy_config():
    try:
        result = subprocess.run(
            [str(RCLONE_EXE), "config", "file"],
            capture_output=True, text=True, check=True
        )
        lines = result.stdout.strip().splitlines()
        config_path = None
        for line in lines:
            if line.strip().endswith('rclone.conf'):
                config_path = Path(line.strip())
                break
        if not config_path or not config_path.exists():
            print_warning("Could not locate rclone.conf automatically.")
            return False
        shutil.copy2(str(config_path), str(RCLONE_CONFIG))
        print_success(f"Config copied from: {config_path}")
        return True
    except Exception as e:
        print_warning(f"Failed to locate/copy config: {e}")
        return False

def manual_authentication():
    print_separator()
    print_header("🔐  GOOGLE DRIVE AUTHENTICATION")
    log_event("AUTH", "Starting manual authentication")

    print("\n" + center_text("1️⃣  Open a Command Prompt (Win+R → cmd → Enter)"))
    print("\n" + center_text("2️⃣  Copy and paste this command, then press Enter:"))
    print("\n" + center_text(c(f'"{RCLONE_EXE}" config create gdrive drive', 'cyan')))
    print("\n" + center_text("3️⃣  Browser opens → Login → Allow → Code is captured automatically"))
    print("\n" + center_text("4️⃣  After you see 'Success!', return here and press Enter."))
    print()
    
    input(center_text(c("👉  Press Enter AFTER authentication complete...", "cyan")))
    
    print_step("auto", "Locating and copying rclone.conf...")
    if find_and_copy_config():
        print_success("Config copied to Source folder.")
    else:
        print_warning("Could not auto‑copy config. You may need to manually copy rclone.conf to:")
        print_info(f"   {RCLONE_CONFIG}")

    if is_config_valid():
        print_success("Authentication successful! Config is valid.")
        log_event("AUTH_SUCCESS", "Google Drive authenticated")
        return True
    else:
        print_error("Authentication failed. Config is invalid or missing.")
        log_event("AUTH_FAILED", "Config still invalid after manual attempt")
        return False

def create_startup_shortcut(vbs_path, local_name):
    startup_folder = Path(os.environ['APPDATA']) / "Microsoft" / "Windows" / "Start Menu" / "Programs" / "Startup"
    shortcut_path = startup_folder / SHORTCUT_NAME.format(local_name)
    ps_script = f'''
$WScriptShell = New-Object -ComObject WScript.Shell
$shortcut = $WScriptShell.CreateShortcut("{shortcut_path}")
$shortcut.TargetPath = "wscript.exe"
$shortcut.Arguments = '"{vbs_path}"'
$shortcut.WorkingDirectory = "{vbs_path.parent}"
$shortcut.Description = "Google Drive Backup – {local_name}"
$shortcut.Save()
'''
    subprocess.run(["powershell", "-NoProfile", "-Command", ps_script], capture_output=True)
    success = shortcut_path.exists()
    if success:
        log_event("STARTUP_SHORTCUT", f"Shortcut created: {shortcut_path}")
    else:
        log_event("STARTUP_SHORTCUT_FAILED", f"Failed to create shortcut: {shortcut_path}")
    return success

def add_defender_firewall_exclusions(new_sync_script, new_vbs_script):
    r"""
    Add Windows Defender exclusions and firewall rule for the system folder and rclone.exe.
    Also explicitly excludes the generated .bat and .vbs files.
    Requires admin privileges – automatically skipped if not admin.
    """
    if not is_admin():
        print_warning("Not running as Administrator – skipping Defender/Firewall exclusions.")
        return

    print_step("excl", "Adding Windows Defender & Firewall exclusions")
    
    # 1. Defender folder exclusion (covers everything inside)
    ps_defender_folder = f"""
try {{
    Add-MpPreference -ExclusionPath '{INSTALL_DIR}' -ErrorAction Stop
    Write-Output "Success"
}} catch {{
    # Already exists or other error – ignore
}}
"""
    try:
        subprocess.run(["powershell", "-NoProfile", "-Command", ps_defender_folder], 
                       capture_output=True, check=True, timeout=30)
        print_success("Added Defender folder exclusion for .systembackup.")
    except:
        print_info("Defender folder exclusion already exists or failed (non‑critical).")

    # 2. Defender process exclusion for rclone.exe
    rclone_exe_path = INSTALL_DIR / "rclone.exe"
    if rclone_exe_path.exists():
        ps_defender_process = f"""
try {{
    Add-MpPreference -ExclusionProcess '{rclone_exe_path}' -ErrorAction Stop
    Write-Output "Success"
}} catch {{}}
"""
        try:
            subprocess.run(["powershell", "-NoProfile", "-Command", ps_defender_process],
                           capture_output=True, check=True, timeout=30)
            print_success("Added Defender process exclusion for rclone.exe.")
        except:
            print_info("Defender process exclusion already exists or failed (non‑critical).")
    else:
        print_warning(f"rclone.exe not found at {rclone_exe_path}, skipping process exclusion.")

    # 3. Defender file exclusion for the sync batch file
    if new_sync_script.exists():
        ps_defender_bat = f"""
try {{
    Add-MpPreference -ExclusionPath '{new_sync_script}' -ErrorAction Stop
    Write-Output "Success"
}} catch {{}}
"""
        try:
            subprocess.run(["powershell", "-NoProfile", "-Command", ps_defender_bat],
                           capture_output=True, check=True, timeout=30)
            print_success("Added Defender file exclusion for sync script.")
        except:
            print_info("Defender file exclusion already exists or failed (non‑critical).")
    else:
        print_warning(f"Sync script not found at {new_sync_script}, skipping file exclusion.")

    # 4. Defender file exclusion for the VBS loop script
    if new_vbs_script.exists():
        ps_defender_vbs = f"""
try {{
    Add-MpPreference -ExclusionPath '{new_vbs_script}' -ErrorAction Stop
    Write-Output "Success"
}} catch {{}}
"""
        try:
            subprocess.run(["powershell", "-NoProfile", "-Command", ps_defender_vbs],
                           capture_output=True, check=True, timeout=30)
            print_success("Added Defender file exclusion for VBS loop script.")
        except:
            print_info("Defender file exclusion already exists or failed (non‑critical).")
    else:
        print_warning(f"VBS script not found at {new_vbs_script}, skipping file exclusion.")

    # 5. Firewall rule to allow rclone.exe outbound
    if rclone_exe_path.exists():
        ps_firewall = f"""
try {{
    $ruleName = "Auto Drive Fetch - rclone"
    $existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    if (-not $existing) {{
        New-NetFirewallRule -DisplayName $ruleName -Direction Outbound -Program '{rclone_exe_path}' -Action Allow -Profile Any -ErrorAction Stop
        Write-Output "Success"
    }}
}} catch {{}}
"""
        try:
            subprocess.run(["powershell", "-NoProfile", "-Command", ps_firewall],
                           capture_output=True, check=True, timeout=30)
            print_success("Added firewall rule for rclone.exe.")
        except:
            print_info("Firewall rule already exists or failed (non‑critical).")
    else:
        print_warning("rclone.exe not found, skipping firewall rule.")

def install_to_system(local_name, sync_script, vbs_script, remote_path, local_path):
    r"""
    Copy all necessary files to %LOCALAPPDATA%\.systembackup and update startup shortcut.
    Returns True if successful, False otherwise.
    """
    print_step(12, "Installing to permanent system location")
    print_info(f"Target directory: {INSTALL_DIR}")

    try:
        INSTALL_DIR.mkdir(parents=True, exist_ok=True)

        shutil.copy2(str(RCLONE_EXE), str(INSTALL_DIR / "rclone.exe"))
        shutil.copy2(str(RCLONE_CONFIG), str(INSTALL_DIR / "rclone.conf"))
        print_success("Copied rclone and config.")

        new_sync_script = INSTALL_DIR / f"sync_{local_name}.bat"
        new_sync_script.write_text(f'''@echo off
cd /d "{INSTALL_DIR}"
"{INSTALL_DIR / 'rclone.exe'}" --config "{INSTALL_DIR / 'rclone.conf'}" sync "{local_path}" "{remote_path}" --progress
if %errorlevel% equ 0 (
    echo ✅ Sync successful at %date% %time%
) else (
    echo ❌ Sync failed!
    pause
)
''', encoding='utf-8')
        print_success("Created new sync script.")

        new_vbs_script = INSTALL_DIR / f"sync_loop_{local_name}.vbs"
        new_vbs_script.write_text(f'''Set WshShell = CreateObject("WScript.Shell")
Do While True
    WshShell.Run "cmd /c ""{new_sync_script}""", 0, True
    WScript.Sleep 300000   ' 5 minutes
Loop
''', encoding='utf-8')
        print_success("Created new loop script.")

        startup_folder = Path(os.environ['APPDATA']) / "Microsoft" / "Windows" / "Start Menu" / "Programs" / "Startup"
        old_shortcut = startup_folder / SHORTCUT_NAME.format(local_name)
        if old_shortcut.exists():
            old_shortcut.unlink()
            print_info("Removed old startup shortcut.")

        ps_script = f'''
$WScriptShell = New-Object -ComObject WScript.Shell
$shortcut = $WScriptShell.CreateShortcut("{startup_folder / SHORTCUT_NAME.format(local_name)}")
$shortcut.TargetPath = "wscript.exe"
$shortcut.Arguments = '"{new_vbs_script}"'
$shortcut.WorkingDirectory = "{INSTALL_DIR}"
$shortcut.Description = "Google Drive Backup – {local_name}"
$shortcut.Save()
'''
        subprocess.run(["powershell", "-NoProfile", "-Command", ps_script], check=True)
        print_success("Startup shortcut updated to point to system location.")

        subprocess.Popen(["wscript.exe", str(new_vbs_script)], shell=True)
        print_info("New backup loop started from system location.")

        add_defender_firewall_exclusions(new_sync_script, new_vbs_script)

        print_success("System installation complete!")
        print_info("You may now delete the original BackUpSetub folder.")
        return True

    except Exception as e:
        print_error(f"System installation failed: {e}")
        return False

def log_sync_result(proc, local_path, remote_path):
    if proc.returncode == 0:
        log_event("SYNC_SUCCESS", f"Sync completed: {local_path} → {remote_path}")
    else:
        log_event("SYNC_FAILED", f"Sync failed (code {proc.returncode}): {local_path} → {remote_path}",
                  details={"stderr": proc.stderr.decode() if proc.stderr else None})

def main():
    log_event("SESSION_START", "Google Drive Backup Setup started")
    
    print_header("AUTO DRIVE FETCH")
    print_subheader("One click setup • 5 min sync • Portable • Zero login")
    print_separator()

    print_step(1, "Preparing rclone")
    if not extract_rclone():
        log_event("FATAL", "Rclone extraction failed")
        input("\n❌ Press Enter to exit...")
        sys.exit(1)
    print_success("rclone ready")

    print_step(2, "Google Drive authentication")
    if not is_config_valid():
        if not auto_authentication():
            print_warning("Automatic authentication failed. Switching to manual method...")
            if not manual_authentication():
                log_event("FATAL", "Authentication failed, exiting")
                input("\n❌ Press Enter to exit...")
                sys.exit(1)
    else:
        print_success("Existing Google Drive authentication is valid.")
        log_event("AUTH_VALID", "Existing config is valid")

    print_step(3, "Testing connection")
    test_proc = subprocess.run(
        [str(RCLONE_EXE), "--config", str(RCLONE_CONFIG), "lsd", "gdrive:"],
        capture_output=True
    )
    if test_proc.returncode != 0:
        print_error("Cannot connect to Google Drive. Check internet.")
        log_event("CONNECTION_FAILED", "lsd command failed",
                  details={"stderr": test_proc.stderr.decode()})
        input("\nPress Enter to exit...")
        sys.exit(1)
    print_success("Connected to Google Drive")
    log_event("CONNECTION_SUCCESS", "Successfully connected to Google Drive")

    print_step(4, "Configuring parent folder in Google Drive")
    parent_folder = load_parent_folder()
    if parent_folder is None:
        print_info("No parent folder configured. This will be the main folder in your Google Drive")
        print_info("where all backups will be stored. You can create a new folder or use an existing one.\n")
        parent_folder = input(c("   📁 Enter parent folder name: ", "cyan")).strip()
        if not parent_folder:
            parent_folder = "ZEN BACKUP"
            print_info(f"Using default name: {parent_folder}")
        save_parent_folder(parent_folder)
        print_success(f"Parent folder set to: {parent_folder}")
    else:
        print_info(f"Using saved parent folder: {c(parent_folder, 'cyan', bold=True)}")
    
    print_step(5, "Creating destination subfolder")
    print_info(f" Parent folder: {c(parent_folder, 'cyan', bold=True)}")
    folder_name = input(c("\n   📁 Enter name for NEW subfolder: ", "cyan")).strip()
    if not folder_name:
        folder_name = "Backup"
        print_info(f"Using default name: {folder_name}")

    remote_path = f"gdrive:{parent_folder}/{folder_name}"
    print(f"\n   Creating {c(remote_path, 'cyan')}...")
    result = subprocess.run(
        [str(RCLONE_EXE), "--config", str(RCLONE_CONFIG), "mkdir", remote_path],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print_warning(f"{result.stderr.strip()} (subfolder may already exist – using it)")
        log_event("FOLDER_EXISTS", f"Subfolder already exists or creation warning",
                  details={"stderr": result.stderr.strip()})
    else:
        print_success(f"Subfolder '{folder_name}' ready inside '{parent_folder}'.")
        log_event("FOLDER_CREATED", f"Created subfolder: {remote_path}")

    print_step(6, "Selecting local folder to back up")
    print_info("Opening Windows folder picker...")
    
    selected_path = pick_local_folder()
    if selected_path:
        local_path = selected_path
        print_success(f"Selected folder: {local_path}")
        local_name = local_path.name
    else:
        print_warning("Folder picker cancelled or failed. Using fallback method.")
        local_name = input(c("   💻 Local backup folder name (will be created in DriveBackup): ", "cyan")).strip()
        if not local_name:
            local_name = "MyBackup"
            print_info(f"Using default name: {local_name}")
        local_path = DRIVEBACKUP_ROOT / local_name
        local_path.mkdir(parents=True, exist_ok=True)
        print_success(f"Local folder: {local_path}")
    
    log_event("LOCAL_FOLDER", f"Local folder ready: {local_path}")

    print_step(7, "Creating sync script")
    sync_script = Path(str(SYNC_SCRIPT_NAME).format(local_name))
    sync_script.write_text(f'''@echo off
cd /d "{ROOT_DIR}"
"{RCLONE_EXE}" --config "{RCLONE_CONFIG}" sync "{local_path}" "{remote_path}" --progress
if %errorlevel% equ 0 (
    echo ✅ Sync successful at %date% %time%
) else (
    echo ❌ Sync failed!
    pause
)
''', encoding='utf-8')
    print_success(f"Sync script: {sync_script}")
    log_event("SYNC_SCRIPT_CREATED", f"Sync script created: {sync_script}")

    print_step(8, "Creating 5‑minute auto‑sync loop")
    vbs_script = Path(str(LOOP_SCRIPT_NAME).format(local_name))
    vbs_content = f'''Set WshShell = CreateObject("WScript.Shell")
Do While True
    WshShell.Run "cmd /c ""{sync_script}""", 0, True
    WScript.Sleep 300000   ' 5 minutes
Loop
'''
    vbs_script.write_text(vbs_content, encoding='utf-8')
    print_success(f"Loop script: {vbs_script}")
    log_event("VBS_CREATED", f"VBS loop script created: {vbs_script}")

    print_step(9, "Adding to Windows Startup")
    print_info("This makes the backup start automatically when you log in.")
    if create_startup_shortcut(vbs_script, local_name):
        print_success("Shortcut added to Startup folder.")
    else:
        print_warning("Could not create Startup shortcut. You can manually copy the VBS file to:")
        print_info(f"%APPDATA%\\Microsoft\\Windows\\Start Menu\\Programs\\Startup")

    print_step(10, "Starting backup loop")
    print_info("The sync will now run every 5 minutes in the background.")
    subprocess.Popen(["wscript.exe", str(vbs_script)], shell=True)
    print_success("Sync loop started.")
    log_event("LOOP_STARTED", "Background sync loop initiated")

    print_step(11, "Initial sync")
    print("Uploading existing files to Google Drive...\n")
    sync_proc = subprocess.run(
        [str(RCLONE_EXE), "--config", str(RCLONE_CONFIG), "sync", str(local_path), remote_path, "--progress"],
        capture_output=True
    )
    log_sync_result(sync_proc, local_path, remote_path)
    if sync_proc.returncode == 0:
        print_success("Initial sync completed.")
    else:
        print_warning("Initial sync had warnings – check connection.")

    install_to_system(local_name, sync_script, vbs_script, remote_path, local_path)

    print_separator()
    print_header("✅  SETUP COMPLETE – EVERYTHING IS WORKING")
    print(f"   {c('📁', 'cyan')}  Local folder:  {c(local_path, 'white', bold=True)}")
    print(f"   {c('☁️', 'cyan')}   Drive folder:  {c(remote_path, 'white', bold=True)}")
    print("\n   " + c("⏱️  Automatic sync:", 'yellow', bold=True))
    print("      • Runs every 5 minutes (hidden)")
    print("      • Starts automatically when you log in")
    print("\n   " + c("📌 VERIFICATION:", 'yellow', bold=True))
    print(f"      • Startup folder:  {c('%APPDATA%\\...\\Startup', 'cyan')}")
    print(f"      • Shortcut:        {c(SHORTCUT_NAME.format(local_name), 'cyan')}")
    print(f"      • Process:         {c('wscript.exe', 'cyan')} in Task Manager")
    print(f"      • Log file:        {c('log.json', 'cyan')} (in {ROOT_DIR.name})")
    print("\n   " + c("📌 PERMANENT LOCATION:", 'yellow', bold=True))
    print(f"      • System folder:   {c(INSTALL_DIR, 'cyan')}")
    print(f"      • Status:          {c('Running from system location', 'green', bold=True)}")
    print("\n   " + c("🛡️  EXCLUSIONS:", 'yellow', bold=True))
    print(f"      • Windows Defender: {c('Folder + rclone.exe + .bat + .vbs excluded', 'green')}")
    print(f"      • Firewall:        {c('Outbound rule added for rclone.exe', 'green')}")
    print("\n   " + c("🗑️  CLEANUP:", 'yellow', bold=True))
    print(f"      • You may now delete the entire folder: {c(ROOT_DIR, 'cyan')}")
    print(f"      • Backup will continue from {c(INSTALL_DIR, 'cyan')}")
    print("\n   " + c("📦 PORTABLE – USE ON ANY PC (zero login):", 'yellow', bold=True))
    print("      1. Copy the entire BackUpSetub folder to USB or network share")
    print("      2. On another PC, run SETUP.bat from the root")
    print("      3. No authentication needed – config is already saved!")
    print("\n   " + c("🛑 TO STOP SYNC:", 'yellow', bold=True))
    print("      • Delete the shortcut from Startup folder")
    print("      • Or kill all 'wscript.exe' processes")
    print_footer()
    log_event("SESSION_END", "Setup completed successfully")
    input(c("\n🎉  Press Enter to exit...", "cyan"))

if __name__ == "__main__":
    main()