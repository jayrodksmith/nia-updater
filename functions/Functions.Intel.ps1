###############################################################################
# Function - Intel Driver Installer
###############################################################################
function Set-DriverUpdatesintel{
    RMM-Msg "Script Mode: `tUpdating Intel drivers" -messagetype Verbose
    $gpuInfointel = $gpuInfo | Where-Object { $_.Name -match "intel" }
    $extractinfo = Get-extract
    if ($gpuInfointel.DriverUptoDate -eq $True){
      RMM-Msg "Intel Drivers already upto date" -messagetype Verbose
      return "uptodate"
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
    return "Updated"
   }
  ###############################################################################
  # Function - Intel Driver Installer End
  ###############################################################################