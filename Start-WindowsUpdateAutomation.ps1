<#
.SYNOPSIS
  <Overview of script>

.DESCRIPTION
  <Brief description of script>

.PARAMETER <Parameter_Name>
  <Brief description of parameter input required. Repeat this attribute if required>

.INPUTS
  <Inputs if any, otherwise state None>

.OUTPUTS Log File
  The script log file stored in C:\Windows\Temp\<name>.log

.NOTES
  Version:        1.0
  Author:         <Name>
  Creation Date:  <Date>
  Purpose/Change: Initial script development

.EXAMPLE
  <Example explanation goes here>
  
  <Example goes here. Repeat this attribute for more than one example>
#>

<# PSWindowsUpdate Syntax Notes
Get default windows update, which should be SCCM for computers with SCCM agent installed, otherwise will be Microsoft Windows Update
Get-WindowsUpdate -AcceptAll -AutoReboot -Confirm:$False

Example below goes to Microsoft Windows Update
Get-WindowsUpdate -MicrosoftUpdate

Example below limits simultaneous updates to 30
Get-WUInstall -MicrosoftUpdate -UpdateCount 30
#>

#Requires -RunAsAdministrator

# Inspect modules, install if not available
If (Get-Module -ListAvailable -Name PSWindowsUpdate){
	Import-Module PSWindowsUpdate
}
Else{

}


# Make sure a restart is not required, if so, restart.
$RStatus = Get-WURebootStatus
If ($RStatus -NotLike "*not required*"){
	Restart-Computer
}




Function Check-FIPSValue {
	# Future implementation - automate installing the PSWindowsUpdate Module
	# Note FIPS must be disabled for this to work
	$FIPSValue = (get-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\FipsAlgorithmPolicy" -name "Enabled").enabled
	If ($FIPSValue -eq 1){
		set-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\FipsAlgorithmPolicy" -name "Enabled" -value "0"
	}
}


Function Install-PMandPSWindowsUpdate {
	Import-Module PackageManagement
	Install-PackageProvider -Name NuGet -Force -Confirm:$False | Out-Null
	Install-Module -Name PSWindowsUpdate -Force -Confirm:$False | Out-Null
}

# Check for available updates, if available, then install.  Use Get-WindowsUpdate by itself to get a count.

$WUCount = Get-WindowsUpdate
If ($WUCount -gt "0"){
	Get-WindowsUpdate -AcceptAll -AutoReboot -Confirm:$False
}


