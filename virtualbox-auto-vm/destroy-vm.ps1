param(
    [string]$VmName = "ubuntu-lab"
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command VBoxManage -ErrorAction SilentlyContinue)) {
    throw "VBoxManage was not found in PATH."
}

$running = & VBoxManage list runningvms 2>$null
if ($running -match ('"' + [regex]::Escape($VmName) + '"')) {
    Write-Host "Powering off $VmName..."
    & VBoxManage controlvm $VmName poweroff
}

Write-Host "Deleting $VmName and its attached storage..."
& VBoxManage unregistervm $VmName --delete
if ($LASTEXITCODE -ne 0) {
    throw "Could not delete VM '$VmName'."
}
