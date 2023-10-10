<#
Get-DownloadUrls
    Used to download files

Get-GPUInfo
    Used to retrieve versions for installed and latest drivers

Get-Extract
    Used to verify if 7zip installed and install if required

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
            checkGpuInfo                        (Script Variable Checkbox) (Set Default True)
            logInfoToNinjarmm                   (Script Variable Checkbox) (Set Default True)
#>
param (
        [string]$update_nvidia = $env:updateNvidiaDrivers,
        [string]$update_amd = $env:updateamdDrivers,
        [string]$update_intel = $env:updateintelDrivers,
        [string]$drivers_check = $env:checkGpuInfo,
        [string]$drivers_log = $env:logInfoToNinjarmm,
        [string]$restartAfterUpdating = $env:restartAfterUpdating,
        [ValidateSet('NinjaOne', 'Standalone')]
        [string]$RMMPlatform = "NinjaOne",
        [string]$programdirectory = "C:\ProgramData\nia-updater",
        # Currently not implemented
        [bool]$notifications = $false
        )
###############################################################################
# Pre Steps
###############################################################################

## Check if run as adminstrator
function Test-Administrator  
{  
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)  
}
$administrator = Test-Administrator
if($administrator -eq $true){Write-Output "Running As Admin"}else{
    Write-Output "Not running as Admin, run this script elevated"
    exit 0
}

## If ran outside of NinjaRMM automation, will set to check and print driver info by default.
## With no logging to ninja and no updating

if(!$update_nvidia){$update_nvidia = $false}
if(!$update_amd) {$update_amd = $false}
if(!$update_intel) {$update_intel = $false}
if(!$drivers_check) {$drivers_check = $true}
if(!$drivers_log) {$drivers_log = $false}
if(!$restartAfterUpdating) {$restartAfterUpdating = $false}

###############################################################################
# Function - Logging
###############################################################################

$LogDate = get-date -format "dd-MM-yy HH:MM"
$logfilelocation = "$programdirectory\logs"
$logfilename = "nia-updater.log"
$logdescription = "nia-updater"
# Check if the folder exists
if (-not (Test-Path -Path $logfilelocation -PathType Container)) {
    # Create the folder and its parent folders if they don't exist
    New-Item -Path $logfilelocation -ItemType Directory -Force | Out-Null
}
$logfilelocation = "$logfilelocation\$logfilename"
$Global:nl = [System.Environment]::NewLine
$Global:ErrorCount = 0
$global:Output = '' 
function Get-TimeStamp() {
  return (Get-Date).ToString("dd-MM-yyyy HH:mm:ss")
}
function RMM-LogParse{
  $cutOffDate = (Get-Date).AddDays(-30)
  $lines = Get-Content -Path $logfilelocation
  $filteredLines = $lines | Where-Object {
    if ($_ -match '^(\d{2}-\d{2}-\d{4} \d{2}:\d{2}:\d{2})') {
        $lineDate = [DateTime]::ParseExact($matches[1], 'dd-MM-yyyy HH:mm:ss', $null)
        $lineDate -ge $cutOffDate
    } else {
        $true  # Include lines without a recognized date
    }
}
$filteredLines | Set-Content -Path $logfilelocation
}

function RMM-Initilize{
  Add-content $logfilelocation -value "$(Get-Timestamp) -----------------------------$logdescription"
}
RMM-Initilize

function RMM-Msg{
  param (
    $Message,
    [ValidateSet('Verbose','Debug','Silent')]
    [string]$messagetype = 'Silent'
  )
  $global:Output += "$(Get-Timestamp) - Msg   : $Message"+$Global:nl
  Add-content $logfilelocation -value "$(Get-Timestamp) - Msg   : $message"
  if($messagetype -eq 'Verbose'){Write-Output "$Message"}elseif($messagetype -eq 'Debug'){Write-Debug "$Message"}
}

#######
function RMM-Error{
    param (
    $Message,
    [ValidateSet('Verbose','Debug','Silent')]
    [string]$messagetype = 'Silent'
  )
  $Global:ErrorCount += 1
  $global:Output += "$(Get-Timestamp) - Error : $Message"+$Global:nl
  Add-content $logfilelocation -value "$(Get-Timestamp) - Error : $message"
  if($messagetype -eq 'Verbose'){Write-Warning "$Message"}elseif($messagetype -eq 'Debug'){Write-Debug "$Message"}
}

