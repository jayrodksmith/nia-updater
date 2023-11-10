<#
Set-DriverUpdatesNvidia
    Used to install nvidia drivers
    ( Should be fairly robust)

Set-DriverUpdatesamd
    Used to install amd drivers
    ( Currently working , but needs more testing)

Set-DriverUpdatesIntel
    Used to install intel drivers
    ( Currently working for Intel Gen 11 +)

Set-GPUtoNinjaRMM 
    Used to log details to NinjaRMM
        All NinjaRMM custom fields below
            hardwarediscretegpu                 (text)
            hardwarediscretedriverinstalled     (text)
            hardwarediscretedriverlatest        (text)
            hardwarediscretedriveruptodate      (checkbox)
        
            hardwareintegratedgpu               (text)
            hardwareintegrateddriverinstalled   (text)
            hardwareintegrateddriverlatest      (text)
            hardwareintegrateddriveruptodate    (checkbox)

NinjaRMM requirements -----------------
            updateNvidiaDrivers                 (Script Variable Checkbox)
            updateamdDrivers                    (Script Variable Checkbox)
            updateintelDrivers                  (Script Variable Checkbox)
            restartAfterUpdating                (Script Variable Checkbox)(Default unticked)
#>
param (
        [string]$githubrepo = "jayrodksmith/nia-updater",
        [string]$update_nvidia = $env:updateNvidiaDrivers,
        [string]$update_amd = $env:updateamdDrivers,
        [string]$update_intel = $env:updateintelDrivers,
        [string]$restartAfterUpdating = $env:restartAfterUpdating,
        [ValidateSet('NinjaOne', 'Standalone')]
        [string]$RMMPlatform = "Standalone",
        # Currently not implemented
        [bool]$notifications = $true,
        [bool]$autoupdate = $true
        )
###############################################################################
# Pre Checks
###############################################################################
function Test-Administrator {  
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)  
}
if(Test-Administrator -eq $true){
    Write-Debug "Running As Admin"}
    else{
    Write-Warning "Not running as Admin, run this script elevated or as System Context"
    exit 0
}
# If ran outside of NinjaRMM automation, will set to check and print driver info by default.
# With no logging to ninja and no updating

if(!$update_nvidia){$update_nvidia = $false}
if(!$update_amd) {$update_amd = $false}
if(!$update_intel) {$update_intel = $false}
if(!$restartAfterUpdating) {$restartAfterUpdating = $false}

###############################################################################
# Global Variable Setting
###############################################################################

$Script:niaupdaterPath = (Join-Path -Path $ENV:ProgramData -ChildPath "niaupdater")
$Script:logfilelocation = "$niaupdaterPath\logs"
$Script:logfile = "$Script:logfilelocation\niaupdater.log"
$Script:logdescription = "niaupdater"


###############################################################################
# NIA Installer
###############################################################################
$niaupdaterRepo = "https://github.com/$githubrepo"
$releases = "https://api.github.com/repos/$githubrepo/releases"
$niaupdaterlatestversion = (Invoke-WebRequest $releases | ConvertFrom-Json)[0].tag_name
$niaupdaterinstalledversion = Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\Software\niaupdater' -erroraction silentlycontinue | Select-Object -ExpandProperty Version
$niaupdaterTempExtractionPath = (Join-Path -Path $ENV:Temp -ChildPath "niaupdater")
$uptodate = if($niaupdaterlatestversion -eq $niaupdaterinstalledversion){$true}else{$false}

# Check if installed
if (-not (Test-Path -Path ('{0}\Invoke-niaupdater.ps1' -f $niaupdaterPath))) {
    $niaupdaterinstalled = $false
    }else {
    $niaupdaterinstalled = $true
}

