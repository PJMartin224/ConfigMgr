<#
.SYNOPSIS
	IT Maintenance notice for task sequence maintenance deployments
	
.DESCRIPTION
	The script updates the background, legal notice and legal caption for IT maintenance work. 
	Run the script in a TS before the first restart. When the machine reboots the specified
	maintenance background and logon messages are displayed. The existing messages and background 
	details	are captured into text backup files. 

	Post driver installation, run the script again, it will automatically read in the backup 
	files and revert settings.

.EXAMPLE
	.\Invoke-ITMaintenanceMessage -MaintenanceMessage $True

.NOTES
    FileName:    Invoke-ITMaintenanceMessage.ps1
    Author:      Maurice Daly
    Contact:     @MoDaly_IT
    Created:     2017-10-19
	Updated:     2017-10-22
  
    Version history:
    1.0.0 - (2017-10-13) Script created
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
	[parameter(Mandatory = $true, HelpMessage = "Turn on or off the maintenance message")]
	[ValidateNotNullOrEmpty()]
	[Boolean]$MaintenanceMessage
)

# Set Maintenance Values - Required for maintenance notice and wallpaper
$MaintenanceNotice = "Your machine will reboot shortly and be ready for use. DO NOT log in to the machine at this point."
$MaintenanceCaption = "IT MAINTENANCE IN PROCESS - DO NOT LOG ON"
$MaintenanceBackground = "C:\Windows\System32\oobe\info\backgrounds\maintenanceBackground.jpg"

# Define Variables
$LegalRegNoticePath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$PersonalizationRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"
$CurrentLegalNotice = (Get-Item -Path $LegalRegNoticePath | Get-ItemProperty).LegalNoticeText
$CurrentLegalCaption = (Get-Item -Path $LegalRegNoticePath | Get-ItemProperty).LegalNoticeCaption
$CurrentLockScreenImage = (Get-Item -Path $PersonalizationRegPath| Get-ItemProperty).LockScreenImage
$LegalCaptionBackupFile = "LegalCaptionBackup.txt"
$LegalNoticeBackupFile = "LegalNoticeBackup.txt"
$LockScreenBackupFile = "LockScreenBackup.txt"

function Get-ScriptDirectory {
	[OutputType([string])]
	param ()
	if ($null -ne $hostinvocation) {
		Split-Path $hostinvocation.MyCommand.path
	}
	else {
		Split-Path $script:MyInvocation.MyCommand.Path
	}
}

function Update-RegistryValue {
	param (
		[parameter(Mandatory = $false, HelpMessage = "The registy key to work with")]
		[ValidateNotNullOrEmpty()]
		[string]
		$RegistryKey,
		[parameter(Mandatory = $false, HelpMessage = "The registry item to restore")]
		[ValidateNotNullOrEmpty()]
		[string]
		$RegistryItem,
		[parameter(Mandatory = $false, HelpMessage = "The registry item to restore")]
		[ValidateNotNullOrEmpty()]
		[string]
		$RegistryValue,
		[parameter(Mandatory = $true, HelpMessage = "The backup file to use")]
		[ValidateNotNullOrEmpty()]
		[string]
		$BackupFile,
		[parameter(Mandatory = $true, HelpMessage = "The job type, backup or restore")]
		[ValidateNotNullOrEmpty()]
		[ValidateSet("Backup", "Restore")]
		[string]
		$Action
	)
	
	if ($Action -eq "Backup") {
		$RegistryValue | Out-File -Encoding ASCII -FilePath $BackupFile -Force
	}
	elseif ($Action -eq "Restore") {
		if ((Test-Path -Path $BackupFile) -eq $true) {
			$Notice = [string]::join([environment]::newline, (get-content -path $BackupFile))
			Set-ItemProperty -Path $RegistryKey -Name $RegistryItem -Value $Notice
		}
		else {
			Set-ItemProperty -Path $RegistryKey -Name $RegistryItem -Value $null
		}
	}
}

function Enable-Maintenance {
	
	# Back legal caption, legal notce and lock screen values 
	Update-RegistryValue -RegistryValue $CurrentLegalCaption -BackupFile (Join-Path -Path $(Get-ScriptDirectory) -ChildPath $LegalCaptionBackupFile) -Action Backup
	Update-RegistryValue -RegistryValue $CurrentLegalNotice -BackupFile (Join-Path -Path $(Get-ScriptDirectory) -ChildPath $LegalNoticeBackupFile) -Action Backup
	Update-RegistryValue -RegistryValue $CurrentLockScreenImage -BackupFile (Join-Path -Path $(Get-ScriptDirectory) -ChildPath $LockScreenBackupFile) -Action Backup
	
	# Set legal notice to warn user of driver update process
	Set-ItemProperty -Path $LegalRegNoticePath -Name LegalNoticeCaption -Value $MaintenanceCaption
	Set-ItemProperty -Path $LegalRegNoticePath -Name LegalNoticeText -Value $MaintenanceNotice
	
	# Enable lock screen changing
	if ((Get-ItemProperty -Path $PersonalizationRegPath).NoChangingLockScreen -eq $true) {
		Set-ItemProperty -Path $PersonalizationRegPath -Name "NoChangingLockScreen" -Value $false
	}
	Set-ItemProperty -Path $PersonalizationRegPath -Name "LockScreenImage" -Value $MaintenanceBackground
	sleep -Seconds 10
}

if ($MaintenanceMessage -eq $true) {
	Enable-Maintenance
}

if ($MaintenanceMessage -eq $false){
	try {
		# Revert previous legal caption, legal notce and lock screen values
		Update-RegistryValue -RegistryKey $LegalRegNoticePath -RegistryItem LegalNoticeCaption -BackupFile (Join-Path -Path $(Get-ScriptDirectory) -ChildPath $LegalCaptionBackupFile) -Action Restore
		Update-RegistryValue -RegistryKey $LegalRegNoticePath -RegistryItem LegalNoticeText -BackupFile (Join-Path -Path $(Get-ScriptDirectory) -ChildPath $LegalNoticeBackupFile) -Action Restore
		Update-RegistryValue -RegistryKey $PersonalizationRegPath -RegistryItem LockScreenImage -BackupFile (Join-Path -Path $(Get-ScriptDirectory) -ChildPath $LockScreenBackupFile) -Action Restore
	}
	catch [System.Exception] {
		Write-Warning "$($_.Exception.Message)"
	}
}
