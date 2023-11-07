Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
Install-Module BurntToast
Import-Module BurntToast
Install-module -Name RunAsUser
Import-module -Name RunAsUser

$logonvidia = "C:\ProgramData\niaupdater\resources\logos\logo_nvidia_square.jpg"

New-BurntToastNotification -Text "Nvidia Drivers Updated"
New-BurntToastNotification -Text "Nvidia Drivers Updated" -AppLogo $logonvidia -UniqueIdentifier '001'

$Header = New-BTHeader -Title 'Restart Computer'
$Button = New-BTButton -Content "Reboot now" -Arguments "ToastReboot:" -ActivationType Protocol
$Button3 = New-BTButton -Content "Dismiss" -Dismiss
New-BurntToastNotification -Text "Nvidia Drivers Updated" -AppLogo "C:\\SuperLogo.png" -UniqueIdentifier '001' -Header $Header -Buttons $Button, $Button3
New-BurntToastNotification -Text "Nvidia Drivers Updated" -SnoozeAndDismiss




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
invoke-ascurrentuser -scriptblock {

    $heroimage = New-BTImage -Source "C:\ProgramData\niaupdater\resources\logos\logo_nvidia_square.jpg" -HeroImage
    $Text1 = New-BTText -Content  "Updates"
    $Text2 = New-BTText -Content "Nvidia drivers updated. Please select if you'd like to reboot now, or snooze this message."
    $Button = New-BTButton -Content "Snooze" -Snooze -id 'SnoozeTime'
    $Button2 = New-BTButton -Content "Reboot now" -Arguments "ToastReboot:" -ActivationType Protocol
    $Button3 = New-BTButton -Content "Dismiss" -Dismiss
    $10Min = New-BTSelectionBoxItem -Id 10 -Content '10 minutes'
    $1Hour = New-BTSelectionBoxItem -Id 60 -Content '1 hour'
    $1Day = New-BTSelectionBoxItem -Id 1440 -Content '1 day'
    $Items = $10Min, $1Hour, $1Day
    $SelectionBox = New-BTInput -Id 'SnoozeTime' -DefaultSelectionBoxItemId 10 -Items $Items
    $action = New-BTAction -Buttons $Button, $Button2, $Button3 -inputs $SelectionBox
    $Binding = New-BTBinding -Children $text1, $text2 -HeroImage $heroimage
    $Visual = New-BTVisual -BindingGeneric $Binding
    $Content = New-BTContent -Visual $Visual -Actions $action
    Submit-BTNotification -Content $Content

}
## Progress Bar

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

New-BurntToastNotification -Text 'Server Update' -ProgressBar $ProgressBar -UniqueIdentifier 'Toast001'
New-BurntToastNotification -Text 'Server Updates' -ProgressBar $ProgressBar -UniqueIdentifier 'Toast001'