# Download and install if not exist
if(($niaupdaterinstalled -eq $false) -or ($uptodate -eq $false -and $autoupdate -eq $true)){
    $niaupdaterDownloadZip = ('{0}/archive/main.zip' -f $niaupdaterRepo)
    $niaupdaterDownloadFile = ('{0}\niaupdater.zip' -f $ENV:Temp)

    # Create the niaupdater folder if it doesn't exist 
    if (-not (Test-Path -Path $niaupdaterPath)) {
        $null = New-Item -Path $niaupdaterPath -ItemType Directory -Force
    } else {
        $null = Remove-Item -Recurse -Force -Path $niaupdaterPath
        $null = New-Item -Path $niaupdaterPath -ItemType Directory -Force
    }

    # Download the repository
    Invoke-WebRequest -Uri $niaupdaterDownloadZip -OutFile $niaupdaterDownloadFile

    # Extract the zip file to temp.
    Expand-Archive -Path $niaupdaterDownloadFile -DestinationPath $niaupdaterTempExtractionPath -Force

    # Copy the contents of the extracted folder to the niaupdater folder
    $null = Copy-Item -Path ('{0}\nia-updater-main\*' -f $niaupdaterTempExtractionPath) -Destination $niaupdaterPath -Force -Recurse
    if(-not(Test-Path 'Registry::HKEY_LOCAL_MACHINE\Software\niaupdater')){
    New-Item -Path 'Registry::HKEY_LOCAL_MACHINE\Software\' -Name NIAupdater
    }
    $updatedversion = Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\Software\NIAupdater' -Name 'Version' -Value $niaupdaterlatestversion -erroraction silentlycontinue

    # Remove the downloaded zip file
    Remove-Item -Path $niaupdaterDownloadFile -Force

    # Remove the extracted folder
    Remove-Item -Path $niaupdaterTempExtractionPath -Force -Recurse

    # Confirm that we have the `nia-updater.ps1` file
    if (-not (Test-Path -Path ('{0}\Invoke-niaupdater.ps1' -f $niaupdaterPath))) {
        throw 'Unable to find the Invoke-niaupdater.ps1 file. Please check the installation.'
    }
    Write-Output "niaupdater updated to version : $niaupdaterlatestversion"    
    }else{
    if($autoupdate -eq $true){Write-Output "niaupdater already latest version : $niaupdaterlatestversion"}else{
    Write-Output "niaupdater already installed" 
    }
}
###############################################################################
# Import Functions as required
###############################################################################

$Functions = Get-ChildItem -Path (Join-Path -Path $Script:niaupdaterPath -ChildPath 'functions') -Filter '*.ps1' -Exclude @() -Recurse
foreach ($Function in $Functions) {
    Write-Verbose ('Importing function file: {0}' -f $Function.FullName)
    . $Function.FullName
}
RMM-Initilize
###############################################################################
# Main Script Starts Here
###############################################################################
# Get GPU Info and print to screen
$gpuInfo = Get-GPUInfo
$Script:gpuInfo = $gpuInfo

# Send GPU Info to RMM
if($RMMPlatform -eq "NinjaOne"){
    Set-GPUtoNinjaRMM
}
# Cycle through updating drivers if required
if($update_amd -eq $true){ 
    Set-DriverUpdatesamd  
}
if($update_nvidia -eq $true){
    Set-DriverUpdatesNvidia
}
if($update_intel -eq $true){
    Set-DriverUpdatesintel 
}
$gpuInfo
# Restart machine if required
if($restartAfterUpdating -eq $true -and $Script:installstatus -eq "Updated"){
    shutdown /r /t 30 /c "In 30 seconds, the computer will be restarted to finish installing GPU Drivers"
}
RMM-Exit 0

###############################################################################
# Main Script Ends Here
###############################################################################

<## Example
$Toastenable = $true
Set-Toast -Toasttitle "Driver Update" -Toasttext "Finished installing nvidia drivers please reboot" -UniqueIdentifier "default" -Toastreboot -Toastenable $notifications
Set-Toast -Toasttitle "Driver Update" -Toasttext "Finished installing nvidia drivers please reboot" -UniqueIdentifier "default" -Toastenable $notifications
##>