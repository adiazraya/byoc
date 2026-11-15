# Preflight check for the BYOC lab (Windows PowerShell 5.1 or PowerShell 7).
#
# Usage, from the repository root, after `. .\env.ps1`:
#     .\verify.ps1                       # checks the org alias byoc-org
#     .\verify.ps1 -OrgAlias my-alias    # checks a different alias
#
# Read-only: it changes nothing on your machine or in your org.

param([string]$OrgAlias = 'byoc-org')

$MinSf = [version]'2.130.9'
$MinPlugin = [version]'0.1.5'
$script:Fails = 0

function Pass([string]$Msg) { Write-Host "  [PASS] $Msg" -ForegroundColor Green }
function Fail([string]$Msg, [string]$Fix) {
    Write-Host "  [FAIL] $Msg" -ForegroundColor Red
    Write-Host "         -> $Fix"
    $script:Fails++
}
function Strip-Ansi([string]$Text) { $Text -replace "$([char]27)\[[0-9;]*m", '' }

Write-Host "BYOC lab preflight (org alias: $OrgAlias)`n"

# 1. Salesforce CLI
if (Get-Command sf -ErrorAction SilentlyContinue) {
    $sfOut = Strip-Ansi ((sf --version 2>$null) -join ' ')
    if ($sfOut -match '@salesforce/cli/(\d+\.\d+\.\d+)') {
        $sfVer = [version]$Matches[1]
        if ($sfVer -ge $MinSf) { Pass "Salesforce CLI $sfVer (>= $MinSf)" }
        else { Fail "Salesforce CLI $sfVer (need >= $MinSf)" 'Run: sf update   (docs/01-setup.md, Step 1)' }
    } else { Fail 'Could not read the Salesforce CLI version' 'Run: sf --version' }
} else {
    Fail 'Salesforce CLI not found' 'Install it, then open a new terminal (docs/01-setup.md, Step 1)'
}

# 2. Code Extension plugin
$pluginLine = (Strip-Ansi ((sf plugins 2>$null) -join "`n")) -split "`n" |
    Where-Object { $_ -match '^data-code-extension\s+(\d+\.\d+\.\d+)' } | Select-Object -First 1
if ($pluginLine -and ($pluginLine -match '^data-code-extension\s+(\d+\.\d+\.\d+)')) {
    $pv = [version]$Matches[1]
    if ($pv -ge $MinPlugin) { Pass "Code Extension plugin $pv (>= $MinPlugin)" }
    else { Fail "Code Extension plugin $pv (need >= $MinPlugin)" 'Run: sf plugins install @salesforce/plugin-data-code-extension' }
} else {
    Fail 'Code Extension plugin not installed' 'Run: sf plugins install @salesforce/plugin-data-code-extension   (docs/01-setup.md, Step 3)'
}

# 3. Python 3.11 active. The plugin tries python3 first, then python, so check both.
foreach ($cmd in 'python3', 'python') {
    $exe = Get-Command $cmd -ErrorAction SilentlyContinue
    if (-not $exe) { Fail "$cmd not found" 'Run: . .\env.ps1   (docs/01-setup.md, Part B)'; continue }
    $out = (& $cmd --version 2>&1) -join ' '
    if ($out -match 'Python 3\.11\.\d+') { Pass "$cmd is $($Matches[0]) ($($exe.Source))" }
    else { Fail "$cmd reports '$out' (need exactly 3.11)" 'Run: . .\env.ps1 ; also disable the python/python3 App execution aliases (docs/01-setup.md, Step 5)' }
}

# 4. A virtual environment is active
if ($env:VIRTUAL_ENV) { Pass "venv active: $env:VIRTUAL_ENV" }
else { Fail 'No venv active' 'Run: . .\env.ps1' }

# 5. pip inside the venv
python -m pip --version *> $null
if ($LASTEXITCODE -eq 0) { Pass 'pip available in the active Python' }
else { Fail 'pip missing from the active Python' 'Run: uv pip install pip   (or recreate the venv with --seed)' }

# 6. SDK installed
$sdk = (python -m pip show salesforce-data-customcode 2>$null) | Where-Object { $_ -like 'Version:*' }
if ($sdk) { Pass ("salesforce-data-customcode " + ($sdk -replace 'Version:\s*', '') + ' installed') }
else { Fail 'salesforce-data-customcode not installed in the active Python' 'Run: uv pip install salesforce-data-customcode   (docs/01-setup.md, Step 6)' }

# 6b. pipreqs (scan calls it to detect imports for requirements.txt)
if (Get-Command pipreqs -ErrorAction SilentlyContinue) { Pass "pipreqs available (needed by 'script scan')" }
else { Fail 'pipreqs not found' "Run: uv pip install pipreqs   (or use 'script scan --no-requirements')" }

# 7. Java 17 on JAVA_HOME
$javaExe = if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME 'bin\java.exe' } else { $null }
if ($javaExe -and (Test-Path $javaExe)) {
    $jv = ((& $javaExe -version 2>&1) | Select-Object -First 1) -as [string]
    if ($jv -match '"17[.\d_]*"') { Pass "JAVA_HOME is Java 17 ($env:JAVA_HOME)" }
    else { Fail "JAVA_HOME points to '$jv' (need 17)" 'Run: . .\env.ps1   (docs/01-setup.md, Step 7)' }
} else {
    Fail 'JAVA_HOME not set or not a JDK' 'Run: . .\env.ps1   (docs/01-setup.md, Step 7 and Part B)'
}

# 8. Org alias authorized and connected
$orgJson = (sf org display --target-org $OrgAlias --json 2>$null) -join "`n"
try { $org = $orgJson | ConvertFrom-Json } catch { $org = $null }
if ($org -and $org.status -eq 0 -and $org.result.connectedStatus -eq 'Connected') {
    Pass "Org alias '$OrgAlias' is connected"
} else {
    $st = if ($org -and $org.result) { $org.result.connectedStatus } else { 'not authorized' }
    Fail "Org alias '$OrgAlias' is $st" "Run: sf org login web --alias $OrgAlias   (docs/02-authorize-org.md)"
}

Write-Host ''
if ($script:Fails -eq 0) {
    Write-Host 'All checks passed. Continue with docs/04-run-locally.md.' -ForegroundColor Green
    exit 0
}
Write-Host "$($script:Fails) check(s) failed. Fix them and run .\verify.ps1 again." -ForegroundColor Yellow
exit 1
