<#
.SYNOPSIS
    Registers a Packer-built VM in Hyper-V after build completion.

.DESCRIPTION
    This script is called by Packer's shell-local post-processor to register
    the exported VM in Hyper-V. Supports two modes:
    - Copy mode: Copies VM to a new location with a new ID
    - In-place mode: Registers VM directly from output directory

.PARAMETER VmName
    Name of the virtual machine

.PARAMETER OutputDir
    Packer's output directory containing the exported VM

.PARAMETER RegisterVm
    Whether to register the VM (true/false)

.PARAMETER RegisterVmCopy
    Whether to copy the VM to a new location (true) or register in-place (false)

.PARAMETER RegisterVmPath
    Destination path for the VM (only used if RegisterVmCopy is true)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$VmName,

    [Parameter(Mandatory=$true)]
    [string]$OutputDir,

    [Parameter(Mandatory=$true)]
    [string]$RegisterVm,

    [Parameter(Mandatory=$true)]
    [string]$RegisterVmCopy,

    [Parameter(Mandatory=$false)]
    [string]$RegisterVmPath = ""
)

# Convert string parameters to booleans
$doRegister = $RegisterVm -eq "true"
$doCopy = $RegisterVmCopy -eq "true"

Write-Host "========================================"
Write-Host "Hyper-V VM Registration Post-Processor"
Write-Host "========================================"
Write-Host "VM Name: $VmName"
Write-Host "Output Dir: $OutputDir"
Write-Host "Register VM: $doRegister"
Write-Host "Copy Mode: $doCopy"
Write-Host "Register Path: $RegisterVmPath"
Write-Host "========================================"

# Exit early if registration is disabled
if (-not $doRegister) {
    Write-Host "VM registration disabled, skipping..."
    exit 0
}

# Find the VM configuration file
$vmcxPattern = Join-Path $OutputDir "Virtual Machines\*.vmcx"
$vmcxFile = Get-ChildItem -Path $vmcxPattern -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $vmcxFile) {
    Write-Error "ERROR: No .vmcx file found in $OutputDir\Virtual Machines\"
    exit 1
}

Write-Host "Found VM config: $($vmcxFile.FullName)"

try {
    if ($doCopy) {
        # Copy mode: Copy VM to new location with new ID
        if ([string]::IsNullOrEmpty($RegisterVmPath)) {
            Write-Error "ERROR: register_vm_path is required when register_vm_copy=true"
            exit 1
        }

        $destPath = Join-Path $RegisterVmPath $VmName

        Write-Host "Copying and registering VM to: $destPath"

        Import-VM -Path $vmcxFile.FullName `
            -Copy `
            -GenerateNewId `
            -VirtualMachinePath $RegisterVmPath `
            -VhdDestinationPath $destPath `
            -SnapshotFilePath $destPath `
            -SmartPagingFilePath $destPath

        Write-Host "SUCCESS: VM '$VmName' registered at $RegisterVmPath"
        Write-Host "  - VHDs: $destPath"
        Write-Host "  - Snapshots: $destPath"
    }
    else {
        # In-place mode: Register VM from output directory
        Write-Host "Registering VM in-place from: $OutputDir"

        Import-VM -Path $vmcxFile.FullName

        Write-Host "SUCCESS: VM '$VmName' registered from $OutputDir"
    }

    # Show the registered VM
    $vm = Get-VM -Name $VmName -ErrorAction SilentlyContinue
    if ($vm) {
        Write-Host ""
        Write-Host "VM Details:"
        Write-Host "  - Name: $($vm.Name)"
        Write-Host "  - State: $($vm.State)"
        Write-Host "  - Generation: $($vm.Generation)"
        Write-Host "  - Memory: $($vm.MemoryStartup / 1MB) MB"
        Write-Host "  - Processors: $($vm.ProcessorCount)"
    }
}
catch {
    Write-Error "ERROR: Failed to register VM: $_"
    exit 1
}

exit 0
