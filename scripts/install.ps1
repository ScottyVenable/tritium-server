# Tritium OS -- canonical bootstrapper (PowerShell: Windows)
#
# Default behaviour: detect platform, check requirements, set up
# %USERPROFILE%\.tritium-os\{bin,state,keys,ledger}, init the ledger DB,
# copy utility scripts to bin\, ensure agent mailboxes exist, print summary.
#
# Nothing invasive happens unless an opt-in flag is passed.
#
# Usage:
#   .\install.ps1                    # check + local setup
#   .\install.ps1 -InstallDeps       # install missing deps via winget
#   .\install.ps1 -WithClaude        # also install Claude CLI
#   .\install.ps1 -WithGemini        # also install Gemini CLI
#   .\install.ps1 -WithCopilot       # also install Copilot CLI
#   .\install.ps1 -WithLmStudio      # detect LM Studio endpoint
#   .\install.ps1 -Profile core      # default
#   .\install.ps1 -Profile full      # honour -With* flags
#   .\install.ps1 -DryRun            # show actions, do nothing
#   .\install.ps1 -Force             # overwrite without .bak backup
#   .\install.ps1 -Quiet             # suppress non-essential output
#
# Backward-compat: if -Target / -Adapter are passed, this delegates to
# scripts\install-adapter.ps1 (the per-repo adapter installer).

[CmdletBinding()]
param(
    [string]   $Target,
    [string]   $Adapter,
    [switch]   $InstallDeps,
    [switch]   $WithClaude,
    [switch]   $WithGemini,
    [switch]   $WithCopilot,
    [switch]   $WithLmStudio,
    [ValidateSet('core','full')]
    [string]   $Profile = 'core',
    [switch]   $DryRun,
    [switch]   $Force,
    [switch]   $Quiet
)

$ErrorActionPreference = 'Stop'
$Version = '4.2'

$here     = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $here '..')).Path

# --- backward-compat dispatch ----------------------------------------------
if ($Target -or $Adapter) {
    Write-Host "[tritium] -Target/-Adapter detected; delegating to install-adapter.ps1"
    & (Join-Path $here 'install-adapter.ps1') -Target $Target -Adapter $Adapter
    exit $LASTEXITCODE
}

function Write-Log    ([string]$msg) { if (-not $Quiet) { Write-Host $msg } }
function Write-WarnX  ([string]$msg) { Write-Warning $msg }
function Invoke-Step  ([scriptblock]$action, [string]$label) {
    if ($DryRun) { Write-Log "  [dry] $label" }
    else { & $action }
}

function Test-Cmd ([string]$name) {
    $c = Get-Command $name -ErrorAction SilentlyContinue
    return [bool]$c
}

# --- platform & package hints ----------------------------------------------
$Platform     = 'Windows'
$NodeHint     = 'winget install OpenJS.NodeJS.LTS'
$PythonHint   = 'winget install Python.Python.3.12'
$GitHint      = 'winget install Git.Git'

# --- requirements check ----------------------------------------------------
$nodeStatus = 'MISSING'; $nodeVer = ''
$pyStatus   = 'MISSING'; $pyVer   = ''; $pyBin = ''
$gitStatus  = 'MISSING'; $gitVer  = ''

if (Test-Cmd 'node') {
    try {
        $nodeVer = (& node --version) -replace '^v',''
        $major = [int]($nodeVer.Split('.')[0])
        if ($major -ge 20) { $nodeStatus = 'OK' } else { $nodeStatus = 'OLD' }
    } catch { }
}

foreach ($candidate in @('python3','python','py')) {
    if (Test-Cmd $candidate) {
        try {
            $v = (& $candidate -c 'import sys;print("%d.%d.%d"%sys.version_info[:3])' 2>$null)
            if ($v) {
                $pyBin = $candidate
                $pyVer = $v.Trim()
                $parts = $pyVer.Split('.')
                $maj = [int]$parts[0]; $min = [int]$parts[1]
                if ($maj -gt 3 -or ($maj -eq 3 -and $min -ge 11)) { $pyStatus = 'OK' } else { $pyStatus = 'OLD' }
                break
            }
        } catch { }
    }
}

if (Test-Cmd 'git') {
    try {
        $gitVer = ((& git --version) -split '\s+')[2]
        $gitStatus = 'OK'
    } catch { }
}