#######
function RMM-Exit{  
  param(
    [int]$ExitCode = 0
  )
  $Message = '----------'+$Global:nl+"$(Get-Timestamp) - Errors : $Global:ErrorCount"
  $global:Output += "$(Get-Timestamp) $Message"
  Add-content $logfilelocation -value "$(Get-Timestamp) - Exit  : $message Exit Code = $Exitcode"
  Add-content $logfilelocation -value "$(Get-Timestamp) -----------------------------Log End"
  Write-Output "Errors : $Global:ErrorCount"
  RMM-LogParse
  Exit $ExitCode
}

###############################################################################
# Function - Logging End
###############################################################################

## Write to screen what is being done
if($drivers_check -eq $true){
  RMM-Msg "Script Mode: `tChecking drivers" -messagetype Verbose
}
if($drivers_log -eq $true){
  RMM-Msg "Script Mode: `tLogging details to NinjaRMM" -messagetype Verbose
}
if($update_nvidia -eq $true){
  RMM-Msg "Script Mode: `tUpdating Nvidia drivers" -messagetype Verbose
}
if($update_amd -eq $true){
  RMM-Msg "Script Mode: `tUpdating AMD drivers" -messagetype Verbose
}
if($update_intel -eq $true){
  RMM-Msg "Script Mode: `tUpdating Intel drivers" -messagetype Verbose
}


###############################################################################
# Function - Download Files
###############################################################################
## Get Download URL
function Get-DownloadUrls {
    param (
        [string[]]$urllist,
        [string]$downloadLocation,
        [switch]$continueOnError
    )
    $totalUrls = $urllist.Length
    # Loop through each URL in the array and download the files using BitsTransfer
    for ($i = 0; $i -lt $totalUrls; $i++) {
        $url = $urllist[$i]

        # Write the progress message with the part number
        RMM-Msg "Downloading Part $($i + 1) of $totalUrls" -messagetype Verbose
        try {
            # Download the file using Start-BitsTransfer directly to the destination folder
            Start-BitsTransfer -Source $url -Destination $downloadLocation -Priority High -ErrorAction Stop
        } catch {
            # If an error occurs and the continueOnError switch is set, move on to the next URL
            if ($continueOnError) {
                RMM-Error "Error occurred while downloading: $($_.Exception.Message)" -messagetype Verbose
                
                $global:downloadError = $true
                continue
            } else {
                # If the continueOnError switch is not set, terminate the loop and function
                Start-sleep -Seconds 5
                RMM-Error "Error occurred while downloading: $($_.Exception.Message)" -messagetype Verbose
                RMM-Error "$url" -messagetype Verbose
                $global:downloadError = $true
                RMM-Exit "1"
            }
        }
    }
    RMM-Msg "All files downloaded to $downloadlocation" -messagetype Verbose
    Start-sleep -Seconds 5
}
###############################################################################
# Function - Download Files End
###############################################################################

