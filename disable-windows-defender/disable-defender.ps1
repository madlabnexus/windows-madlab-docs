# ============================================================================
# PERMANENTLY DISABLE WINDOWS DEFENDER
# Run as Administrator in PowerShell
# IMPORTANT: Disable Tamper Protection manually BEFORE running this script
# Settings > Privacy & Security > Windows Security > Virus & Threat Protection
# > Manage Settings > Turn off Tamper Protection
# ============================================================================

#Requires -RunAsAdministrator

Write-Host "=============================================" -ForegroundColor Yellow
Write-Host " PERMANENTLY DISABLE WINDOWS DEFENDER" -ForegroundColor Yellow
Write-Host "=============================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "PREREQUISITE: Tamper Protection must be OFF" -ForegroundColor Red
Write-Host "Go to: Settings > Privacy & Security > Windows Security" -ForegroundColor Red
Write-Host "  > Virus & Threat Protection > Manage Settings" -ForegroundColor Red
Write-Host "  > Turn off Tamper Protection" -ForegroundColor Red
Write-Host ""

$confirm = Read-Host "Is Tamper Protection OFF? (Y/N)"
if ($confirm -ne "Y" -and $confirm -ne "y") {
    Write-Host "Aborting. Please disable Tamper Protection first." -ForegroundColor Red
    exit
}

Write-Host ""
Write-Host "[1/8] Disabling real-time monitoring..." -ForegroundColor Cyan
Set-MpPreference -DisableRealtimeMonitoring $true
Start-Sleep -Seconds 3

Write-Host "[2/8] Setting Group Policy registry keys..." -ForegroundColor Cyan
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiSpyware" -Value 1 -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiVirus" -Value 1 -Type DWord

New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableRealtimeMonitoring" -Value 1 -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableBehaviorMonitoring" -Value 1 -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableOnAccessProtection" -Value 1 -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableScanOnRealtimeEnable" -Value 1 -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableIOAVProtection" -Value 1 -Type DWord
Start-Sleep -Seconds 2

Write-Host "[3/8] Disabling cloud reporting and sample submission..." -ForegroundColor Cyan
Set-MpPreference -MAPSReporting Disabled
Set-MpPreference -SubmitSamplesConsent NeverSend

New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" -Name "SpynetReporting" -Value 0 -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" -Name "SubmitSamplesConsent" -Value 2 -Type DWord

New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Reporting" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Reporting" -Name "DisableGenericRePorts" -Value 1 -Type DWord
Start-Sleep -Seconds 2

Write-Host "[4/8] Disabling Defender services..." -ForegroundColor Cyan
$services = @("WinDefend", "WdNisSvc", "WdNisDrv", "WdFilter", "WdBoot")
foreach ($svc in $services) {
    try {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$svc" -Name "Start" -Value 4 -Type DWord -ErrorAction Stop
        Write-Host "  Disabled: $svc" -ForegroundColor DarkGray
    } catch {
        Write-Host "  Skipped: $svc (access denied or not found)" -ForegroundColor DarkYellow
    }
}
Start-Sleep -Seconds 2

Write-Host "[5/8] Disabling SmartScreen..." -ForegroundColor Cyan
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableSmartScreen" -Value 0 -Type DWord
Start-Sleep -Seconds 1

Write-Host "[6/8] Disabling Security Center notifications..." -ForegroundColor Cyan
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" -Name "DisableNotifications" -Value 1 -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" -Name "DisableEnhancedNotifications" -Value 1 -Type DWord
Start-Sleep -Seconds 1

Write-Host "[7/8] Hiding Security Center systray icon..." -ForegroundColor Cyan
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Systray" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Systray" -Name "HideSystray" -Value 1 -Type DWord
Start-Sleep -Seconds 1

Write-Host "[8/8] Disabling scheduled tasks..." -ForegroundColor Cyan
$tasks = @(
    "Microsoft\Windows\Windows Defender\Windows Defender Cache Maintenance",
    "Microsoft\Windows\Windows Defender\Windows Defender Cleanup",
    "Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan",
    "Microsoft\Windows\Windows Defender\Windows Defender Verification"
)
foreach ($task in $tasks) {
    schtasks /Change /TN $task /Disable 2>$null | Out-Null
    $name = $task.Split('\')[-1]
    Write-Host "  Disabled: $name" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "=============================================" -ForegroundColor Green
Write-Host " ALL DONE - REBOOT TO APPLY" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""
Write-Host "After reboot, verify by checking Task Manager:" -ForegroundColor White
Write-Host "  MsMpEng.exe should NOT be running" -ForegroundColor White
Write-Host ""

$reboot = Read-Host "Reboot now? (Y/N)"
if ($reboot -eq "Y" -or $reboot -eq "y") {
    Write-Host "Rebooting in 5 seconds..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    Restart-Computer -Force
}
