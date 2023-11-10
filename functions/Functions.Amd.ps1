###############################################################################
# Function - Amd Driver Installer
###############################################################################

function Set-DriverUpdatesamd {
    RMM-Msg "Script Mode: `tUpdating AMD drivers" -messagetype Verbose
    Set-Toast -Toasttitle "Updating Drivers" -Toasttext "Updating AMD Drivers" -UniqueIdentifier "default" -Toastenable $notifications
    $gpuInfoamd = $gpuInfo | Where-Object { $_.Name -match "amd" }
    $extractinfo = Get-extract
    if ($gpuInfoamd.DriverUptoDate -eq $True){
      RMM-Msg "AMD Drivers already upto date"
      $Script:installstatus = "uptodate"
      return
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
    Set-Toast -Toasttitle "Updating Drivers" -Toasttext "$amdversion AMD Drivers Installed" -UniqueIdentifier "default" -Toastenable $notifications
    $Script:installstatus = "Updated"
    return
} 
###############################################################################
# Function - Amd Driver Installer End
###############################################################################

###############################################################################
# Function - Amd Driver Check Updates
###############################################################################
function Get-driverlatestversionamd {
  param (
    [string]$amddriverdetails = "https://videocardz.com/sections/drivers" # URL to check for driver details
  )
  $response = Invoke-WebRequest -Uri $amddriverdetails -UseBasicParsing
  RMM-Msg "Checking $amddriverdetails for driver details" 
  $matches = [regex]::Matches($response, 'href="([^"]*https://videocardz.com/driver/amd-radeon-software-adrenalin[^"]*)"')
  $link = $matches.Groups[1].Value
  RMM-Msg "Checking $link for latest driver details" 
  $response = Invoke-WebRequest -Uri $link -UseBasicParsing
  $latestversion = [regex]::Match($response, "Download AMD Radeon Software Adrenalin (\d+\.\d+\.\d+)").Groups[1].Value
  $matches = [regex]::Matches($response, 'href="([^"]*https://www.amd.com/en/support/kb/release-notes[^"]*)"')
  $link = $matches.Groups[1].Value
  RMM-Msg "Checking $link for latest driver download url"
  Start-Sleep -Seconds 10
  $response = Invoke-RestMethod -Uri $link
  $matches = [regex]::Matches($response, 'href="([^"]*https://drivers.amd.com/drivers/whql-amd-software-[^"]*)"')
  $driverlink = $matches.Groups[1].Value
  # Check if matches were found
  if ($latestversion) {
      # Extract the desired values from the matches
      $latest_version_amd = $latestversion
      RMM-Msg "Latest AMD driver : $latest_version_amd" 
  } else {
      RMM-Error "No Version found." -messagetype Verbose
  }                      
  if ($driverlink) {
      $driverLink_amd = $driverlink
      RMM-Msg "Link AMD driver : $driverLink_amd"
  } else {
      RMM-Error "Download URL not found." -messagetype Verbose
  }
  return $latest_version_amd, $driverLink_amd
}
###############################################################################
# Function - Amd Driver Check Updates End
###############################################################################

###############################################################################
# Function - Amd Driver Check Installed
###############################################################################

function Get-DriverInstalledamd {
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
      }
  }
  return $ins_version_amd
}

###############################################################################
# Function - Amd Driver Check Installed End
###############################################################################