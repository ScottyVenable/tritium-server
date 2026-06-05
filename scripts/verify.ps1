# Verify a Tritium-Team checkout: toolchain, repo structure, agent coverage,
# inbox CLI smoke test, and (warn-only) optional integrations.
#
# Exits 0 on PASS, 1 on FAIL. Pass -Quiet to suppress per-check OK lines.

[CmdletBinding()]
param(
    [switch]$Quiet
)

$ErrorActionPreference = 'Continue'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = (Resolve-Path (Join-Path $here '..')).Path

$agents = @('bridge','sol','jesse','vex','rook','robert','lux','nova','scout')

$script:Fails = New-Object System.Collections.Generic.List[string]
$script:Warns = New-Object System.Collections.Generic.List[string]

function Write-Ok   ($msg) { if (-not $Quiet) { Write-Host "  OK    $msg" } }
function Write-Fail ($msg) { $script:Fails.Add($msg) | Out-Null; Write-Host "  FAIL  $msg" }
function Write-Warn2($msg) { $script:Warns.Add($msg) | Out-Null; Write-Host "  WARN  $msg" }

# --- toolchain -------------------------------------------------------------
$nodeVer = ''; $nodeStatus = 'MISSING'
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if ($nodeCmd) {
    try {
        $raw = (& node -v 2>$null).Trim().TrimStart('v')
        $nodeVer = $raw
        $major = [int]($raw -split '\.')[0]
        if ($major -ge 20) { $nodeStatus = 'OK'; Write-Ok "Node v$nodeVer (>=20)" }
        else { $nodeStatus = 'OLD'; Write-Fail "Node v$nodeVer is too old (need >=20)" }
    } catch { Write-Fail "Node present but version unreadable" }
} else {
    Write-Fail "Node not found on PATH (need >=20)"
}

$pyVer = ''; $pyStatus = 'MISSING'; $pyBin = $null
foreach ($cand in @('python','python3','py')) {
    $c = Get-Command $cand -ErrorAction SilentlyContinue
    if ($c) {
        try {
            $raw = (& $cand --version 2>&1) -join ' '
            if ($raw -match '(\d+)\.(\d+)\.(\d+)') {
                $pyBin = $cand
                $pyVer = "$($matches[1]).$($matches[2]).$($matches[3])"
                break
            }
        } catch {}
    }
}
if ($pyVer) {
    $parts = $pyVer -split '\.'
    $pyMajor = [int]$parts[0]; $pyMinor = [int]$parts[1]
    if ($pyMajor -gt 3 -or ($pyMajor -eq 3 -and $pyMinor -ge 11)) {
        $pyStatus = 'OK'; Write-Ok "Python $pyVer (>=3.11) via $pyBin"
    } else {
        $pyStatus = 'OLD'; Write-Fail "Python $pyVer is too old (need >=3.11)"
    }
} else {
    Write-Fail "Python not found on PATH (need >=3.11)"
}

$gitVer = ''
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if ($gitCmd) {
    try {
        $gitRaw = (& git --version 2>$null)
        if ($gitRaw -match '(\d+\.\d+\.\d+)') { $gitVer = $matches[1] }
        Write-Ok "git $gitVer"
    } catch { Write-Fail "git present but version unreadable" }
} else {
    Write-Fail "git not found on PATH"
}

# --- repo structure --------------------------------------------------------
function Test-RepoPath ([string]$kind, [string]$rel) {
    $p = Join-Path $root $rel
    if ($kind -eq 'f' -and (Test-Path -LiteralPath $p -PathType Leaf)) { Write-Ok "file  $rel" }
    elseif ($kind -eq 'd' -and (Test-Path -LiteralPath $p -PathType Container)) { Write-Ok "dir   $rel" }
    else { Write-Fail "missing $kind $rel" }
}

Test-RepoPath 'f' 'runtime/cli/tritium.js'
Test-RepoPath 'd' 'runtime/server'
Test-RepoPath 'd' 'runtime/heartbeat'
Test-RepoPath 'f' 'data/registry/models.json'

