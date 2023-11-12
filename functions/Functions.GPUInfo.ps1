###############################################################################
# Function - Get GPU Info
###############################################################################
function Get-GPUInfo {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    RMM-Msg "Script Mode: `tChecking GPU Information" -messagetype Verbose
    Set-Toast -Toasttitle "Driver Check" -Toasttext "Checking for GPU drivers" -UniqueIdentifier "default" -Toastenable $notifications
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
    # NVIDIA SECTION ##
    # Retrieve latest nvidia version if card exists
    $exists_nvidia = $gpuInfo | Where-Object { $_.Name -match "nvidia" }
    if($exists_nvidia){
        $latest_version_nvidia, $url, $rp_url = Get-driverlatestversionnvidia
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
        $ins_version_amd = Get-DriverInstalledamd
        $latest_version_amd , $driverLink_amd = Get-driverlatestversionamd
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
        }elseif ($intelgeneration -gt 5) {
            $driverLink_intel, $latest_version_intel = GetLatestDriverLink 'https://www.intel.com/content/www/us/en/download/776137/intel-7th-10th-gen-processor-graphics-windows.html' $generation
        }else {
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
    foreach ($gpu in $gpuinfo) {
        if ($gpu.DriverUptoDate -eq $false) {
            Set-Toast -Toasttitle "$($gpu.brand) Drivers Found" -Toasttext "Latest : $($gpu.DriverLatest) Installed : $($gpu.DriverInstalled)" -UniqueIdentifier "default" -Toastenable $notifications
            $outOfDateFound = $true
        }
    }
    if (!$outOfDateFound) {
        Set-Toast -Toasttitle "Driver Check" -Toasttext "No new drivers found" -UniqueIdentifier "default" -Toastenable $notifications
    }
    
    
    return $gpuInfo
}
###############################################################################
# Function - Get GPU Info End
###############################################################################
