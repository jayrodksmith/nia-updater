###############################################################################
# Function - Logging
###############################################################################
# Check if the folder exists
if (-not (Test-Path -Path $Script:logfilelocation -PathType Container)) {
  # Create the folder and its parent folders if they don't exist
  New-Item -Path $Script:logfilelocation -ItemType Directory -Force | Out-Null
}
$Global:nl = [System.Environment]::NewLine
$Global:ErrorCount = 0
$global:Output = '' 
function Get-TimeStamp() {
return (Get-Date).ToString("dd-MM-yyyy HH:mm:ss")
}
function RMM-LogParse{
$cutOffDate = (Get-Date).AddDays(-30)
$lines = Get-Content -Path $Script:logfile
$filteredLines = $lines | Where-Object {
      if ($_ -match '^(\d{2}-\d{2}-\d{4} \d{2}:\d{2}:\d{2})') {
          $lineDate = [DateTime]::ParseExact($matches[1], 'dd-MM-yyyy HH:mm:ss', $null)
          $lineDate -ge $cutOffDate
      } else {
          $true  # Include lines without a recognized date
      }
  }
  $filteredLines | Set-Content -Path $Script:logfile
}

function RMM-Initilize{
Add-content $Script:logfile -value "$(Get-Timestamp) -----------------------------$Script:logdescription"
}

function RMM-Msg{
param (
  $Message,
  [ValidateSet('Verbose','Debug','Silent')]
  [string]$messagetype = 'Silent'
)
$global:Output += "$(Get-Timestamp) - Msg   : $Message"+$Global:nl
Add-content $Script:logfile -value "$(Get-Timestamp) - Msg   : $message"
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
Add-content $Script:logfile -value "$(Get-Timestamp) - Error : $message"
if($messagetype -eq 'Verbose'){Write-Warning "$Message"}elseif($messagetype -eq 'Debug'){Write-Debug "$Message"}
}

#######
function RMM-Exit{  
param(
  [int]$ExitCode = 0
)
$Message = '----------'+$Global:nl+"$(Get-Timestamp) - Errors : $Global:ErrorCount"
$global:Output += "$(Get-Timestamp) $Message"
Add-content $Script:logfile -value "$(Get-Timestamp) - Exit  : $message Exit Code = $Exitcode"
Add-content $Script:logfile -value "$(Get-Timestamp) -----------------------------Log End"
Write-Output "Errors : $Global:ErrorCount"
RMM-LogParse
Exit $ExitCode
}

###############################################################################
# Function - Logging End
###############################################################################