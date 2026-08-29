param(
    [Parameter(Mandatory=$true)]
    [string]$IsoPath,

    [string]$VmName = "ubuntu-lab",
    [int]$MemoryMB = 4096,
    [int]$Cpus = 2,
    [int]$DiskMB = 40960,
    [int]$SshPort = 2222,
    [string]$VmUser = "labuser",
    [string]$Hostname = "ubuntu-lab.local"
)

$ErrorActionPreference = "Stop"

function Find-VBoxManage {
    $cmd = Get-Command VBoxManage.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $common = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
    if (Test-Path $common) { return $common }

    throw "VBoxManage.exe not found. Install Oracle VirtualBox first."
}

if (-not (Test-Path $IsoPath)) {
    throw "ISO file not found: $IsoPath"
}

$VBox = Find-VBoxManage

& $VBox showvminfo $VmName *> $null
if ($LASTEXITCODE -eq 0) {
    throw "VM '$VmName' already exists."
}

$SecurePassword = Read-Host "Password for VM user '$VmUser'" -AsSecureString
$Ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
try {
    $VmPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($Ptr)
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($Ptr)
}

if ([string]::IsNullOrWhiteSpace($VmPassword)) {
    throw "Password cannot be empty."
}

Write-Host "==> Creating VM: $VmName"
& $VBox createvm --name $VmName --ostype "Ubuntu_64" --register

Write-Host "==> Configuring CPU, RAM, network, boot"
& $VBox modifyvm $VmName `
    --memory $MemoryMB `
    --cpus $Cpus `
    --ioapic on `
    --boot1 dvd `
    --boot2 disk `
    --boot3 none `
    --boot4 none `
    --nic1 nat `
    --cableconnected1 on `
    --audio-enabled off `
    --usb off

Write-Host "==> Adding SSH port forwarding"
& $VBox modifyvm $VmName `
    --natpf1 "ssh,tcp,127.0.0.1,$SshPort,,22"

$SystemProps = & $VBox list systemproperties
$DefaultFolderLine = $SystemProps | Where-Object { $_ -match "^Default machine folder:" }
$DefaultFolder = ($DefaultFolderLine -replace "^Default machine folder:\s*", "").Trim()
if (-not $DefaultFolder) {
    $DefaultFolder = Join-Path $env:USERPROFILE "VirtualBox VMs"
}

$VmDir = Join-Path $DefaultFolder $VmName
$Vdi = Join-Path $VmDir "$VmName.vdi"
New-Item -ItemType Directory -Force -Path $VmDir | Out-Null

Write-Host "==> Creating virtual disk"
& $VBox createmedium disk `
    --filename $Vdi `
    --size $DiskMB `
    --format VDI

Write-Host "==> Creating storage controller"
& $VBox storagectl $VmName `
    --name "SATA Controller" `
    --add sata `
    --controller IntelAHCI

& $VBox storageattach $VmName `
    --storagectl "SATA Controller" `
    --port 0 `
    --device 0 `
    --type hdd `
    --medium $Vdi

Write-Host "==> Preparing unattended Ubuntu installation"
$PostInstall = "/bin/sh -c 'apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server curl git vim htop jq && systemctl enable --now ssh'"

& $VBox unattended install $VmName `
    --iso=$IsoPath `
    --user=$VmUser `
    --full-user-name=$VmUser `
    --user-password=$VmPassword `
    --hostname=$Hostname `
    --locale=en_US `
    --country=US `
    --time-zone=America/Los_Angeles `
    --install-additions `
    --post-install-command=$PostInstall

# Remove plaintext variable as soon as VBoxManage has consumed it.
$VmPassword = $null

Write-Host "==> Starting VM headless"
& $VBox startvm $VmName --type headless

Write-Host ""
Write-Host "VM creation started successfully."
Write-Host "VM name:      $VmName"
Write-Host "CPU:          $Cpus"
Write-Host "RAM:          $MemoryMB MB"
Write-Host "Disk:         $DiskMB MB"
Write-Host "Guest user:   $VmUser"
Write-Host "SSH:          localhost:$SshPort -> VM:22"
Write-Host ""
Write-Host "After Ubuntu installation finishes:"
Write-Host "ssh -p $SshPort $VmUser@127.0.0.1"
