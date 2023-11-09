## Check if toast installed
if(-not (Get-Module BurntToast -ListAvailable)){
    Install-Module BurntToast -Force
    Import-Module BurntToast
    }else{
        Import-Module BurntToast
    }
if(-not (Get-Module RunAsUser -ListAvailable)){
    Install-Module RunAsUser -Force
    Import-Module RunAsUser
    }else{
        Import-Module RunAsUser
    }

#Checking if ToastReboot:// protocol handler is present
New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -erroraction silentlycontinue | out-null
$ProtocolHandler = get-item 'HKCR:\ToastReboot' -erroraction 'silentlycontinue'
if (!$ProtocolHandler) {
    #create handler for reboot
    New-item 'HKCR:\ToastReboot' -force
    set-itemproperty 'HKCR:\ToastReboot' -name '(DEFAULT)' -value 'url:ToastReboot' -force
    set-itemproperty 'HKCR:\ToastReboot' -name 'URL Protocol' -value '' -force
    new-itemproperty -path 'HKCR:\ToastReboot' -propertytype dword -name 'EditFlags' -value 2162688
    New-item 'HKCR:\ToastReboot\Shell\Open\command' -force
    set-itemproperty 'HKCR:\ToastReboot\Shell\Open\command' -name '(DEFAULT)' -value 'C:\Windows\System32\shutdown.exe -r -t 00' -force
}
## Toast Notification Icons
Function Register-NotificationApp {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]$AppID,
        [Parameter(Mandatory=$true)]$AppDisplayName,
        [Parameter(Mandatory=$false)]$AppIconUri,
        [Parameter(Mandatory=$false)][int]$ShowInSettings = 0
    )
    $HKCR = Get-PSDrive -Name HKCR -ErrorAction SilentlyContinue
    If (!($HKCR))
    {
        New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -Scope Script
    }
    $AppRegPath = "HKCR:\AppUserModelId"
    $RegPath = "$AppRegPath\$AppID"
    If (!(Test-Path $RegPath))
    {
        $null = New-Item -Path $AppRegPath -Name $AppID -Force
    }
    $DisplayName = Get-ItemProperty -Path $RegPath -Name DisplayName -ErrorAction SilentlyContinue | Select -ExpandProperty DisplayName -ErrorAction SilentlyContinue
    If ($DisplayName -ne $AppDisplayName)
    {
        $null = New-ItemProperty -Path $RegPath -Name DisplayName -Value $AppDisplayName -PropertyType String -Force
    }
    $IconUri = Get-ItemProperty -Path $RegPath -Name IconUri -ErrorAction SilentlyContinue | Select -ExpandProperty IconUri -ErrorAction SilentlyContinue
    If ($IconUri -ne $AppIconUri)
    {
        $null = New-ItemProperty -Path $RegPath -Name IconUri -Value $AppIconUri -PropertyType String -Force
    }
    $ShowInSettingsValue = Get-ItemProperty -Path $RegPath -Name ShowInSettings -ErrorAction SilentlyContinue | Select -ExpandProperty ShowInSettings -ErrorAction SilentlyContinue
    If ($ShowInSettingsValue -ne $ShowInSettings)
    {
        $null = New-ItemProperty -Path $RegPath -Name ShowInSettings -Value $ShowInSettings -PropertyType DWORD -Force
    }
    Remove-PSDrive -Name HKCR -Force
}
$AppID = "NIAUpdater.Notification"
$AppDisplayName = "NIA Updater"
$AppIconUri = "C:\ProgramData\niaupdater\resources\logos\logo_ninjarmm_square.png"
Register-NotificationApp -AppID $AppID -AppDisplayName $AppDisplayName -AppIconUri $AppIconUri
## Main Toast Function

