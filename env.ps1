# Project environment for the BYOC lab (Windows PowerShell 5.1 or PowerShell 7).
#
# Usage, from the repository root. Dot-source it (note the leading ". "):
#     Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#     . .\env.ps1
#
# It activates the project's Python 3.11 venv, selects Java 17 for this
# terminal only, and points PySpark at the venv's Python. It changes nothing
# globally: open a new terminal and you are back to your normal defaults.

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Dot-source this script so the settings stay in your terminal:  . .\env.ps1" -ForegroundColor Yellow
    return
}

$ByocRoot = $PSScriptRoot
$ByocVenv = Join-Path $ByocRoot 'patient-xml-transform\.venv'
$Activate = Join-Path $ByocVenv 'Scripts\Activate.ps1'

if (-not (Test-Path $Activate)) {
    Write-Host "No venv at $ByocVenv" -ForegroundColor Red
    Write-Host "Create it first (docs/01-setup.md, Step 5):"
    Write-Host "    cd patient-xml-transform; uv venv --python 3.11 --seed .venv"
    return
}

. $Activate

$ZuluRoot = 'C:\Program Files\Zulu'
$Jdk = $null
if (Test-Path $ZuluRoot) {
    $Jdk = Get-ChildItem $ZuluRoot -Directory |
        Where-Object Name -like 'zulu-17*' |
        Sort-Object Name -Descending |
        Select-Object -First 1
}
if ($Jdk) {
    $env:JAVA_HOME = $Jdk.FullName
    $env:Path = "$env:JAVA_HOME\bin;$env:Path"
} else {
    Write-Host "WARNING: Java 17 not found under $ZuluRoot. Install it with: winget install -e --id Azul.Zulu.17.JDK" -ForegroundColor Yellow
}

$env:PYSPARK_PYTHON = Join-Path $ByocVenv 'Scripts\python.exe'

Write-Host ("Python : " + (python --version 2>&1))
Write-Host ("Java   : " + ((java -version 2>&1 | Select-Object -First 1) -as [string]))
Write-Host "Ready. Next: cd patient-xml-transform"
