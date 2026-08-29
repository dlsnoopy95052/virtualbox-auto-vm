#!/usr/bin/env bash
set -euo pipefail

# VirtualBox automatic Ubuntu VM builder
# Usage:
#   ./create-vm.sh /path/to/ubuntu-server.iso [vm_name]
#
# Optional environment variables:
#   VM_MEMORY=4096
#   VM_CPUS=2
#   VM_DISK_MB=40960
#   VM_SSH_PORT=2222
#   VM_USER=labuser
#   VM_HOSTNAME=ubuntu-lab.local

ISO="${1:-}"
VM_NAME="${2:-ubuntu-lab}"

VM_MEMORY="${VM_MEMORY:-4096}"
VM_CPUS="${VM_CPUS:-2}"
VM_DISK_MB="${VM_DISK_MB:-40960}"
VM_SSH_PORT="${VM_SSH_PORT:-2222}"
VM_USER="${VM_USER:-labuser}"
VM_HOSTNAME="${VM_HOSTNAME:-ubuntu-lab.local}"

if [[ -z "$ISO" ]]; then
  echo "Usage: $0 /path/to/ubuntu-server.iso [vm_name]"
  exit 1
fi

if [[ ! -f "$ISO" ]]; then
  echo "ERROR: ISO not found: $ISO"
  exit 1
fi

if ! command -v VBoxManage >/dev/null 2>&1; then
  echo "ERROR: VBoxManage not found. Install Oracle VirtualBox and ensure VBoxManage is in PATH."
  exit 1
fi

if VBoxManage showvminfo "$VM_NAME" >/dev/null 2>&1; then
  echo "ERROR: VM '$VM_NAME' already exists."
  exit 1
fi

read -r -s -p "Password for VM user '$VM_USER': " VM_PASSWORD
echo
if [[ -z "$VM_PASSWORD" ]]; then
  echo "ERROR: Password cannot be empty."
  exit 1
fi

VM_BASE="$(VBoxManage list systemproperties | awk -F': +' '/Default machine folder/ {print $2; exit}')"
if [[ -z "$VM_BASE" ]]; then
  VM_BASE="$HOME/VirtualBox VMs"
fi

VM_DIR="$VM_BASE/$VM_NAME"
VDI="$VM_DIR/$VM_NAME.vdi"

echo "==> Creating VM: $VM_NAME"
VBoxManage createvm \
  --name "$VM_NAME" \
  --ostype "Ubuntu_64" \
  --register

echo "==> Configuring CPU, RAM, network, boot"
VBoxManage modifyvm "$VM_NAME" \
  --memory "$VM_MEMORY" \
  --cpus "$VM_CPUS" \
  --ioapic on \
  --boot1 dvd \
  --boot2 disk \
  --boot3 none \
  --boot4 none \
  --nic1 nat \
  --cableconnected1 on \
  --audio-enabled off \
  --usb off

echo "==> Adding SSH port forwarding: localhost:${VM_SSH_PORT} -> guest:22"
VBoxManage modifyvm "$VM_NAME" \
  --natpf1 "ssh,tcp,127.0.0.1,${VM_SSH_PORT},,22"

echo "==> Creating ${VM_DISK_MB} MB virtual disk"
mkdir -p "$VM_DIR"
VBoxManage createmedium disk \
  --filename "$VDI" \
  --size "$VM_DISK_MB" \
  --format VDI

echo "==> Creating storage controller"
VBoxManage storagectl "$VM_NAME" \
  --name "SATA Controller" \
  --add sata \
  --controller IntelAHCI

VBoxManage storageattach "$VM_NAME" \
  --storagectl "SATA Controller" \
  --port 0 \
  --device 0 \
  --type hdd \
  --medium "$VDI"

echo "==> Preparing unattended Ubuntu installation"
VBoxManage unattended install "$VM_NAME" \
  --iso="$ISO" \
  --user="$VM_USER" \
  --full-user-name="$VM_USER" \
  --user-password="$VM_PASSWORD" \
  --hostname="$VM_HOSTNAME" \
  --locale=en_US \
  --country=US \
  --time-zone=America/Los_Angeles \
  --install-additions \
  --post-install-command="/bin/sh -c 'apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server curl git vim htop jq && systemctl enable --now ssh'"

echo "==> Starting VM headless"
VBoxManage startvm "$VM_NAME" --type headless

cat <<EOF

VM creation started successfully.

VM name:       $VM_NAME
CPU:           $VM_CPUS
RAM:           ${VM_MEMORY} MB
Disk:          ${VM_DISK_MB} MB
Guest user:    $VM_USER
SSH mapping:   localhost:${VM_SSH_PORT} -> VM:22

After Ubuntu installation finishes, connect with:

    ssh -p ${VM_SSH_PORT} ${VM_USER}@127.0.0.1

Useful commands:
    VBoxManage showvminfo "$VM_NAME"
    VBoxManage controlvm "$VM_NAME" acpipowerbutton
    VBoxManage startvm "$VM_NAME" --type headless

EOF