###############################################################################
# Function - Get GPU Info
###############################################################################
function Get-GPUInfo {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    $cim_os = Get-CimInstance -ClassName win32_operatingsystem | select Caption 
    $cim_cpu = Get-CimInstance -ClassName Win32_Processor
    $cim_gpu = Get-CimInstance -ClassName Win32_VideoController | Where-Object { $_.Name -match "NVIDIA|AMD|Intel" }
    $gpu_integrated = @(
        "AMD Radeon (\d+)M Graphics",
        "Radeon \(TM\) Graphics",
        "AMD Radeon\(TM\) Graphics",
        "AMD Radeon\(TM\) R2 Graphics",
        "AMD Radeon\(TM\) Vega (\d+) Graphics",
        "AMD Radeon\(TM\) RX Vega (\d+) Graphics",
        "Intel\(R\) UHD",
        "Intel\(R\) HD",
        "Intel\(R\) Iris\(R\)"
)
    $gpuInfo = [System.Collections.Generic.List[object]]::New()
    # GPU Reporting
    foreach ($gpu in $cim_gpu) {
        $gpuObject = [PSCustomObject]@{
            Name = $gpu.Name
            DriverInstalled = if ($gpu.Name -match "NVIDIA"){($gpu.DriverVersion.Replace('.', '')[-5..-1] -join '').insert(3, '.')}elseif($gpu.Name -notmatch "AMD"){$gpu.DriverVersion}else{$gpu.DriverVersion}
            DriverLatest = $null
            DriverUptoDate = $null
            DriverLink = $null
            DriverLink2 = $null
            Brand = if ($gpu.Name -match "Nvidia"){"NVIDIA"}elseif($gpu.Name -match "AMD"){"AMD"}elseif($gpu.Name -match "INTEL"){"INTEL"}elseif($gpu.Name -match "DisplayLink"){"DisplayLink"}else{"Unknown"}
            IsDiscrete = $null
            IsIntegrated = $null
            Processor = $null
            Generation = $null
            Resolution = if ($gpu.CurrentHorizontalResolution -and $gpu.CurrentVerticalResolution) {"$($gpu.CurrentHorizontalResolution)x$($gpu.CurrentVerticalResolution)"}
        }
        
        $matchedPattern = $null  # Store the matched pattern for debugging
        
        # Detect if the adapter type matches any of the custom regex patterns for integrated GPUs
        foreach ($regex in $gpu_integrated) {
        if ($gpu.Name -match $regex) {
            $gpuObject.IsIntegrated = $true
            $matchedPattern = $regex  # Store the matched pattern for debugging
            $gpuObject.IsDiscrete = $false
            $gpuObject.Processor = $cim_cpu.Name
            break  # Exit the loop after the first match
          }
        }
         # Output debugging information
        RMM-Msg "GPU: $($gpu.Name)"
        if($matchedPattern) {RMM-Msg "Matched Pattern: $($matchedPattern)" -messagetype Verbose}
         if ($gpuObject.IsIntegrated -eq $null) {
            $gpuObject.IsIntegrated = $false
            $gpuObject.IsDiscrete = $true
        }
       
        $gpuInfo.Add($gpuObject)
    }
        ## NVIDIA SECTION ##
        # Retrieve latest nvidia version if card exists
        $exists_nvidia = $gpuInfo | Where-Object { $_.Name -match "nvidia" }
        if($exists_nvidia){
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
       
        }
        elseif ($exists_nvidia.name -match "Geforce") {
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
    }  
        # Update the DriverLink for the NVIDIA device
        $gpuInfo | ForEach-Object {
            if ($_.Name -match "NVIDIA") {
                $_.DriverLatest = "$latest_version_nvidia"
                $_.DriverUptoDate = if($latest_version_nvidia -eq $_.DriverInstalled){$True}else{$False}
                $_.DriverLink = $url
                $_.DriverLink2 = $rp_url
                
                RMM-Msg "Installed Nvidia driver : $($gpuInfo | Where-Object { $_.Name -match 'nvidia' } | Select-Object -ExpandProperty DriverInstalled)"
                RMM-Msg "Link Nvidia driver : $url"
             }
        }
      ## AMD SECTION ##      
      $exists_amd = $gpuInfo | Where-Object { $_.Name -match "amd" }
      if($exists_amd){
            $amddriverdetails = "https://gpuopen.com/version-table/"
            $response = Invoke-WebRequest -Uri $amddriverdetails -UseBasicParsing
            # Define the regular expression patterns to match the data-content attribute and href attribute
            $dataContentPattern = 'data-content=''([\d\.]+)'''
            $hrefPattern = 'href=''(https://www.amd.com[^'']+)'''
            # Find matches for both patterns in the HTML content
            $dataContentMatch = [regex]::Match($response, $dataContentPattern)
            $hrefMatch = [regex]::Match($response, $hrefPattern)
              # Check if matches were found
            if ($dataContentMatch.Success -and $hrefMatch.Success) {
                # Extract the desired values from the matches
                $latest_version_amd = $dataContentMatch.Groups[1].Value
                RMM-Msg "Latest AMD driver : $latest_version_amd"
                $driverrn_amd  = $hrefMatch.Groups[1].Value
                
            } else {
                RMM-Error "No data found." -messagetype Verbose
            }                      
            $response2 = Invoke-RestMethod -Uri $driverrn_amd
            $pattern = 'https://drivers\.amd\.com/drivers/[^"]+'  # Regular expression pattern to match the URL
            $match = [regex]::Match($response2, $pattern)
            if ($match.Success) {
                $driverLink_amd = $match.Value
               
            } else {
                RMM-Error "Download URL not found." -messagetype Verbose
            }
            $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
            # Retrieve the subkeys from the specified registry path
            $subKeys = Get-Item -Path $registryPath | Get-ChildItem -ErrorAction SilentlyContinue
            # Loop through each subkey and retrieve the value of "RadeonSoftwareVersion" if it exists
            foreach ($subKey in $subKeys) {
                $value = Get-ItemProperty -Path $subKey.PSPath -Name "RadeonSoftwareVersion" -ErrorAction SilentlyContinue
                if ($value) {
                    #Write-Output "Subkey: $($subKey.PSChildName) - RadeonSoftwareVersion: $($value.RadeonSoftwareVersion)"
                    $ins_version_amd = $($value.RadeonSoftwareVersion)
                    RMM-Msg "Installed AMD driver : $ins_version_amd"
                    RMM-Msg "Link AMD driver : $driverLink_amd"
                }
        }
            $gpuInfo | ForEach-Object {
                if ($_.Name -match "AMD") {
                    $_.DriverInstalled = $ins_version_amd
                    $_.DriverLatest = $latest_version_amd
                    $_.DriverUptoDate = if($latest_version_amd -eq $ins_version_amd){$True}else{$False}
                    $_.DriverLink = $driverLink_amd
                 }
            }

      }
      ## INTEL SECTION ##
      $exists_intel = $gpuInfo | Where-Object { $_.Name -match "intel" }
      if($exists_intel){
            ## Retrieve Intel Generation
            $generationPattern = "-(\d+)\d{3}"
            $matches = [System.Text.RegularExpressions.Regex]::Match($gpuinfo.Processor, $generationPattern)
            if ($matches.Success) {
            $generation = [decimal]$matches.Groups[1].Value
            $intelGeneration = if ($generation -ge 2 -and $generation -le 14) {
               "$generation Gen"
                } else {
                "Unknown"
                }
            } else {
            $intelGeneration = "Unknown"
            }
            $gpuInfo | ForEach-Object {
                if ($_.Name -match "INTEL") {
                   $_.Generation = $generation
                 }
            }
           ## Retreve Driver link function
           function GetLatestDriverLink($url, $generation) {
            $content = Invoke-WebRequest $url -Headers @{'Referer' = 'https://www.intel.com/'} -UseBasicParsing | % Content
            $linkPattern = '<meta\ name="RecommendedDownloadUrl"\ content="([^"]+)'
            $versionPattern = '<meta\ name="DownloadVersion"\ content="([^"]+)'
            if ($content -match $linkPattern) {
                $driverLink_intel = $Matches[1].Replace(".exe", ".exe")
            }
            if ($content -match $versionPattern) {
                $driverVersion = $Matches[1]
                $latest_version_intel = $driverVersion
                RMM-Msg "`t`t`tLatest Intel driver : $latest_version_intel" -messagetype Verbose
                
            }
            return $driverLink_intel, $latest_version_intel
        }
        if ($intelgeneration -gt 10) {
            $driverLink_intel, $latest_version_intel = GetLatestDriverLink 'https://www.intel.com/content/www/us/en/download/785597/intel-arc-iris-xe-graphics-windows.html' $generation          
        }
        elseif ($intelgeneration -gt 5) {
            $driverLink_intel, $latest_version_intel = GetLatestDriverLink 'https://www.intel.com/content/www/us/en/download/776137/intel-7th-10th-gen-processor-graphics-windows.html' $generation
        }
        else {
            $latest_version_intel = "Legacy"
        }
        $gpuInfo | ForEach-Object {
            if ($_.Name -match "INTEL") {
                $_.DriverLatest = $latest_version_intel
                $_.DriverUptoDate = if($latest_version_intel -eq $_.DriverInstalled){$True}else{$False}
                $_.DriverLink = $driverLink_intel
                RMM-Msg "Installed Intel driver : $($gpuInfo | Where-Object { $_.Name -match 'INTEL' } | Select-Object -ExpandProperty DriverInstalled)"
                RMM-Msg "Link Intel driver : $driverLink_intel"
             }
        }

        }
   
    return $gpuInfo
}
###############################################################################
# Function - Get GPU Info End
###############################################################################

