# Disabling Windows Defender Permanently in Windows 11 VM

🇧🇷 [Versão em Português](README.pt-br.md)

## Why

Windows Defender consumes significant CPU and RAM in a VM. Since this is a virtualized Office workstation running behind the host's network security, Defender is unnecessary overhead.

## Prerequisites

- Windows 11 VM running
- Admin account access

---

## Step 1: Disable Tamper Protection (Manual - GUI Only)

Tamper Protection prevents scripts from modifying Defender settings. It **cannot** be disabled via script — Microsoft requires manual GUI interaction.

1. Open **Settings**
2. Go to **Privacy & Security** → **Windows Security**
3. Click **Virus & threat protection**
4. Scroll down to **Virus & threat protection settings** → click **Manage settings**
5. Scroll to **Tamper Protection** → toggle it **Off**
6. Confirm the UAC prompt

> **Important:** Do NOT skip this step. The scripts below will fail silently or with errors if Tamper Protection is still on.

---

## Step 2: Run the Main Disable Script (Normal Mode)

This script disables Defender policies, SmartScreen, notifications, scheduled tasks, and other unnecessary VM services.

1. Open **Start Menu**
2. Type `PowerShell`
3. Right-click **Windows PowerShell** → **Run as administrator**
4. Run:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
cd ~\Downloads
.\disable-defender.ps1
```

### What this script does:

| Action | Purpose |
|--------|---------|
| Disables real-time monitoring | Stops active file scanning |
| Sets Group Policy registry keys | Prevents Defender from re-enabling itself |
| Disables SmartScreen | Stops app/download reputation checks |
| Hides Security Center notifications | No more taskbar alerts about protection |
| Hides systray icon | Removes shield icon from taskbar |
| Disables scheduled scan tasks | No background scans |
| Disables SysMain (Superfetch) | Frees RAM (unnecessary in VM) |
| Disables DiagTrack (Telemetry) | Stops usage data collection to Microsoft |
| Disables GameBar/GameDVR | Not needed in Office VM |
| Disables NVIDIA Display Service | No GPU in VM, service wastes resources |

---

## Step 3: Disable ALL Defender Services via Safe Mode

The Defender service registry keys are owned by **TrustedInstaller**, a special Windows account with higher privileges than Administrator or even SYSTEM. The only reliable way to modify these keys is in **Safe Mode**, where Defender does not run and its self-protection is inactive.

### 3a: Enter Safe Mode

Open Admin PowerShell and run:

```powershell
bcdedit /set "{current}" safeboot minimal
Restart-Computer
```

Windows will reboot into Safe Mode (minimal desktop, no network, no Defender running).

### 3b: Disable ALL Services

Once in Safe Mode, open an Admin PowerShell:

1. Click **Start**
2. Type `PowerShell`
3. Right-click **Windows PowerShell** → **Run as administrator**
4. Paste and run this entire block:

```powershell
$services = @("WinDefend", "WdNisSvc", "WdNisDrv", "WdFilter", "WdBoot", "MDCoreSvc")
foreach ($svc in $services) {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$svc" -Name "Start" -Value 4 -Type DWord
    Write-Host "$svc disabled" -ForegroundColor Green
}
```

You should see:

```
WinDefend disabled
WdNisSvc disabled
WdNisDrv disabled
WdFilter disabled
WdBoot disabled
MDCoreSvc disabled
```

No errors = success.

### If PowerShell is not available in Safe Mode, use Command Prompt (Admin):

```cmd
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WinDefend" /v Start /t REG_DWORD /d 4 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WdNisSvc" /v Start /t REG_DWORD /d 4 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WdNisDrv" /v Start /t REG_DWORD /d 4 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WdFilter" /v Start /t REG_DWORD /d 4 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WdBoot" /v Start /t REG_DWORD /d 4 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\MDCoreSvc" /v Start /t REG_DWORD /d 4 /f
```

### What each service does:

| Service | Process | Purpose |
|---------|---------|---------|
| WinDefend | MsMpEng.exe | Main antimalware engine |
| WdNisSvc | NisSrv.exe | Network inspection service |
| WdNisDrv | WdNisDrv.sys | Network inspection kernel driver |
| WdFilter | WdFilter.sys | Real-time file system mini-filter |
| WdBoot | WdBoot.sys | Early boot antimalware driver |
| MDCoreSvc | mpdefendercoreservice.exe | Microsoft Defender Core Service (added in recent Windows updates) |

Setting `Start = 4` means **Disabled** — the service will never start.

### 3c: Exit Safe Mode and Reboot Normally

Still in the Admin PowerShell in Safe Mode:

```powershell
bcdedit /deletevalue "{current}" safeboot
Restart-Computer
```

Or in Command Prompt:

```cmd
bcdedit /deletevalue {current} safeboot
shutdown /r /t 0
```

---

## Step 4: Verify

After normal reboot:

1. Open **Task Manager** → **Details** tab
2. Search for `MsMpEng.exe` — should **NOT** be listed
3. Search for `NisSrv.exe` — should **NOT** be listed
4. Search for `mpdefendercoreservice.exe` — should **NOT** be listed
5. Check CPU usage — should be significantly lower
6. Check RAM — should have more free memory
7. No security shield icon in taskbar

---

## After Windows Update (Re-run Procedure)

Windows Update can reset Defender policies and re-enable services. If Defender comes back after an update, follow this sequence:

### 1. Disable Tamper Protection (GUI)

Settings → Privacy & Security → Windows Security → Virus & Threat Protection → Manage Settings → Tamper Protection → **Off**

### 2. Run the disable script (Admin PowerShell)

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
cd ~\Downloads
.\disable-defender.ps1
```