$mailboxPresent = 0
foreach ($a in $agents) {
    $p = Join-Path $root "world/social/mailbox/$a"
    if (Test-Path -LiteralPath $p -PathType Container) {
        $mailboxPresent++; Write-Ok "mbox  world/social/mailbox/$a"
    } else {
        Write-Fail "missing mailbox world/social/mailbox/$a"
    }
}

$agentMdPresent = 0
foreach ($a in $agents) {
    $p = Join-Path $root "agents/$a/agent.md"
    if (Test-Path -LiteralPath $p -PathType Leaf) {
        $agentMdPresent++; Write-Ok "agent agents/$a/agent.md"
    } else {
        Write-Fail "missing agents/$a/agent.md"
    }
}

$claudeOk = 0; $geminiOk = 0; $copilotOk = 0; $clineOk = 0; $cursorOk = 0; $antigravityOk = 0

$p_claude = Join-Path $root "adapters/claude-cli/CLAUDE.md"
if (Test-Path -LiteralPath $p_claude -PathType Leaf) { $claudeOk = 1; Write-Ok "adapter claude-cli/CLAUDE.md" }
else { Write-Fail "missing adapters/claude-cli/CLAUDE.md" }

$p_gemini = Join-Path $root "adapters/gemini-cli/GEMINI.md"
if (Test-Path -LiteralPath $p_gemini -PathType Leaf) { $geminiOk = 1; Write-Ok "adapter gemini-cli/GEMINI.md" }
else { Write-Fail "missing adapters/gemini-cli/GEMINI.md" }

$p_copilot = Join-Path $root "adapters/github-copilot-local/.github/copilot-instructions.md"
if (Test-Path -LiteralPath $p_copilot -PathType Leaf) { $copilotOk = 1; Write-Ok "adapter github-copilot-local/.github/copilot-instructions.md" }
else { Write-Fail "missing adapters/github-copilot-local/.github/copilot-instructions.md" }

$p_cline = Join-Path $root "adapters/cline/.clinerules"
if (Test-Path -LiteralPath $p_cline -PathType Leaf) { $clineOk = 1; Write-Ok "adapter cline/.clinerules" }
else { Write-Fail "missing adapters/cline/.clinerules" }

$p_cursor = Join-Path $root "adapters/cursor/.cursorrules"
if (Test-Path -LiteralPath $p_cursor -PathType Leaf) { $cursorOk = 1; Write-Ok "adapter cursor/.cursorrules" }
else { Write-Fail "missing adapters/cursor/.cursorrules" }

$p_antigravity = Join-Path $root "adapters/antigravity/.antigravityrules"
if (Test-Path -LiteralPath $p_antigravity -PathType Leaf) { $antigravityOk = 1; Write-Ok "adapter antigravity/.antigravityrules" }
else { Write-Fail "missing adapters/antigravity/.antigravityrules" }

# --- inbox CLI smoke test --------------------------------------------------
$inboxStatus = 'SKIP'
$cliPath = Join-Path $root 'runtime/cli/tritium.js'
if ($nodeStatus -eq 'OK' -and (Test-Path -LiteralPath $cliPath -PathType Leaf)) {
    $prev = Get-Location
    try {
        Set-Location $root
        $null = & node 'runtime/cli/tritium.js' inbox check --agent sol 2>&1
        if ($LASTEXITCODE -eq 0) { $inboxStatus = 'OK'; Write-Ok 'tritium inbox check --agent sol' }
        else { $inboxStatus = 'FAIL'; Write-Fail "tritium inbox check --agent sol exited $LASTEXITCODE" }
    } catch {
        $inboxStatus = 'FAIL'; Write-Fail "tritium inbox check threw: $_"
    } finally {
        Set-Location $prev
    }
}

# --- ledger (warn only) ----------------------------------------------------
$homeDir = if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }
$ledgerPath = Join-Path $homeDir '.tritium-team/ledger/credits.db'
if (Test-Path -LiteralPath $ledgerPath -PathType Leaf) {
    $ledgerStatus = "present at $ledgerPath"
    Write-Ok "ledger $ledgerPath"
} else {
    $ledgerStatus = 'not yet initialized -- run: .\scripts\install.ps1'
    Write-Warn2 "ledger not initialized at $ledgerPath"
}