###############################################################################
# Function - Get Extract Info
###############################################################################
function Get-extract{
    $extractinfo = [System.Collections.Generic.List[object]]::New()
    $extractObject = [PSCustomObject]@{
        '7zipinstalled' = $null
        archiverProgram = $null
    }

# Checking if 7zip or WinRAR are installed
# Check 7zip install path on registry
$7zipinstalled = $false 
if ((Test-path HKLM:\SOFTWARE\7-Zip\) -and ([bool]((Get-itemproperty -Path "HKLM:\SOFTWARE\7-Zip").Path)) -eq $true) {
    RMM-Msg "7zip is Installed"
    $7zpath = Get-ItemProperty -path  HKLM:\SOFTWARE\7-Zip\ -Name Path
    $7zpath = $7zpath.Path
    $7zpathexe = $7zpath + "7z.exe"
    if ((Test-Path $7zpathexe) -eq $true) {
        $extractObject.archiverProgram = $7zpathexe
        $extractObject.'7zipinstalled' = $true 
    }    
}
else {
    RMM-Msg "Sorry, but it looks like you don't have a supported archiver." -messagetype Verbose
    Write-Host ""
    # Download and silently install 7-zip if the user presses y
    $7zip = "https://www.7-zip.org/a/7z2301-x64.exe"
    $output = "$folder\7Zip.exe"
    (New-Object System.Net.WebClient).DownloadFile($7zip, $output)
       
    Start-Process "$folder\7Zip.exe" -Wait -ArgumentList "/S"
    # Delete the installer once it completes
    Remove-Item "$folder\7Zip.exe"
    RMM-Msg "7zip Installed"  -messagetype Verbose
    $7zpath = Get-ItemProperty -path  HKLM:\SOFTWARE\7-Zip\ -Name Path
    $7zpath = $7zpath.Path
    $7zpathexe = $7zpath + "7z.exe"
    if ((Test-Path $7zpathexe) -eq $true) {
        $extractObject.archiverProgram = $7zpathexe
        $extractObject.'7zipinstalled' = $true 
    }    
}
$extractinfo.Add($extractObject)
return $extractinfo 
}

