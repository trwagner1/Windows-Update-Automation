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
  Version:			1.1
  Author:			Ted Wagner
  Creation Date:	02/14/2018 (alpha framework)
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

Function Check-WMF{
    # If PS 3 or 4 prompt to install WMF 5.x
    If ($PSVersionTable.PSVersion.Major -lt "5" -and $PSVersionTable.PSVersion.Major -ge "3"){
        Clear-Host
        Write-Host "This script requires Windows Management Framework 5 or above." -ForegroundColor Yellow; Write-Host "Please install https://www.microsoft.com/en-us/download/details.aspx?id=54616";Write-Host ""
        $Global:Control = $false
    }
    Else{
        # Not needed with requires statement, insurance
        Write-Host "This script requires PowerShell 3.0 or above." -ForegroundColor Red;Write-Host ""
        $Global:Control = $false
    }
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
			Get-WUInstall -AcceptAll -AutoReboot -Confirm:$False
		}
		Else{
			Write-Host "No Windows Updates to Install"
			Break
		}
	}
}

# Global variable for run control.
$Global:Control = $true

# Global variable to save original FIPS setting
$Global:FIPSValue = Check-FIPSValue


<# Check PS Version for WMF version compatibility #>
Check-WMF

<# Check FIPS.  If enabled, disable. #>
If ($Global:Control){
    $Global:FIPSValue = Check-FIPSValue
    If ($Global:FIPSValue -eq "1"){
	    Disable-FIPSValue
    }
}

<# Install and update modules #>
If ($Global:Control){
    Install-PMandPSWindowsUpdate
}


<# Perform Windows Updates #>

<# Check FIPS #>
# If FIPS was enabled at script start, re-enable
If ($Global:FIPSValue -eq "1"){
	Enable-FIPSValue
}

<# End #>

