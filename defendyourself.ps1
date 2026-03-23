# checks for admin if your reading this hi
$wid = [Security.Principal.WindowsIdentity]::GetCurrent()
$wpr = New-Object Security.Principal.WindowsPrincipal($wid)

if (-not $wpr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Requesting administrative privileges..."
    Start-Process powershell.exe "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}
# endregion

$global:logPath = "$env:ProgramData\DefenderProfile\run.log"
$global:backupPath = "$env:ProgramData\DefenderProfile\backup.json"

if (!(Test-Path "$env:ProgramData\DefenderProfile")) {
    New-Item -ItemType Directory -Path "$env:ProgramData\DefenderProfile" | Out-Null
}

function Write-Log {
    param([string]$msg)

    $line = "{0} | {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg
    Add-Content -Path $global:logPath -Value $line
}

function Save-CurrentDefenderState {
    try {
        Write-Log "Defender log"
        $prefs = Get-MpPreference
        $prefs | ConvertTo-Json -Depth 5 | Set-Content $global:backupPath
        Write-Log "Backup saved to $global:backupPath"
    }
    catch {
        Write-Log "Backup failed shucks: $($_.Exception.Message)"
    }
}

function Restore-PreviousState {
    if (!(Test-Path $global:backupPath)) {
        Write-Host "No backup available awh man."
        Write-Log "Restore attempted but no backup file found that sucks"
        return
    }

    try {
        $data = Get-Content $global:backupPath | ConvertFrom-Json

        Write-Host "Restoring the before defender..."
        Write-Log "Restoring Defender from backup"

        Set-MpPreference -DisableRealtimeMonitoring $data.DisableRealtimeMonitoring
        Set-MpPreference -DisableBehaviorMonitoring $data.DisableBehaviorMonitoring
        Set-MpPreference -PUAProtection $data.PUAProtection
        Set-MpPreference -EnableNetworkProtection $data.EnableNetworkProtection
        Set-MpPreference -EnableControlledFolderAccess $data.EnableControlledFolderAccess

        Write-Host "Restore complete."
        Write-Log "Restore completed successfully yay!"
    }
    catch {
        Write-Host "Restore failed. Check your log."
        Write-Log "Restore error: $($_.Exception.Message)"
    }
}

function Apply-DefenderHardenedProfile {
    Save-CurrentDefenderState

    Write-Host "Applying hardened Defender profile..."
    Write-Log "Applying hardened configuration"

    $asrList = @(
        "5beb7efe-fd9a-4556-801d-275e5ffc04cc",
        "be9ba2d9-53ea-4cdc-84e5-9b1eeee46550",
        "d4f940ab-401b-4efc-aadc-ad5f3c50688a"
    )

    try {
        Set-MpPreference -PUAProtection Enabled
        Set-MpPreference -EnableNetworkProtection Enabled
        Set-MpPreference -EnableControlledFolderAccess Enabled

        Set-MpPreference `
            -AttackSurfaceReductionRules_Ids $asrList `
            -AttackSurfaceReductionRules_Actions Enabled

        Write-Host "Defender hardened successfully."
        Write-Log "Hardened profile applied"
    }
    catch {
        Write-Host "Configuration failed. See log."
        Write-Log "Apply error: $($_.Exception.Message)"
    }
}

function Show-Menu {
    Clear-Host
    Write-Host "Windows Defender better version"
	Write-Host "Hopefully this helps yall i know its a small script!"
    Write-Host "--------------------------------"
    Write-Host "1) Apply profile"
    Write-Host "2) Restore previous configuration"
    Write-Host "3) View current ASR rules"
    Write-Host "4) Exit"
}

do {
    Show-Menu
    $selection = Read-Host "Select an option"

    switch ($selection) {
        "1" { Apply-DefenderHardenedProfile }
        "2" { Restore-PreviousState }
        "3" {
            Get-MpPreference |
            Select-Object AttackSurfaceReductionRules_Ids,
                          AttackSurfaceReductionRules_Actions |
            Format-List
        }
    }

    Write-Host ""
    Read-Host "Press Enter to continue"

} while ($selection -ne "4")
