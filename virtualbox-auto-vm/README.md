# VirtualBox Auto VM

Creates an Ubuntu VirtualBox VM from the command line, including CPU/RAM/disk setup, NAT networking, SSH port forwarding, and an unattended Ubuntu installation.

## New: choose where the VM is stored

### Windows PowerShell

Use `-VmBaseFolder` to choose the parent folder:

```powershell
.\create-vm.ps1 `
  -IsoPath "C:\ISO\ubuntu-24.04-server-amd64.iso" `
  -VmBaseFolder "D:\VirtualBox VMs"
```

This creates the VM under approximately:

```text
D:\VirtualBox VMs\ubuntu-lab\
```

If you omit `-VmBaseFolder`, VirtualBox uses its configured **Default Machine Folder**.

```powershell
.\create-vm.ps1 -IsoPath "C:\ISO\ubuntu-24.04-server-amd64.iso"
```

### More Windows examples

Custom name and storage location:

```powershell
.\create-vm.ps1 `
  -IsoPath "C:\ISO\ubuntu-24.04-server-amd64.iso" `
  -VmName "sre-lab-01" `
  -VmBaseFolder "E:\VMs"
```

Custom CPU/RAM/disk:

```powershell
.\create-vm.ps1 `
  -IsoPath "C:\ISO\ubuntu-24.04-server-amd64.iso" `
  -VmName "sre-lab-01" `
  -VmBaseFolder "D:\VirtualBox VMs" `
  -MemoryMB 8192 `
  -Cpus 4 `
  -DiskMB 61440
```

## Windows parameters

| Parameter | Default | Purpose |
|---|---:|---|
| `-IsoPath` | required | Ubuntu ISO |
| `-VmName` | `ubuntu-lab` | VM name |
| `-MemoryMB` | `4096` | RAM |
| `-Cpus` | `2` | vCPU count |
| `-DiskMB` | `40960` | VDI size |
| `-SshPort` | `2222` | Host port forwarded to guest SSH 22 |
| `-VmUser` | `labuser` | Ubuntu username |
| `-VmPassword` | `labpass` | Ubuntu password |
| `-VmBaseFolder` | empty | Parent folder for VM; empty uses VirtualBox default |

## Linux/macOS

```bash
./create-vm.sh \
  --iso ~/Downloads/ubuntu-24.04-server-amd64.iso \
  --base-folder /data/VirtualBoxVMs
```

Omit `--base-folder` to use the VirtualBox default.

## Delete the VM

Windows:

```powershell
.\destroy-vm.ps1 -VmName "ubuntu-lab"
```

Linux/macOS:

```bash
./destroy-vm.sh ubuntu-lab
```

> The destroy scripts delete the VM and its attached virtual disks. Use carefully.
