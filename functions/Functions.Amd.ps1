###############################################################################
# Function - Amd Driver Installer
###############################################################################

function Set-DriverUpdatesamd {
    RMM-Msg "Script Mode: `tUpdating AMD drivers" -messagetype Verbose
    $gpuInfoamd = $gpuInfo | Where-Object { $_.Name -match "amd" }
    $extractinfo = Get-extract
    if ($gpuInfoamd.DriverUptoDate -eq $True){
      RMM-Msg "AMD Drivers already upto date"
      return "uptodate"
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
    return "Updated"
  }
  
  ###############################################################################
  # Function - Amd Driver Installer End
  ###############################################################################