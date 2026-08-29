param(
    [string]$VmName = "ubuntu-lab"
)

$ErrorActionPreference = "Stop"
$VBox = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
if (-not (Test-Path $VBox)) {
    $VBox = (Get-Command VBoxManage.exe -ErrorAction Stop).Source
}

& $VBox showvminfo $VmName *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "VM '$VmName' does not exist."
    exit 0
}

$Info = & $VBox showvminfo $VmName --machinereadable
$StateLine = $Info | Where-Object { $_ -match '^VMState=' }
$State = ($StateLine -replace '^VMState="', '' -replace '"$', '')

if ($State -eq "running" -or $State -eq "paused") {
    & $VBox controlvm $VmName poweroff
}

& $VBox unregistervm $VmName --delete
Write-Host "Deleted VM: $VmName"