# --- optional CLIs (warn only) ---------------------------------------------
function Get-CliVersion ([string]$bin) {
    $c = Get-Command $bin -ErrorAction SilentlyContinue
    if (-not $c) { return $null }
    try {
        $out = (& $bin --version 2>&1) | Select-Object -First 1
        return ([string]$out).Trim()
    } catch { return $null }
}

$claudeVer  = Get-CliVersion 'claude'
$geminiVer  = Get-CliVersion 'gemini'
$copilotVer = Get-CliVersion 'copilot'

if ($claudeVer)  { Write-Ok "claude CLI: $claudeVer" }   else { Write-Warn2 'claude CLI not on PATH (optional)' }
if ($geminiVer)  { Write-Ok "gemini CLI: $geminiVer" }   else { Write-Warn2 'gemini CLI not on PATH (optional)' }
if ($copilotVer) { Write-Ok "copilot CLI: $copilotVer" } else { Write-Warn2 'copilot CLI not on PATH (optional)' }

$lmStatus = 'not reachable'
try {
    $resp = Invoke-WebRequest -UseBasicParsing -Uri 'http://localhost:1234/v1/models' -TimeoutSec 2 -ErrorAction Stop
    if ($resp.StatusCode -eq 200) {
        $lmStatus = 'reachable at http://localhost:1234'
        Write-Ok 'LM Studio reachable'
    }
} catch {
    Write-Warn2 'LM Studio not reachable at http://localhost:1234'
}

# --- summary ---------------------------------------------------------------
$overall = if ($script:Fails.Count -gt 0) { 'FAIL' } else { 'PASS' }

Write-Host ''
Write-Host 'Tritium-Team verify summary'
switch ($nodeStatus) {
    'OK'  { Write-Host "- Node:    found v$nodeVer" }
    'OLD' { Write-Host "- Node:    v$nodeVer (TOO OLD, need >=20)" }
    default { Write-Host '- Node:    MISSING (need >=20)' }
}
switch ($pyStatus) {
    'OK'  { Write-Host "- Python:  found $pyVer" }
    'OLD' { Write-Host "- Python:  $pyVer (TOO OLD, need >=3.11)" }
    default { Write-Host '- Python:  MISSING (need >=3.11)' }
}
if ($gitVer) { Write-Host "- Git:     found $gitVer" } else { Write-Host '- Git:     MISSING' }
Write-Host "- Mailboxes: $mailboxPresent/9 present"
Write-Host "- Agent docs: $agentMdPresent/9 present"
Write-Host "- Adapters: claude-cli=$claudeOk, gemini-cli=$geminiOk, copilot-local=$copilotOk, cline=$clineOk, cursor=$cursorOk, antigravity=$antigravityOk"
Write-Host "- Inbox CLI: $inboxStatus"
Write-Host "- Ledger:  $ledgerStatus"
Write-Host '- Optional integrations:'
if ($claudeVer)  { Write-Host "    Claude CLI:  found $claudeVer" }  else { Write-Host '    Claude CLI:  not found -- run: .\scripts\install.ps1 -WithClaude' }
if ($geminiVer)  { Write-Host "    Gemini CLI:  found $geminiVer" }  else { Write-Host '    Gemini CLI:  not found -- run: .\scripts\install.ps1 -WithGemini' }
if ($copilotVer) { Write-Host "    Copilot CLI: found $copilotVer" } else { Write-Host '    Copilot CLI: not found -- run: .\scripts\install.ps1 -WithCopilot' }
Write-Host "    LM Studio:   $lmStatus"

if ($script:Fails.Count -gt 0) {
    Write-Host ''
    Write-Host "Failures ($($script:Fails.Count)):"
    foreach ($f in $script:Fails) { Write-Host "  - $f" }
}

Write-Host "- Status: $overall -- see above"

if ($overall -eq 'PASS') { exit 0 } else { exit 1 }