# --- paths -----------------------------------------------------------------
$tritiumHome = if ($env:TRITIUM_HOME) { $env:TRITIUM_HOME } else { Join-Path $env:USERPROFILE '.tritium-os' }
$binDir      = Join-Path $tritiumHome 'bin'
$stateDir    = Join-Path $tritiumHome 'state'
$keysDir     = Join-Path $tritiumHome 'keys'
$ledgerDir   = Join-Path $tritiumHome 'ledger'
$ledgerDb    = Join-Path $ledgerDir 'ledger.db'
$repoRootFile = Join-Path $stateDir 'repo-root'
$envFile     = Join-Path $stateDir 'env'
$mailboxRoot = Join-Path $repoRoot 'world\social\mailbox'

$agents = @('bridge','jesse','lux','nova','robert','rook','scout','sol','vex')
$v41    = @('tritium-crypt','tritium-open','tritium-close','tritium-cp','tritium-doctor','tier-auto','tritium-id','tritium-authorize')
$helpers= @('tritium.cmd','setup-ledger.py','new-agent.sh','new-agent.ps1','package.sh','package.ps1','install-adapter.sh','install-adapter.ps1')

Write-Log ''
Write-Log "+--- Tritium OS v$Version install ---"
Write-Log "  Platform   : $Platform"
Write-Log "  Repo       : $repoRoot"
Write-Log "  Tritium home: $tritiumHome"
Write-Log "  Profile    : $Profile"
if ($DryRun) { Write-Log "  Mode       : DRY-RUN (no changes will be made)" }

# --- optional: install missing deps via winget -----------------------------
if ($InstallDeps) {
    Write-Log ''
    Write-Log '[deps] -InstallDeps requested (using: winget)'
    if (-not (Test-Cmd 'winget')) {
        Write-WarnX 'winget not found; install App Installer from the Microsoft Store.'
    } else {
        if ($nodeStatus -ne 'OK') { Invoke-Step { winget install --silent --accept-source-agreements --accept-package-agreements OpenJS.NodeJS.LTS } 'winget install OpenJS.NodeJS.LTS' }
        if ($pyStatus   -ne 'OK') { Invoke-Step { winget install --silent --accept-source-agreements --accept-package-agreements Python.Python.3.12 } 'winget install Python.Python.3.12' }
        if ($gitStatus  -ne 'OK') { Invoke-Step { winget install --silent --accept-source-agreements --accept-package-agreements Git.Git } 'winget install Git.Git' }
    }
}

# --- directories -----------------------------------------------------------
Write-Log ''
Write-Log '[1/5] Tritium home directories'
foreach ($d in @($tritiumHome,$binDir,$stateDir,$keysDir,$ledgerDir)) {
    if (Test-Path $d) {
        Write-Log "  exists $d"
    } else {
        Write-Log "  mkdir  $d"
        Invoke-Step { New-Item -ItemType Directory -Path $d -Force | Out-Null } "mkdir $d"
    }
}
if ($DryRun) {
    Write-Log "  [dry] record repo root -> $repoRootFile"
} else {
    Set-Content -Path $repoRootFile -Value $repoRoot -NoNewline
    Write-Log "  repo   $repoRootFile"
}

# --- ledger ----------------------------------------------------------------
$ledgerStatus = 'missing'
Write-Log ''
Write-Log '[2/5] Ledger DB'
if (Test-Path $ledgerDb) {
    $ledgerStatus = 'exists'
    Write-Log "  exists $ledgerDb"
} elseif ($pyStatus -eq 'OK' -and (Test-Path (Join-Path $repoRoot 'scripts\setup-ledger.py'))) {
    if ($DryRun) {
        Write-Log "  [dry] $pyBin scripts\setup-ledger.py $ledgerDb"
        $ledgerStatus = 'initialized (dry)'
    } else {
        try {
            & $pyBin (Join-Path $repoRoot 'scripts\setup-ledger.py') $ledgerDb | Out-Null
            $ledgerStatus = 'initialized'
            Write-Log "  initialized $ledgerDb"
        } catch {
            $ledgerStatus = 'failed'
            Write-WarnX "ledger init failed: $_"
        }
    }
} else {
    Write-WarnX 'cannot init ledger (python missing or setup-ledger.py absent)'
}

