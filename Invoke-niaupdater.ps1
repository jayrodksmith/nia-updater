$niaupdater = (Join-Path -Path $ENV:ProgramData -ChildPath "niaupdater")
$niaupdaterRepo = 'https://github.com/jayrodksmith/nia-updater' # Note the lack of trailing `/` please.
$niaupdaterPath = (Join-Path -Path $ENV:ProgramData -ChildPath "niaupdater")
$releases = "https://api.github.com/repos/jayrodksmith/nia-updater/releases"
$latestversion = (Invoke-WebRequest $releases | ConvertFrom-Json)[0].tag_name
$installedversion = Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\Software\niaupdater' -erroraction silentlycontinue | Select-Object -ExpandProperty Version
$niaupdaterTempExtractionPath = (Join-Path -Path $ENV:Temp -ChildPath "niaupdater")
$uptodate = if($latestversion -eq $installedversion){$true}else{$false}

if(!$uptodate){
# Download the repository
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
$updatedversion = Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\Software\niaupdater' -Name 'Version' -Value $latestversion -erroraction silentlycontinue

# Remove the downloaded zip file
Remove-Item -Path $niaupdaterDownloadFile -Force

# Remove the extracted folder
Remove-Item -Path $niaupdaterTempExtractionPath -Force -Recurse

# Confirm that we have the `nia-updater.ps1` file
if (-not (Test-Path -Path ('{0}\nia-updater.ps1' -f $niaupdaterPath))) {
    throw 'Unable to find the nia-updater.ps1 file. Please check the installation.'
}
}
