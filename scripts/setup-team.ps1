# Tritium Team -- Workflow Setup Bootstrapper (PowerShell)
#
# Sets up the Tritium Team workflow structure in a target repository.
# Drops in the agents, world/memory layers, and configures adapter rules.
#

param(
    [string] $Target = ".",
    [switch] $Force
)

$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $here '..')).Path

if (-not (Test-Path $Target)) {
    New-Item -ItemType Directory -Path $Target -Force | Out-Null
}
$targetPath = (Resolve-Path $Target).Path

Write-Host ""
Write-Host "===================================================================="
Write-Host "                  TRITIUM TEAM WORKFLOW INITIALIZER                 "
Write-Host "===================================================================="
Write-Host "  Source Template : $repoRoot"
Write-Host "  Target Project  : $targetPath"
Write-Host ""

# Helper to copy directory structures safely
function Copy-Dir ([string]$srcDir, [string]$dstDir) {
    if (-not (Test-Path $srcDir)) {
        Write-Warning "Source directory $srcDir not found!"
        return
    }
    
    if (-not (Test-Path $dstDir)) {
        New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
    }
    
    Get-ChildItem -Path $srcDir -Recurse | ForEach-Object {
        $rel = $_.FullName.Substring($srcDir.Length + 1)
        $dest = Join-Path $dstDir $rel
        
        if ($_.PsIsContainer) {
            if (-not (Test-Path $dest)) {
                New-Item -ItemType Directory -Path $dest -Force | Out-Null
            }
        } else {
            if ($_.Extension -eq '.bak') { return }
            
            if (Test-Path $dest) {
                if ($Force) {
                    Copy-Item $_.FullName $dest -Force
                    Write-Host "  [overwrote] $rel"
                } else {
                    Write-Host "  [skipped]   $rel (already exists)"
                }
            } else {
                $parent = Split-Path -Parent $dest
                if (-not (Test-Path $parent)) {
                    New-Item -ItemType Directory -Path $parent -Force | Out-Null
                }
                Copy-Item $_.FullName $dest -Force
                Write-Host "  [created]   $rel"
            }
        }
    }
}

# 1. Copy Agents Template
Write-Host "Step 1: Installing Agent Personalities and Schemas..."
Copy-Dir (Join-Path $repoRoot "agents") (Join-Path $targetPath "agents")

# 2. Copy World/Memory Template
Write-Host ""
Write-Host "Step 2: Installing World Memory and Mailbox Systems..."
Copy-Dir (Join-Path $repoRoot "world") (Join-Path $targetPath "world")

# 3. Setup Settings File
Write-Host ""
Write-Host "Step 3: Configuring Master Settings..."
$settingsDst = Join-Path $targetPath "SETTINGS.jsonc"
$settingsSrc = Join-Path $repoRoot "SETTINGS.example.jsonc"
if (Test-Path $settingsDst) {
    Write-Host "  [skipped]   SETTINGS.jsonc already exists"
} else {
    Copy-Item $settingsSrc $settingsDst
    Write-Host "  [created]   SETTINGS.jsonc (default template copied)"
}

# 4. Install Adapter Rules
Write-Host ""
Write-Host "Step 4: Writing AI Tool Integration Adapters..."

# 4.a Claude CLI (CLAUDE.md)
$claudeDst = Join-Path $targetPath "CLAUDE.md"
$claudeSrc = Join-Path $repoRoot "adapters\claude-cli\CLAUDE.md"
if (Test-Path $claudeSrc) {
    Copy-Item $claudeSrc $claudeDst -Force
    Write-Host "  [installed] CLAUDE.md (Claude CLI adapter)"
}

# 4.b VS Code Cline (.clinerules)
$clineDst = Join-Path $targetPath ".clinerules"
$clineSrc = Join-Path $repoRoot "adapters\cline\.clinerules"
if (Test-Path $clineSrc) {
    Copy-Item $clineSrc $clineDst -Force
    Write-Host "  [installed] .clinerules (VS Code Cline adapter)"
}

# 4.c Cursor (.cursorrules)
$cursorDst = Join-Path $targetPath ".cursorrules"
$cursorSrc = Join-Path $repoRoot "adapters\cursor\.cursorrules"
if (Test-Path $cursorSrc) {
    Copy-Item $cursorSrc $cursorDst -Force
    Write-Host "  [installed] .cursorrules (Cursor editor adapter)"
}

# 4.d Antigravity / Gemini CLI (.antigravityrules and GEMINI.md)
$antigravityDst = Join-Path $targetPath ".antigravityrules"
$antigravitySrc = Join-Path $repoRoot "adapters\antigravity\.antigravityrules"
if (Test-Path $antigravitySrc) {
    Copy-Item $antigravitySrc $antigravityDst -Force
    Write-Host "  [installed] .antigravityrules (Antigravity CLI adapter)"
}
$geminiDst = Join-Path $targetPath "GEMINI.md"
$geminiSrc = Join-Path $repoRoot "adapters\gemini-cli\GEMINI.md"
if (Test-Path $geminiSrc) {
    Copy-Item $geminiSrc $geminiDst -Force
    Write-Host "  [installed] GEMINI.md (Gemini CLI adapter)"
}

# 4.e VS Code GitHub Copilot (.github/copilot-instructions.md)
$copilotDir = Join-Path $targetPath ".github"
if (-not (Test-Path $copilotDir)) { New-Item -ItemType Directory -Path $copilotDir -Force | Out-Null }
$copilotDst = Join-Path $copilotDir "copilot-instructions.md"
$copilotSrc = Join-Path $repoRoot "adapters\github-copilot-local\.github\copilot-instructions.md"
if (Test-Path $copilotSrc) {
    Copy-Item $copilotSrc $copilotDst -Force
    Write-Host "  [installed] .github/copilot-instructions.md (GitHub Copilot adapter)"
}

Write-Host ""
Write-Host "SUCCESS: Tritium Team workflow successfully initialized!"
Write-Host "Start the live coordination dashboard by running: tritium serve"
Write-Host "Ensure the Tritium Team server is running to let your agents communicate."
Write-Host ""