###############################################################################
# Function - Get Extract Info End
###############################################################################

###############################################################################
# Function - Nvidia Driver Installer
###############################################################################
function Set-DriverUpdatesNvidia {
    param (
    [switch]$clean = $false, # Will delete old drivers and install the new ones
    [string]$folder = "C:\Temp"   # Downloads and extracts the driver here
)

$gpuInfoNvidia = $gpuInfo | Where-Object { $_.Name -match "nvidia" }
$extractinfo = Get-extract
if ($gpuInfoNvidia.DriverUptoDate -eq $True){
    RMM-Msg "Nvidia Drivers already upto date" -messagetype Verbose
    RMM-Exit 0
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
Set-GPUtoNinjaRMM
}

###############################################################################
# Function - Nvidia Driver Installer End
###############################################################################

###############################################################################
# Function - Amd Driver Installer
###############################################################################

function Set-DriverUpdatesamd {
  RMM-Msg "Updating AMD Driver" -messagetype Verbose
  $gpuInfoamd = $gpuInfo | Where-Object { $_.Name -match "amd" }
  $extractinfo = Get-extract
  if ($gpuInfoamd.DriverUptoDate -eq $True){
    RMM-Msg "AMD Drivers already upto date"
    RMM-Exit 0
  }
  $amdversion = $gpuInfoamd.DriverLatest
  $amdurl = $gpuInfoamd.DriverLink
  Invoke-WebRequest -Uri $amdurl -Headers @{'Referer' = 'https://www.amd.com/en/support'} -Outfile C:\temp\ninjarmm\$amdversion.exe -usebasicparsing
  # Installing drivers
  RMM-Msg "Installing AMD drivers now..." -messagetype Verbose
  $install_args = "-install"
  Start-Process -FilePath "C:\temp\ninjarmm\$amdversion.exe" -ArgumentList $install_args -wait
  RMM-Msg "Driver installed. You may need to reboot to finish installation." -messagetype Verbose
  RMM-Msg "Driver installed. $amdversion" -messagetype Verbose
  Set-GPUtoNinjaRMM
}

###############################################################################
# Function - Amd Driver Installer End
###############################################################################

###############################################################################
# Function - Intel Driver Installer
###############################################################################
function Set-DriverUpdatesintel{
  RMM-Msg "Updating Intel Driver" -messagetype Verbose
  $gpuInfointel = $gpuInfo | Where-Object { $_.Name -match "intel" }
  $extractinfo = Get-extract
  if ($gpuInfointel.DriverUptoDate -eq $True){
    RMM-Msg "Intel Drivers already upto date" -messagetype Verbose
    RMM-Exit 0
  }
  $intelversion = $gpuInfointel.DriverLatest
  $intelurl = $gpuInfointel.DriverLink
  $inteldriverfile = "C:\temp\ninjarmm\$intelversion.exe"
  mkdir "C:\temp\ninjarmm\$intelversion"
  $extractFolder = "C:\temp\ninjarmm\$intelversion"
  if (-not(Test-Path -Path $inteldriverfile -PathType Leaf)){
  Invoke-WebRequest -Uri $intelurl -Headers @{'Referer' = 'https://www.intel.com/'} -Outfile C:\temp\ninjarmm\$intelversion.exe -usebasicparsing
  }
  if ($extractinfo.'7zipinstalled') {
    Start-Process -FilePath $extractinfo.archiverProgram -NoNewWindow -ArgumentList "x -bso0 -bsp1 -bse1 -aoa $inteldriverfile -o""$extractFolder""" -wait
}else {
    RMM-Error "Something went wrong. No archive program detected. This should not happen." -messagetype Verbose
    RMM-Exit 1
}

  # Installing drivers
  RMM-Msg "Installing Intel drivers now..." -messagetype Verbose
  $install_args = "--silent"
  Start-Process -FilePath "$extractFolder\installer.exe" -ArgumentList $install_args -wait
  RMM-Msg "Driver installed. You may need to reboot to finish installation." -messagetype Verbose
  RMM-Msg "Driver installed. $intelversion" -messagetype Verbose
  Set-GPUtoNinjaRMM
}
###############################################################################
# Function - Intel Driver Installer End
###############################################################################

###############################################################################
# Function - Send Info to Ninja
###############################################################################

function Set-GPUtoNinjaRMM {
    RMM-Msg "Writing Details to NinjaRMM custom fields" -messagetype Verbose
    foreach ($gpu in $gpuInfo) {
        if ($gpu.IsDiscrete){
            $discreteGPUFound = $true
            Ninja-Property-Set hardwarediscretegpu $gpu.Name
            Ninja-Property-Set hardwarediscretedriverinstalled $gpu.DriverInstalled
            Ninja-Property-Set hardwarediscretedriverlatest $gpu.DriverLatest
            if($gpu.DriverUptoDate){
                Ninja-Property-Set hardwarediscretedriveruptodate "1"
            }else {
                Ninja-Property-Set hardwarediscretedriveruptodate "0"
            }
        }
        if ($gpu.IsIntegrated){
            $integratedGPUFound = $true
            Ninja-Property-Set hardwareintegratedgpu $gpu.Name
            Ninja-Property-Set hardwareintegrateddriverinstalled $gpu.DriverInstalled
            Ninja-Property-Set hardwareintegrateddriverlatest $gpu.DriverLatest
            if($gpu.DriverUptoDate){
                Ninja-Property-Set hardwareintegrateddriveruptodate "1"
            }else {
                Ninja-Property-Set hardwareintegrateddriveruptodate "0"
            }
        }

    }
if (-not $integratedGPUFound) {
Ninja-Property-Set hardwareintegratedgpu "Not Detected"
Ninja-Property-Set hardwareintegrateddriverinstalled clear
Ninja-Property-Set hardwareintegrateddriverlatest clear
Ninja-Property-Set hardwareintegrateddriveruptodate clear
}
if (-not $discreteGPUFound) {
Ninja-Property-Set hardwarediscretegpu "Not Detected"
}
}

###############################################################################
# Function - Send Info to Ninja end
###############################################################################

###############################################################################
# Main Script Starts Here
###############################################################################

if($drivers_check -eq $true){
$gpuInfo = Get-GPUInfo
$gpuInfo
}
if($drivers_log -eq $true){
if($RMMPlatform -eq "NinjaOne"){Set-GPUtoNinjaRMM}
}
if($update_amd -eq $true){
    Set-DriverUpdatesamd 
    if($restartAfterUpdating -eq $true){shutdown /r /t 30 /c "In 30 seconds, the computer will be restarted to finish installing AMD Drivers"}
}
if($update_nvidia -eq $true){
    Set-DriverUpdatesNvidia
    if($restartAfterUpdating -eq $true){shutdown /r /t 30 /c "In 30 seconds, the computer will be restarted to finish installing NVIDIA Drivers"}
}
if($update_intel -eq $true){
    Set-DriverUpdatesintel 
    if($restartAfterUpdating -eq $true){shutdown /r /t 30 /c "In 30 seconds, the computer will be restarted to finish installing INTEL Drivers"}
}
RMM-Exit 0

###############################################################################
# Main Script Ends Here
###############################################################################