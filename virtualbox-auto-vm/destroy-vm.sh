#!/usr/bin/env bash
set -euo pipefail
VM_NAME="${1:-ubuntu-lab}"
if VBoxManage list runningvms | grep -Fq "\"$VM_NAME\""; then
  VBoxManage controlvm "$VM_NAME" poweroff
fi
VBoxManage unregistervm "$VM_NAME" --delete
