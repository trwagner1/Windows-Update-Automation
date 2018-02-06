<#
.SYNOPSIS
  This script is used to fully automate the deployment of Windows updates for patching vmware templates/images 

.DESCRIPTION
  For full automation, taking advantage of Microsoft Windows Management Foundation 5.1.  Powershell 3.0 and above required.
  Installs most recent versions of package provider nuget, and module PSWindowsUpdate.

.PARAMETER <Parameter_Name>
  None

.INPUTS
  None

.OUTPUTS Log File
  The script log file stored in C:\Windows\Temp\<name>.log

.NOTES
  Version:			1.0
  Author:			Ted Wagner
  Creation Date:	02/06/2018 (initial draft)
  Purpose/Change:	Initial script development
  Important:		FIPS must be disabled
  Requirements:		PowerShell 3.0 and above, run as administrator
  
  PSWindowsUpdate Syntax Notes
  Get default windows update;  if using WSUS or SCCM, those sources are used by default, otherwise will be Microsoft Windows Update
  Get-WindowsUpdate -AcceptAll -AutoReboot -Confirm:$False
  
  Example forces the use of Microsoft Windows Update as a source
  Get-WindowsUpdate -MicrosoftUpdate
  
  Example below limits simultaneous updates to 30
  Get-WUInstall -MicrosoftUpdate -UpdateCount 30

.EXAMPLE
  .\Start-WindowsUpdateAutomation
#>

#Requires -RunAsAdministrator -Version 3.0

# Design Notes
# Step 1: Check FIPS
# Step 2: Invoke PSSession localhost and install and or update modules.
# Step 3: Invoke PSSession localhost and run windows updates, accept all, and restart
# Step 4: If FIPS was enabled, re-enable.

Function Check-FIPSValue {
	# FIPS check required at this time (February 2018) for proper install of nuget
	# Note FIPS must be disabled for this to work
	$Global:FIPSValue = (get-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\FipsAlgorithmPolicy" -name "Enabled").enabled
	Return $Global:FIPSValue
}

Function Enable-FIPSValue {
	set-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\FipsAlgorithmPolicy" -name "Enabled" -value "1"
}

Function Disable-FIPSValue {
	set-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\FipsAlgorithmPolicy" -name "Enabled" -value "0"
}

Function Install-PMandPSWindowsUpdate {
	# Create Session and install/update NuGet and PSWindowsUpdate
	$Session = New-PSSession -ComputerName "Localhost"
	Invoke-Command -Session $Session -ScriptBlock {
		Import-Module PackageManagement
		Install-PackageProvider -Name NuGet -Force -Confirm:$False | Out-Null
		Install-Module -Name PSWindowsUpdate -Force -Confirm:$False | Out-Null
	}
}

# Check for available updates, if available, then install.  Use Get-WindowsUpdate by itself to get a count.
Function Start-InstallAllUpdates {
	$Session = New-PSSession -ComputerName "Localhost"
	Invoke-Command -Session $Session -ScriptBlock {
		Import-Module PSWindowsUpdate
		$WUCount = Get-WindowsUpdate
		If ($WUCount -gt "0"){
			Get-WindowsUpdate -AcceptAll -AutoReboot -Confirm:$False
		}
		Else{
			Write-Host "No Windows Updates to Install"
			Break
		}
	}
}

# Global variable for FIPS setting
$Global:FIPSValue = Check-FIPSValue


<# Start #>
# Begin check of FIPS value.  If enabled, disable.
$Global:FIPSValue = Check-FIPSValue
If ($Global:FIPSValue -eq "1"){
	Disable-FIPSValue
}

<# Perform Windows Updates #>

<# Check FIPS #>
# If FIPS was enabled at script start, re-enable
If ($Global:FIPSValue -eq "1"){
	Enable-FIPSValue
}

<# End #>