# --- copy utility scripts --------------------------------------------------
Write-Log ''
Write-Log "[3/5] Utility scripts -> $binDir"
function Copy-One ([string]$name) {
    $src = Join-Path $here $name
    $dst = Join-Path $binDir $name
    if (-not (Test-Path $src)) {
        Write-Log "  [skip] $name not found in scripts\"
        return
    }
    if ((Test-Path $dst) -and (-not $Force)) {
        $sh1 = (Get-FileHash $src).Hash
        $sh2 = (Get-FileHash $dst).Hash
        if ($sh1 -eq $sh2) {
            Write-Log "  same   $name"
            return
        }
        Invoke-Step { Copy-Item $dst "$dst.bak" -Force } "backup $name"
        Write-Log "  backup $name -> $name.bak"
    }
    Invoke-Step { Copy-Item $src $dst -Force } "copy $name"
    Write-Log "  copy   $name"
}
foreach ($s in ($v41 + $helpers)) { Copy-One $s }

# --- mailboxes -------------------------------------------------------------
Write-Log ''
Write-Log "[4/5] Agent mailboxes -> $mailboxRoot"
$mailboxPresent = 0
if (-not $DryRun) { New-Item -ItemType Directory -Path $mailboxRoot -Force -ErrorAction SilentlyContinue | Out-Null }
foreach ($a in $agents) {
    $d = Join-Path $mailboxRoot $a
    if (Test-Path $d) {
        $mailboxPresent++
        Write-Log "  exists $a"
    } else {
        Write-Log "  mkdir  $a"
        Invoke-Step { New-Item -ItemType Directory -Path $d -Force | Out-Null } "mkdir $d"
        $mailboxPresent++
    }
}

# --- optional integrations -------------------------------------------------
Write-Log ''
Write-Log '[5/5] Optional integrations'
if ($Profile -eq 'full') { Write-Log '  profile=full (only the -With* flags you passed will run)' }

$claudeVer = ''
$geminiVer = ''
$copilotVer = ''
$lmStatus = 'not detected'

if (Test-Cmd 'claude') {
    try { $claudeVer = ((& claude --version 2>$null) | Select-Object -First 1) -replace '.*\s',''  } catch {}
}
if ($WithClaude) {
    if (-not $claudeVer) {
        if (Test-Cmd 'npm') {
            Write-Log '  installing Claude CLI (npm i -g @anthropic-ai/claude-cli)'
            Invoke-Step { npm install -g '@anthropic-ai/claude-cli' } 'npm i -g @anthropic-ai/claude-cli'
            if (Test-Cmd 'claude') { try { $claudeVer = ((& claude --version 2>$null) | Select-Object -First 1) -replace '.*\s','' } catch {} }
        } else { Write-WarnX 'npm not found; cannot install Claude CLI' }
    } else { Write-Log "  Claude CLI present ($claudeVer)" }
}

if (Test-Cmd 'gemini') {
    try { $geminiVer = ((& gemini --version 2>$null) | Select-Object -First 1) -replace '.*\s','' } catch {}
}
if ($WithGemini) {
    if (-not $geminiVer) {
        if (Test-Cmd 'npm') {
            Write-Log '  installing Gemini CLI (npm i -g @google/gemini-cli)'
            Invoke-Step { npm install -g '@google/gemini-cli' } 'npm i -g @google/gemini-cli'
            if (Test-Cmd 'gemini') { try { $geminiVer = ((& gemini --version 2>$null) | Select-Object -First 1) -replace '.*\s','' } catch {} }
        } else { Write-WarnX 'npm not found; cannot install Gemini CLI' }
    } else { Write-Log "  Gemini CLI present ($geminiVer)" }
}

if (Test-Cmd 'gh') {
    try {
        $extList = & gh extension list 2>$null
        if ($extList -match 'gh-copilot') {
            $copilotVer = ((& gh copilot --version 2>$null) | Select-Object -First 1) -replace '.*\s',''
        }
    } catch {}
}
if (-not $copilotVer -and (Test-Cmd 'copilot')) {
    try { $copilotVer = ((& copilot --version 2>$null) | Select-Object -First 1) -replace '.*\s','' } catch {}
}
if ($WithCopilot) {
    if (-not $copilotVer) {
        if (Test-Cmd 'gh') {
            Write-Log '  installing Copilot CLI (gh extension install github/gh-copilot)'
            Invoke-Step { gh extension install github/gh-copilot } 'gh extension install github/gh-copilot'
            try { $copilotVer = ((& gh copilot --version 2>$null) | Select-Object -First 1) -replace '.*\s','' } catch {}
        } elseif (Test-Cmd 'npm') {
            Write-Log '  installing Copilot CLI (npm i -g @github/copilot)'
            Invoke-Step { npm install -g '@github/copilot' } 'npm i -g @github/copilot'
            if (Test-Cmd 'copilot') { try { $copilotVer = ((& copilot --version 2>$null) | Select-Object -First 1) -replace '.*\s','' } catch {} }
        } else { Write-WarnX 'neither gh nor npm found; cannot install Copilot CLI' }
    } else { Write-Log "  Copilot CLI present ($copilotVer)" }
}

