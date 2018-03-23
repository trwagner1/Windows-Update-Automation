<#
.SYNOPSIS
  This script is used to fully automate the deployment of Windows updates for patching vmware templates/images 

.DESCRIPTION
  Microsoft Windows Management Framework 5.1 or above required.  https://www.microsoft.com/en-us/download/details.aspx?id=54616
  Powershell 3.0 and above required.
  Installs most recent versions of package provider nuget and module PSWindowsUpdate.
  
  This version of the script is the first stepping stone to fully automate the application of Windows Updates to Windows templates in a VMware virtual environment.
  Version 1.x is intended to be run on individual computers connected to the internet.

.PARAMETER <Parameter_Name>
  None

.INPUTS
  None

.OUTPUTS Log File
  None

.NOTES
  Version:			0.0.4
  Author:			Ted Wagner
  Creation Date:	02/16/2018 (alpha framework)
  Revision Date:	03/23/2018
  Purpose/Change:	Initial script development
  Important:		FIPS must be disabled
  Requirements:		PowerShell 3.0 and above, run as administrator
  
  PSWindowsUpdate Syntax Notes
  Get default windows update;  if using WSUS or SCCM, those sources are used by default, otherwise will be Microsoft Windows Update; and installs updates
  Get-WindowsUpdate -AcceptAll -Install -AutoReboot -Confirm:$False
  
  Example forces the use of Microsoft Windows Update as a source; list updates
  Get-WindowsUpdate -MicrosoftUpdate
  
  Example below limits simultaneous updates to 30; using alias to install updates
  Get-WUInstall -MicrosoftUpdate -UpdateCount 30

.EXAMPLE
  .\Start-WindowsUpdateAutomation.ps1
#>

#Requires -RunAsAdministrator
#Requires -Version 3.0

# Design Notes
# Step 1: Check FIPS
# Step 2: install and/or update modules.
# Step 3: run windows updates, accept important (ignore optional), and restart
# Step 4: Using workflows, invoke PSSession on localhost again and re-run windows updates.
# https://blogs.technet.microsoft.com/heyscriptingguy/2013/01/23/powershell-workflows-restarting-the-computer/
# Step 5: If FIPS was enabled, re-enable.

Function Test-InternetConnection {
	# Check internet connection
	$PingResult = Test-Connection -Count 2 -ErrorAction SilentlyContinue -Quiet download.microsoft.com
	If (!($PingResult)){
		Write-Host "This script requires an internet connection."
		# Exit in function, end terminate script but not close console.
		Exit
	}
}

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

Function Check-WMF{
 # If PS version 3 or 4, prompt to install WMF 5.x
If ($PSVersionTable.PSVersion.Major -lt "5"){
	Clear-Host
	Write-Host "This script requires Windows Management Framework 5 or above." -ForegroundColor Yellow; Write-Host "Please install https://www.microsoft.com/en-us/download/details.aspx?id=54616";Write-Host ""
	$Global:Control = $false
	# Exit in function, end terminate script but not close console.
	Exit
}
}

Function Install-PMandPSWindowsUpdate {
	# Install/update NuGet and PSWindowsUpdate
	Try{
		Import-Module PackageManagement
		Install-PackageProvider -Name NuGet -Force -Confirm:$False | Out-Null
		Install-Module -Name PSWindowsUpdate -Force -Confirm:$False | Out-Null
	}
	Catch{
		Remove-Module -Name PSWindowsUpdate
		return $_
	}
}


# Check for available updates, if available, then install.  Install only autoselected updates (omit optional updates).
# Use verbose switch for testing
# If local WSUS or SCCM, default source is "Windows Update" and that should be reflected in verbose output.
Function Start-InstallAllUpdates {
	Import-Module PSWindowsUpdate
	$WUCount = (Get-WindowsUpdate).count
	If ($WUCount -gt "0"){
		Get-WUInstall -Install -AutoSelectOnly -AutoReboot -Confirm:$False -Verbose
	}
	Else{
		# Exit in function, end terminate script but not close console.
		Write-Host "No updates to install.  Nothing to do"
        Remove-Module PSWindowsUpdate
		Exit
	}
}

# Remove & cleanup PowerShell sessions
Function Close-AllSessions {
	Get-PsSession |?{$s.State.value__ -ne 2 -or $_.Availability -ne 1}|Remove-PSSession
}

# Global variable for run control.
$Global:Control = $true

# Global variable to save original FIPS setting
$Global:FIPSValue = Check-FIPSValue

<# Make sure a connection to the internet exists #>
Test-InternetConnection

<# Check PS Version for WMF version compatibility #>
Check-WMF

<# Check FIPS.  If enabled, disable. #>
If ($Global:Control){
	$Global:FIPSValue = Check-FIPSValue
	If ($Global:FIPSValue -eq "1"){
		Write-host "Unable to proceed.  The PSWindowsUpdate module will not work with FIPS enabled" -ForegroundColor "Yellow" -BackgroundColor "Black"
		#Disable-FIPSValue
	}
}

<# Install and update modules #>
If ($Global:Control){
	Install-PMandPSWindowsUpdate
}

<# Perform Windows Updates #>
Start-InstallAllUpdates

<# Need new function to pick up and check again after a restart #>

<# Finished with Windows Updates, start cleanup phase #>

<# Check FIPS #>
# If FIPS was enabled at script start, re-enable
<#
If ($Global:FIPSValue -eq "1"){
	Enable-FIPSValue
}
#>

Close-AllSessions
<# End #>