### 3. Enter Safe Mode

```powershell
bcdedit /set "{current}" safeboot minimal
Restart-Computer
```

### 4. Disable all services (Admin PowerShell in Safe Mode)

```powershell
$services = @("WinDefend", "WdNisSvc", "WdNisDrv", "WdFilter", "WdBoot", "MDCoreSvc")
foreach ($svc in $services) {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$svc" -Name "Start" -Value 4 -Type DWord
    Write-Host "$svc disabled" -ForegroundColor Green
}
```

### 5. Exit Safe Mode and reboot

```powershell
bcdedit /deletevalue "{current}" safeboot
Restart-Computer
```

### 6. Verify

Task Manager → Details → confirm `MsMpEng.exe` and `mpdefendercoreservice.exe` are gone.

---

## Troubleshooting

### Security Center still shows warnings

1. Right-click the shield icon in the taskbar → Remove icon
2. Or: **Settings** → **Personalization** → **Taskbar** → **Other system tray icons** → disable Security Center

### Safe Mode doesn't boot via bcdedit

1. Hold **Shift** while clicking **Restart** in Start menu
2. Navigate: **Troubleshoot** → **Advanced options** → **Startup Settings** → **Restart**
3. Press **4** for Safe Mode
4. Continue from Step 3b

### PowerShell bcdedit syntax — PowerShell vs CMD

PowerShell requires quotes around `{current}`:

```powershell
bcdedit /set "{current}" safeboot minimal
```

CMD does not:

```cmd
bcdedit /set {current} safeboot minimal
```

---

## Complete Services Summary

| Service/Feature | Action | Method | Impact |
|----------------|--------|--------|--------|
| Windows Defender | Disabled | Safe Mode | No antivirus scanning |
| Defender Core Service | Disabled | Safe Mode | No core defender process |
| Network Inspection | Disabled | Safe Mode | No network traffic scanning |
| Boot Driver | Disabled | Safe Mode | No boot-time scanning |
| File System Filter | Disabled | Safe Mode | No real-time file scanning |
| SmartScreen | Disabled | Script | No app reputation checks |
| Tamper Protection | Off | Manual GUI | Allows script changes |
| SysMain/Superfetch | Disabled | Script | Frees RAM |
| DiagTrack/Telemetry | Disabled | Script | No data sent to Microsoft |
| GameBar/GameDVR | Disabled | Script | No game overlay |
| NVIDIA Display | Disabled | Script | No GPU in VM |
| Windows Search | **KEPT** | — | Outlook search depends on it |
| Windows Update | **KEPT** | — | Manual for Office updates |
