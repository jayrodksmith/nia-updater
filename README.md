# nia-updater (Nvidia Intel Amd Updater)
Checks for a current and new versions of the NVIDIA Intel and AMD gpu drivers

Stores values into an array for use to import into RMM

Nvida drivers use studio drivers (not game drivers)

# External Modules and Programs Used
[BurntToast](https://github.com/Windos/BurntToast)

[RunAsUser](https://github.com/KelvinTegelaar/RunAsUser)

[7zip](https://www.7-zip.org/download.html)

# Current Bugs
AMD
    
    Driver Check        Some minor timeout issues to amd website checking version          
    Driver Install      None reported

Nvidia
    
    Driver Check        None reported
    Driver Install      None reported

Intel
    
    Driver Check        Certain generations are not checked properly
    Driver Install      Not fully tested

# Future Features
Nvidia
    
    Select between studio and game drivers

AMD

    Make driver check more reliable

Intel

    Resolve issues with generation checks

Other

    More notifications for steps applied
    Cleanup invoke script to be more generic to allow updates without modify invoke

# Requirements
Script has been designed to run as "System Context"

Can be run as Administrator however advised to run as system context

NinjaRMM Script Variable Requirements
            
            updateNvidiaDrivers                 (Script Variable Checkbox)
            updateamdDrivers                    (Script Variable Checkbox)
            updateintelDrivers                  (Script Variable Checkbox)
            restartAfterUpdating                (Script Variable Checkbox)(Default unticked)
            notfications                        (Script Variable Checkbox)
            autoupdate                          (Script Variable Checkbox)

NinjaRMM Custom Field Requirements inlcuding permissions
            
            Permissions for all fields
                Technician                      Read Only
                Automations                     Read Write
                API                             Read Only

            hardwarediscretegpu                 (text)
            hardwarediscretedriverinstalled     (text)
            hardwarediscretedriverlatest        (text)
            hardwarediscretedriveruptodate      (checkbox)
        
            hardwareintegratedgpu               (text)
            hardwareintegrateddriverinstalled   (text)
            hardwareintegrateddriverlatest      (text)
            hardwareintegrateddriveruptodate    (checkbox)         

# Examples
```powershell
.\Invoke-niaupdater.ps1
```

Run as system context using RMM

Copy paste all code in invoke script directly into RMM script with relevaly script variables

# Function Descriptions
    Functions.Nvidia.ps1
    All nvidia related functions

    Functions.Amd.ps1
    All amd related functions

    Functions.Intel.ps1
    All Intel related functions

    Functions.GPUInfo.ps1
    All code to retrieve infomation on GPUs

    Functions.Notifications.ps1
    All code related to Toast notifications

    Functions.NinjaOne.ps1
    All code related to ninjaon integration

    Functions.Logging.ps1
    All code related to custom logging

    Functions.Helpers.ps1
    All other code