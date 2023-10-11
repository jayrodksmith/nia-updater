###############################################################################
# Function - Send Info to Ninja
###############################################################################
function Set-GPUtoNinjaRMM {
    RMM-Msg "Script Mode: `tLogging details to NinjaRMM" -messagetype Verbose
    foreach ($gpu in $gpuInfo) {
        if ($gpu.IsDiscrete){
            $discreteGPUFound = $true
            Ninja-Property-Set hardwarediscretegpu $gpu.Name
            Ninja-Property-Set hardwarediscretedriverinstalled $gpu.DriverInstalled
            Ninja-Property-Set hardwarediscretedriverlatest $gpu.DriverLatest
            if($gpu.DriverUptoDate){
                Ninja-Property-Set hardwarediscretedriveruptodate "1"
            }else {
                Ninja-Property-Set hardwarediscretedriveruptodate "0"
            }
        }
        if ($gpu.IsIntegrated){
            $integratedGPUFound = $true
            Ninja-Property-Set hardwareintegratedgpu $gpu.Name
            Ninja-Property-Set hardwareintegrateddriverinstalled $gpu.DriverInstalled
            Ninja-Property-Set hardwareintegrateddriverlatest $gpu.DriverLatest
            if($gpu.DriverUptoDate){
                Ninja-Property-Set hardwareintegrateddriveruptodate "1"
            }else {
                Ninja-Property-Set hardwareintegrateddriveruptodate "0"
            }
        }

    }
if (-not $integratedGPUFound) {
Ninja-Property-Set hardwareintegratedgpu "Not Detected"
Ninja-Property-Set hardwareintegrateddriverinstalled clear
Ninja-Property-Set hardwareintegrateddriverlatest clear
Ninja-Property-Set hardwareintegrateddriveruptodate clear
}
if (-not $discreteGPUFound) {
Ninja-Property-Set hardwarediscretegpu "Not Detected"
}
}

###############################################################################
# Function - Send Info to Ninja end
###############################################################################