if ($WithLmStudio) {
    $lmUrl = 'http://localhost:1234/v1/models'
    try {
        $resp = Invoke-WebRequest -Uri $lmUrl -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
        if ($resp.StatusCode -eq 200) {
            $lmStatus = 'reachable at http://localhost:1234'
            if (-not $DryRun) {
                if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }
                $existing = if (Test-Path $envFile) { Get-Content $envFile } else { @() }
                if (-not ($existing -match '^LM_STUDIO_BASE_URL=')) {
                    Add-Content -Path $envFile -Value 'LM_STUDIO_BASE_URL=http://localhost:1234/v1'
                }
                Write-Log "  wrote LM_STUDIO_BASE_URL to $envFile"
            } else {
                Write-Log "  [dry] would write LM_STUDIO_BASE_URL=http://localhost:1234/v1 to $envFile"
            }
        }
    } catch {
        Write-Log "  LM Studio not reachable at $lmUrl"
        Write-Log '  start LM Studio desktop app and enable the local server (1234).'
    }
}

# --- adapter file counts ---------------------------------------------------
function Count-Agents ([string]$adapter) {
    $d = Join-Path $repoRoot "adapters\$adapter\agents"
    if (Test-Path $d) { (Get-ChildItem -Path $d -File -Filter '*.md' -ErrorAction SilentlyContinue).Count } else { 0 }
}
function Count-CopilotLocal {
    $d = Join-Path $repoRoot 'adapters\github-copilot-local\.github\agents'
    if (Test-Path $d) { (Get-ChildItem -Path $d -File -Filter '*.agent.md' -ErrorAction SilentlyContinue).Count } else { 0 }
}
$claudeAgentCount  = Count-Agents 'claude-cli'
$geminiAgentCount  = Count-Agents 'gemini-cli'
$copilotAgentCount = Count-CopilotLocal

# --- summary ---------------------------------------------------------------
function Format-Status ([string]$label,[string]$status,[string]$ver,[string]$hint) {
    switch ($status) {
        'OK'  { return "$label found $ver" }
        'OLD' { return "$label found $ver (TOO OLD) -- run: $hint" }
        default { return "$label MISSING -- run: $hint" }
    }
}

$overall = 'READY'
if ($nodeStatus -ne 'OK' -or $pyStatus -ne 'OK' -or $gitStatus -ne 'OK') { $overall = 'INCOMPLETE' }

if (-not $Quiet) {
    Write-Host ''
    Write-Host 'Tritium-OS install summary'
    Write-Host "- Platform: $Platform"
    Write-Host ('- ' + (Format-Status 'Node:'   $nodeStatus "v$nodeVer" $NodeHint))
    Write-Host ('- ' + (Format-Status 'Python:' $pyStatus   $pyVer      $PythonHint))
    Write-Host ('- ' + (Format-Status 'Git:'    $gitStatus  $gitVer     $GitHint))
    $homeState = if (Test-Path $tritiumHome) { 'exists' } else { 'created' }
    Write-Host "- Tritium home: $tritiumHome ($homeState)"
    Write-Host "- Ledger:   $ledgerStatus"
    Write-Host "- Mailboxes: $mailboxPresent/9 present"
    Write-Host "- Adapters: claude-cli $claudeAgentCount/9, gemini-cli $geminiAgentCount/9, copilot-local $copilotAgentCount/9"
    Write-Host '- Optional integrations:'
    if ($claudeVer)  { Write-Host "    Claude CLI:  found $claudeVer" }  else { Write-Host '    Claude CLI:  not found -- run: .\install.ps1 -WithClaude' }
    if ($geminiVer)  { Write-Host "    Gemini CLI:  found $geminiVer" }  else { Write-Host '    Gemini CLI:  not found -- run: .\install.ps1 -WithGemini' }
    if ($copilotVer) { Write-Host "    Copilot CLI: found $copilotVer" } else { Write-Host '    Copilot CLI: not found -- run: .\install.ps1 -WithCopilot' }
    Write-Host "    LM Studio:   $lmStatus"
    Write-Host "- Status: $overall"
}

exit 0