function Set-Toast{
    param (
    [string]$Toastenable = $true,
    [string]$Toasttitle = "",
    [string]$Toasttext = "",
    [string]$Toastlogo = "C:\ProgramData\niaupdater\resources\logos\logo_ninjarmm_square.png",
    [string]$UniqueIdentifier = "default",
    [switch]$Toastreboot = $false
    )
    if($Toastenable -eq $false){return}
    New-BTAppId -AppId "NIAUpdater.Notification"
    if($Toastreboot){
            $scriptblock = {
                $logoimage = New-BTImage -Source $Toastlogo -AppLogoOverride -Crop Default
                $Text1 = New-BTText -Content  "$Toasttitle"
                $Text2 = New-BTText -Content "$Toasttext"
                $Button = New-BTButton -Content "Snooze" -Snooze -id 'SnoozeTime'
                $Button2 = New-BTButton -Content "Reboot now" -Arguments "ToastReboot:" -ActivationType Protocol
                $Button3 = New-BTButton -Content "Dismiss" -Dismiss
                $10Min = New-BTSelectionBoxItem -Id 10 -Content '10 minutes'
                $1Hour = New-BTSelectionBoxItem -Id 60 -Content '1 hour'
                $1Day = New-BTSelectionBoxItem -Id 1440 -Content '1 day'
                $Items = $10Min, $1Hour, $1Day
                $SelectionBox = New-BTInput -Id 'SnoozeTime' -DefaultSelectionBoxItemId 10 -Items $Items
                $action = New-BTAction -Buttons $Button, $Button2, $Button3 -inputs $SelectionBox
                $Binding = New-BTBinding -Children $text1, $text2 -AppLogoOverride $logoimage
                $Visual = New-BTVisual -BindingGeneric $Binding
                $Content = New-BTContent -Visual $Visual -Actions $action
                Submit-BTNotification -Content $Content -UniqueIdentifier $UniqueIdentifier -AppId "NIAUpdater.Notification"
        }
        }else{
            $scriptblock = {
                $logoimage = New-BTImage -Source $Toastlogo -AppLogoOverride -Crop Default
                $Text1 = New-BTText -Content  "$Toasttitle"
                $Text2 = New-BTText -Content "$Toasttext"
                $Button = New-BTButton -Content "Dismiss" -Dismiss
                $action = New-BTAction -Buttons $Button
                $Binding = New-BTBinding -Children $text1, $text2 -AppLogoOverride $logoimage
                $Visual = New-BTVisual -BindingGeneric $Binding
                $Content = New-BTContent -Visual $Visual -Actions $action
                Submit-BTNotification -Content $Content -UniqueIdentifier $UniqueIdentifier -AppId "NIAUpdater.Notification"
        }
    }
    if(($currentuser = whoami) -eq 'nt authority\system'){
        $systemcontext = $true
    }else {
        $systemcontext = $false
    }
    if($systemcontext -eq $true) {
        invoke-ascurrentuser -scriptblock $scriptblock
    }else{
        Invoke-Command -scriptblock $scriptblock 
    }
}

## Progress Bar
function Set-ToastProgress {
    $ParentBar = New-BTProgressBar -Title 'ParentTitle' -Status 'ParentStatus' -Value 'ParentValue'
    function Set-Downloadbar {
    $DataBinding = @{
        'ParentTitle'  = 'Installing Nvidia Drivers'
        'ParentStatus' = 'Downloading'
        'ParentValue'  = $currentpercentage
    }
    return $DataBinding
    }
    $Id = 'SecondUpdateDemo'
    $Text = 'Driver Updater', 'Drivers are currently updating'
    $currentpercentage = 0.1
    $DataBinding = Set-Downloadbar
    New-BurntToastNotification -Text $Text -UniqueIdentifier $Id -ProgressBar $ParentBar -DataBinding $DataBinding -Snoozeanddismiss
    $currentpercentage = 0.2
    $DataBinding = Set-Downloadbar
    Update-BTNotification -UniqueIdentifier $Id -DataBinding $DataBinding -ErrorAction SilentlyContinue
    $currentpercentage = 0.8
    $DataBinding = Set-Downloadbar
    Update-BTNotification -UniqueIdentifier $Id -DataBinding $DataBinding -ErrorAction SilentlyContinue

    New-BurntToastNotification -Progressbar @(
        New-BTProgressBar -Status 'Copying files' -Indeterminate
        New-BTProgressBar -Status 'Copying files' -Value 0.2 -ValueDisplay '4/20 files complete'
        New-BTProgressBar -Title 'File Copy' -Status 'Copying files' -Value 0.2
    ) -UniqueIdentifier 'ExampleToast' -Snoozeanddismiss

    Update-BTNotification -UniqueIdentifier 'ExampleToast' -DataBinding '$DataBinding' -ErrorAction SilentlyContinue

    $DataBinding

    New-BurntToastNotification -Text 'Server Update' -ProgressBar $ProgressBar -UniqueIdentifier 'Toast001' -Snoozeanddismiss
    New-BurntToastNotification -Text 'Server Updates' -ProgressBar $ProgressBar -UniqueIdentifier 'Toast001' -Snoozeanddismiss

}