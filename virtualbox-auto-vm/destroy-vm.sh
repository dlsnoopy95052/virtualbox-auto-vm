#!/usr/bin/env bash
set -euo pipefail
VM_NAME="${1:-ubuntu-lab}"

if ! command -v VBoxManage >/dev/null 2>&1; then
  echo "ERROR: VBoxManage not found."
  exit 1
fi

if ! VBoxManage showvminfo "$VM_NAME" >/dev/null 2>&1; then
  echo "VM '$VM_NAME' does not exist."
  exit 0
fi

STATE="$(VBoxManage showvminfo "$VM_NAME" --machinereadable | awk -F= '$1=="VMState" {gsub(/"/,"",$2); print $2}')"
if [[ "$STATE" == "running" || "$STATE" == "paused" ]]; then
  VBoxManage controlvm "$VM_NAME" poweroff
fi

VBoxManage unregistervm "$VM_NAME" --delete
echo "Deleted VM: $VM_NAME"
