param(
    [Parameter(Mandatory = $true)]
    [string]$IsoPath,

    [string]$VmName = "ubuntu-lab",
    [int]$MemoryMB = 4096,
    [int]$Cpus = 2,
    [int]$DiskMB = 40960,
    [int]$SshPort = 2222,
    [string]$VmUser = "labuser",
    [string]$VmPassword = "labpass",

    # Optional. Example: D:\VirtualBox VMs
    # Leave empty to use VirtualBox's Default Machine Folder.
    [string]$VmBaseFolder = ""
)

$ErrorActionPreference = "Stop"

function Run-VBoxManage {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
    & VBoxManage @Args
    if ($LASTEXITCODE -ne 0) {
        throw "VBoxManage failed: VBoxManage $($Args -join ' ')"
    }
}

if (-not (Get-Command VBoxManage -ErrorAction SilentlyContinue)) {
    throw "VBoxManage was not found in PATH. Install VirtualBox or add its installation directory to PATH."
}

$IsoPath = (Resolve-Path $IsoPath).Path

if ($VmBaseFolder) {
    $VmBaseFolder = [Environment]::ExpandEnvironmentVariables($VmBaseFolder)
    $VmBaseFolder = [System.IO.Path]::GetFullPath($VmBaseFolder)
    if (-not (Test-Path $VmBaseFolder)) {
        New-Item -ItemType Directory -Path $VmBaseFolder -Force | Out-Null
    }
}

# Stop if a VM with the same name already exists.
$existing = & VBoxManage list vms 2>$null
if ($existing -match ('"' + [regex]::Escape($VmName) + '"')) {
    throw "A VirtualBox VM named '$VmName' already exists. Choose a different -VmName or remove the existing VM first."
}

Write-Host "Creating VM: $VmName"
if ($VmBaseFolder) {
    Write-Host "VM base folder: $VmBaseFolder"
} else {
    Write-Host "VM base folder: VirtualBox default"
}

# Create and register the VM. --basefolder controls where the VM directory is created.
$createArgs = @("createvm", "--name", $VmName, "--ostype", "Ubuntu_64", "--register")
if ($VmBaseFolder) {
    $createArgs += @("--basefolder", $VmBaseFolder)
}
Run-VBoxManage @createArgs

# Ask VirtualBox for the actual configuration location. This works whether a custom
# base folder was supplied or the VirtualBox default was used.
$vmInfo = & VBoxManage showvminfo $VmName --machinereadable
$cfgLine = $vmInfo | Where-Object { $_ -match '^CfgFile=' } | Select-Object -First 1
if (-not $cfgLine) {
    throw "Could not determine the VM configuration folder."
}
$cfgFile = ($cfgLine -replace '^CfgFile="?', '') -replace '"$', ''
$vmFolder = Split-Path -Parent $cfgFile
$diskPath = Join-Path $vmFolder "$VmName.vdi"

Write-Host "Actual VM folder: $vmFolder"
Write-Host "Virtual disk: $diskPath"

# Basic hardware.
Run-VBoxManage modifyvm $VmName `
    --memory $MemoryMB `
    --cpus $Cpus `
    --ioapic on `
    --boot1 dvd `
    --boot2 disk `
    --boot3 none `
    --boot4 none `
    --nic1 nat

# NAT SSH forwarding: localhost:<SshPort> -> guest:22
Run-VBoxManage modifyvm $VmName --natpf1 "ssh,tcp,127.0.0.1,$SshPort,,22"

# Create and attach disk.
Run-VBoxManage createmedium disk --filename $diskPath --size $DiskMB --format VDI
Run-VBoxManage storagectl $VmName --name "SATA Controller" --add sata --controller IntelAhci
Run-VBoxManage storageattach $VmName --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium $diskPath

# Add DVD controller and ISO.
Run-VBoxManage storagectl $VmName --name "IDE Controller" --add ide
Run-VBoxManage storageattach $VmName --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium $IsoPath

# Configure unattended Ubuntu install and start the VM.
# Guest Additions are requested when supported by the selected Ubuntu ISO.
$postInstall = "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server curl git vim && systemctl enable --now ssh"

Write-Host "Starting unattended Ubuntu installation..."
Run-VBoxManage unattended install $VmName `
    --iso=$IsoPath `
    --user=$VmUser `
    --user-password=$VmPassword `
    --full-user-name=$VmUser `
    --hostname="$VmName.local" `
    --install-additions `
    --post-install-command=$postInstall `
    --start-vm=headless

Write-Host ""
Write-Host "VM creation started successfully."
Write-Host "Name       : $VmName"
Write-Host "Location   : $vmFolder"
Write-Host "Disk       : $diskPath"
Write-Host "RAM        : $MemoryMB MB"
Write-Host "CPUs       : $Cpus"
Write-Host "SSH        : ssh -p $SshPort $VmUser@127.0.0.1"
Write-Host "User       : $VmUser"
Write-Host ""
Write-Host "Note: SSH becomes available after Ubuntu finishes installing."
