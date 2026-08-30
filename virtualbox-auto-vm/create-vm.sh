#!/usr/bin/env bash
set -euo pipefail

ISO_PATH=""
VM_NAME="ubuntu-lab"
MEMORY_MB=4096
CPUS=2
DISK_MB=40960
SSH_PORT=2222
VM_USER="labuser"
VM_PASSWORD="labpass"
VM_BASE_FOLDER=""

usage() {
  cat <<USAGE
Usage: $0 --iso /path/to/ubuntu.iso [options]

Options:
  --name NAME               VM name (default: ubuntu-lab)
  --memory MB               RAM in MB (default: 4096)
  --cpus N                  vCPUs (default: 2)
  --disk MB                 disk size in MB (default: 40960)
  --ssh-port PORT           host SSH port (default: 2222)
  --user USER               VM user (default: labuser)
  --password PASSWORD       VM password (default: labpass)
  --base-folder PATH        VM base folder; omit for VirtualBox default
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso) ISO_PATH="$2"; shift 2 ;;
    --name) VM_NAME="$2"; shift 2 ;;
    --memory) MEMORY_MB="$2"; shift 2 ;;
    --cpus) CPUS="$2"; shift 2 ;;
    --disk) DISK_MB="$2"; shift 2 ;;
    --ssh-port) SSH_PORT="$2"; shift 2 ;;
    --user) VM_USER="$2"; shift 2 ;;
    --password) VM_PASSWORD="$2"; shift 2 ;;
    --base-folder) VM_BASE_FOLDER="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

[[ -n "$ISO_PATH" ]] || { usage; exit 1; }
command -v VBoxManage >/dev/null || { echo "VBoxManage not found"; exit 1; }
ISO_PATH="$(cd "$(dirname "$ISO_PATH")" && pwd)/$(basename "$ISO_PATH")"

create_args=(createvm --name "$VM_NAME" --ostype Ubuntu_64 --register)
if [[ -n "$VM_BASE_FOLDER" ]]; then
  mkdir -p "$VM_BASE_FOLDER"
  create_args+=(--basefolder "$VM_BASE_FOLDER")
fi
VBoxManage "${create_args[@]}"

CFG_FILE=$(VBoxManage showvminfo "$VM_NAME" --machinereadable | sed -n 's/^CfgFile="\(.*\)"$/\1/p' | head -1)
VM_FOLDER=$(dirname "$CFG_FILE")
DISK_PATH="$VM_FOLDER/$VM_NAME.vdi"

VBoxManage modifyvm "$VM_NAME" --memory "$MEMORY_MB" --cpus "$CPUS" --ioapic on --boot1 dvd --boot2 disk --boot3 none --boot4 none --nic1 nat
VBoxManage modifyvm "$VM_NAME" --natpf1 "ssh,tcp,127.0.0.1,$SSH_PORT,,22"
VBoxManage createmedium disk --filename "$DISK_PATH" --size "$DISK_MB" --format VDI
VBoxManage storagectl "$VM_NAME" --name "SATA Controller" --add sata --controller IntelAhci
VBoxManage storageattach "$VM_NAME" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "$DISK_PATH"
VBoxManage storagectl "$VM_NAME" --name "IDE Controller" --add ide
VBoxManage storageattach "$VM_NAME" --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium "$ISO_PATH"

POST_INSTALL='apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server curl git vim && systemctl enable --now ssh'
VBoxManage unattended install "$VM_NAME" \
  --iso="$ISO_PATH" \
  --user="$VM_USER" \
  --user-password="$VM_PASSWORD" \
  --full-user-name="$VM_USER" \
  --hostname="$VM_NAME.local" \
  --install-additions \
  --post-install-command="$POST_INSTALL" \
  --start-vm=headless

echo "VM folder: $VM_FOLDER"
echo "SSH after install: ssh -p $SSH_PORT $VM_USER@127.0.0.1"
