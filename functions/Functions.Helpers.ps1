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
                Set-Toast -Toasttitle "Download Error" -Toasttext "Error occurred : $($_.Exception.Message)" -UniqueIdentifier "default" -Toastenable $notifications
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

##############################################################################
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