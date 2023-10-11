###############################################################################
# Function - Nvidia Driver Installer
###############################################################################
function Set-DriverUpdatesNvidia {
    param (
    [switch]$clean = $false, # Will delete old drivers and install the new ones
    [string]$folder = "C:\Temp"   # Downloads and extracts the driver here
)
RMM-Msg "Script Mode: `tUpdating NVIDIA drivers" -messagetype Verbose
$gpuInfoNvidia = $gpuInfo | Where-Object { $_.Name -match "nvidia" }
$extractinfo = Get-extract
if ($gpuInfoNvidia.DriverUptoDate -eq $True){
    RMM-Msg "Nvidia Drivers already upto date" -messagetype Verbose
    $Script:installstatus = "uptodate"
    return
}

# Temp folder
New-Item -Path $folder -ItemType Directory 2>&1 | Out-Null
$nvidiaTempFolder = "$folder\NVIDIA"
New-Item -Path $nvidiaTempFolder -ItemType Directory 2>&1 | Out-Null

# Variable Set
$extractFolder = "$nvidiaTempFolder\$($gpuInfoNvidia.DriverLatest.Trim())"
$filesToExtract = "Display.Driver HDAudio NVI2 PhysX EULA.txt ListDevices.txt setup.cfg setup.exe"

# Downloading the installer
$dlFile = "$nvidiaTempFolder\$($gpuInfoNvidia.DriverLatest.Trim()).exe"
Get-DownloadUrls -urllist $gpuInfoNvidia.DriverLink -downloadLocation $dlFile

# Extract the installer
if ($extractinfo.'7zipinstalled') {
    Start-Process -FilePath $extractinfo.archiverProgram -NoNewWindow -ArgumentList "x -bso0 -bsp1 -bse1 -aoa $dlFile $filesToExtract -o""$extractFolder""" -wait
}else {
    RMM-Error "Something went wrong. No archive program detected. This should not happen." -messagetype Verbose
    RMM-Exit 1
}

# Remove unneeded dependencies from setup.cfg
(Get-Content "$extractFolder\setup.cfg") | Where-Object { $_ -notmatch 'name="\${{(EulaHtmlFile|FunctionalConsentFile|PrivacyPolicyFile)}}' } | Set-Content "$extractFolder\setup.cfg" -Encoding UTF8 -Force

# Installing drivers
RMM-Msg "Installing Nvidia drivers now..." -messagetype Verbose
$install_args = "-passive -noreboot -noeula -nofinish -s"
if ($clean) {
    $install_args = $install_args + " -clean"
}
Start-Process -FilePath "$extractFolder\setup.exe" -ArgumentList $install_args -wait

# Cleaning up downloaded files
RMM-Msg "Deleting downloaded files" -messagetype Verbose
Remove-Item $nvidiaTempFolder -Recurse -Force

# Driver installed, requesting a reboot
RMM-Msg "Driver installed. You may need to reboot to finish installation." -messagetype Verbose
RMM-Msg "Driver installed. $($gpuInfoNvidia.DriverLatest)" -messagetype Verbose
$Script:installstatus = "Updated"
return
}

###############################################################################
# Function - Nvidia Driver Installer End
###############################################################################