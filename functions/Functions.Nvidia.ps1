###############################################################################
# Function - Nvidia Driver Installer
###############################################################################
function Set-DriverUpdatesNvidia {
    param (
    [switch]$clean = $false, # Will delete old drivers and install the new ones
    [string]$folder = "C:\Temp"   # Downloads and extracts the driver here
    )
    RMM-Msg "Script Mode: `tUpdating NVIDIA drivers" -messagetype Verbose
    Set-Toast -Toasttitle "Updating Drivers" -Toasttext "Updating Nvidia Drivers" -UniqueIdentifier "default" -Toastenable $notifications
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
    Set-Toast -Toasttitle "Updating Drivers" -Toasttext "$($gpuInfoNvidia.DriverLatest) Nvidia Drivers Installed" -UniqueIdentifier "default" -Toastenable $notifications
    $Script:installstatus = "Updated"
    return
}

###############################################################################
# Function - Nvidia Driver Installer End
###############################################################################

###############################################################################
# Function - Nvidia Driver Check Updates
###############################################################################
function Get-driverlatestversionnvidia {
    ## Check OS Level
    if ($cim_os -match "Windows 11"){$os = "135"}
    elseif ($cim_os-match "Windows 10"){$os = "57"}
    if ($exists_nvidia.name -match "Quadro|NVIDIA RTX|NVIDIA T600|NVIDIA T1000|NVIDIA T400") {
        $nsd = ""
        $windowsVersion = if (($cim_os -match "Windows 11")-or($cim_os -match "Windows 10")){"win10-win11"}elseif(($cim_os -match "Windows 7")-or($cim_os -match "Windows 8")){"win8-win7"}
        $windowsArchitecture = if ([Environment]::Is64BitOperatingSystem){"64bit"}else{"32bit"}
        $cardtype = "/Quadro_Certified/"
        $drivername1 = "quadro-rtx-desktop-notebook"
        $drivername2 = "dch"
        $psid = "122"
        $pfid = "967"
        $whql = "1"
        }elseif ($exists_nvidia.name -match "Geforce") {
        $nsd = "nsd-"
        $windowsVersion = if (($cim_os -match "Windows 11")-or($cim_os -match "Windows 10")){"win10-win11"}elseif(($cim_os -match "Windows 7")-or($cim_os -match "Windows 8")){"win8-win7"}
        $windowsArchitecture = if ([Environment]::Is64BitOperatingSystem){"64bit"}else{"32bit"}
        $cardtype = "/"
        $drivername1 = "desktop"
        $drivername2 = "nsd-dch"
        $psid = "101"
        $pfid = "816"
        $whql = "4"
    }   
    # Checking latest driver version from Nvidia website
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    $linkcreate = 'https://www.nvidia.com/Download/processFind.aspx?psid='+$psid+'&pfid='+$pfid+'&osid='+$os+'&lid=1&whql='+$whql+'&lang=en-us&ctk=0&qnfslb=10&dtcid=1'
    $link = Invoke-WebRequest -Uri $linkcreate -Method GET -UseBasicParsing
    $link -match '<td class="gridItem">([^<]+?)</td>' | Out-Null
    $version = $matches[1]
    if ($version -match "R"){
        ## Write-Host "Replacing invalid chars"
        $latest_version_nvidia = $version -replace '^.*\(|\)$',''
        RMM-Msg "Latest Nvidia driver : $latest_version_nvidia"
        }else {
        $latest_version_nvidia = $version
        RMM-Msg "Latest Nvidia driver : $latest_version_nvidia"
    }  
        # Create download URL
        $url = "https://international.download.nvidia.com/Windows$cardtype$latest_version_nvidia/$latest_version_nvidia-$drivername1-$windowsVersion-$windowsArchitecture-international-$drivername2-whql.exe"
        $rp_url = "https://international.download.nvidia.com/Windows$cardtype$latest_version_nvidia/$latest_version_nvidia-$drivername1-$windowsVersion-$windowsArchitecture-international-$drivername2-whql-rp.exe"
    return $latest_version_nvidia, $url, $rp_url
}
###############################################################################
# Function - Nvidia Driver Check Updates End
###############################################################################