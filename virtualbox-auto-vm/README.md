# VirtualBox Automatic Ubuntu VM Builder

This project creates and installs an Ubuntu Server VM automatically with Oracle VirtualBox `VBoxManage`.

## What it configures

- Ubuntu 64-bit VM
- 2 vCPUs by default
- 4 GB RAM by default
- 40 GB dynamically allocated VDI disk
- NAT networking
- SSH port forwarding from host `127.0.0.1:2222` to guest port `22`
- VirtualBox unattended OS installation
- Guest Additions
- Post-install packages:
  - openssh-server
  - curl
  - git
  - vim
  - htop
  - jq

The VM runs headless after creation.

## Requirements

1. Oracle VirtualBox installed.
2. `VBoxManage` available.
3. An Ubuntu Server ISO already downloaded.

Verify VirtualBox:

### Windows

```powershell
& "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" --version
```

### Linux / macOS

```bash
VBoxManage --version
```

## Linux/macOS

Make the script executable:

```bash
chmod +x create-vm.sh destroy-vm.sh
```

Create a VM:

```bash
./create-vm.sh ~/Downloads/ubuntu-server.iso
```

Custom VM name:

```bash
./create-vm.sh ~/Downloads/ubuntu-server.iso sre-lab01
```

Custom sizing:

```bash
VM_MEMORY=8192 \
VM_CPUS=4 \
VM_DISK_MB=81920 \
VM_SSH_PORT=2223 \
VM_USER=daywen \
./create-vm.sh ~/Downloads/ubuntu-server.iso sre-lab01
```

The script securely prompts for the guest password.

## Windows PowerShell

Allow the script for the current PowerShell process if needed:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

Run:

```powershell
.\create-vm.ps1 -IsoPath "C:\ISO\ubuntu-server.iso"
```

Custom VM:

```powershell
.\create-vm.ps1 `
  -IsoPath "C:\ISO\ubuntu-server.iso" `
  -VmName "sre-lab01" `
  -MemoryMB 8192 `
  -Cpus 4 `
  -DiskMB 81920 `
  -SshPort 2223 `
  -VmUser "sysadmin"
```

## SSH into the VM

Default:

```bash
ssh -p 2222 labuser@127.0.0.1
```

For a custom SSH port/user, use the values you specified.

## Check VM status

```bash
VBoxManage showvminfo ubuntu-lab
```

List VMs:

```bash
VBoxManage list vms
```

List running VMs:

```bash
VBoxManage list runningvms
```

## Stop the VM

Graceful ACPI shutdown:

```bash
VBoxManage controlvm ubuntu-lab acpipowerbutton
```

Force power off:

```bash
VBoxManage controlvm ubuntu-lab poweroff
```

## Start it again

```bash
VBoxManage startvm ubuntu-lab --type headless
```

## Delete the lab

Linux/macOS:

```bash
./destroy-vm.sh ubuntu-lab
```

Windows:

```powershell
.\destroy-vm.ps1 -VmName ubuntu-lab
```

## Notes

- `VBoxManage unattended install` support depends on the exact guest ISO. If an ISO is not recognized, test it with:

```bash
VBoxManage unattended detect --iso=/path/to/ubuntu-server.iso
```

- NAT keeps the VM isolated from the LAN by default.
- SSH is exposed only on the host loopback interface (`127.0.0.1`) by default.
- To create many VMs, use different VM names and SSH host ports.
