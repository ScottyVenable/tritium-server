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
$tritiumHome = if ($env:TRITIUM_HOME) { $env:TRITIUM_HOME } else { Join-Path $env:USERPROFILE '.tritium-team' }

# Determine source template paths dynamically
$repoAgents = Join-Path $repoRoot "agents"
if (Test-Path $repoAgents) {
    $srcAgents   = $repoAgents
    $srcWorld    = Join-Path $repoRoot "world"
    $srcSettings = Join-Path $repoRoot "SETTINGS.example.jsonc"
    $srcAdapters = Join-Path $repoRoot "adapters"
} else {
    $srcAgents   = Join-Path $tritiumHome "templates\agents"
    $srcWorld    = Join-Path $tritiumHome "templates\world"
    $srcSettings = Join-Path $tritiumHome "templates\SETTINGS.example.jsonc"
    $srcAdapters = Join-Path $tritiumHome "templates\adapters"
}

if (-not (Test-Path $Target)) {
    New-Item -ItemType Directory -Path $Target -Force | Out-Null
}
$targetPath = (Resolve-Path $Target).Path

Write-Host ""
Write-Host "===================================================================="
Write-Host "                  TRITIUM TEAM WORKFLOW INITIALIZER                 "
Write-Host "===================================================================="
Write-Host "  Source Templates: $srcAgents"
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
Copy-Dir $srcAgents (Join-Path $targetPath "agents")

# 2. Copy World/Memory Template
Write-Host ""
Write-Host "Step 2: Installing World Memory and Mailbox Systems..."
Copy-Dir $srcWorld (Join-Path $targetPath "world")

# 3. Setup Settings File
Write-Host ""
Write-Host "Step 3: Configuring Master Settings..."
$settingsDst = Join-Path $targetPath "SETTINGS.jsonc"
if (Test-Path $settingsDst) {
    Write-Host "  [skipped]   SETTINGS.jsonc already exists"
} else {
    Copy-Item $srcSettings $settingsDst
    Write-Host "  [created]   SETTINGS.jsonc (default template copied)"
}

# 4. Install Adapter Rules
Write-Host ""
Write-Host "Step 4: Writing AI Tool Integration Adapters..."

# 4.a Claude CLI (CLAUDE.md)
$claudeDst = Join-Path $targetPath "CLAUDE.md"
$claudeSrc = Join-Path $srcAdapters "claude-cli\CLAUDE.md"
if (Test-Path $claudeSrc) {
    Copy-Item $claudeSrc $claudeDst -Force
    Write-Host "  [installed] CLAUDE.md (Claude CLI adapter)"
}

# 4.b VS Code Cline (.clinerules)
$clineDst = Join-Path $targetPath ".clinerules"
$clineSrc = Join-Path $srcAdapters "cline\.clinerules"
if (Test-Path $clineSrc) {
    Copy-Item $clineSrc $clineDst -Force
    Write-Host "  [installed] .clinerules (VS Code Cline adapter)"
}

# 4.c Cursor (.cursorrules)
$cursorDst = Join-Path $targetPath ".cursorrules"
$cursorSrc = Join-Path $srcAdapters "cursor\.cursorrules"
if (Test-Path $cursorSrc) {
    Copy-Item $cursorSrc $cursorDst -Force
    Write-Host "  [installed] .cursorrules (Cursor editor adapter)"
}

# 4.d Antigravity / Gemini CLI (.antigravityrules and GEMINI.md)
$antigravityDst = Join-Path $targetPath ".antigravityrules"
$antigravitySrc = Join-Path $srcAdapters "antigravity\.antigravityrules"
if (Test-Path $antigravitySrc) {
    Copy-Item $antigravitySrc $antigravityDst -Force
    Write-Host "  [installed] .antigravityrules (Antigravity CLI adapter)"
}
$geminiDst = Join-Path $targetPath "GEMINI.md"
$geminiSrc = Join-Path $srcAdapters "gemini-cli\GEMINI.md"
if (Test-Path $geminiSrc) {
    Copy-Item $geminiSrc $geminiDst -Force
    Write-Host "  [installed] GEMINI.md (Gemini CLI adapter)"
}

# 4.e VS Code GitHub Copilot (.github/copilot-instructions.md)
$copilotDir = Join-Path $targetPath ".github"
if (-not (Test-Path $copilotDir)) { New-Item -ItemType Directory -Path $copilotDir -Force | Out-Null }
$copilotDst = Join-Path $copilotDir "copilot-instructions.md"
$copilotSrc = Join-Path $srcAdapters "github-copilot-local\.github\copilot-instructions.md"
if (Test-Path $copilotSrc) {
    Copy-Item $copilotSrc $copilotDst -Force
    Write-Host "  [installed] .github/copilot-instructions.md (GitHub Copilot adapter)"
}

Write-Host ""
Write-Host "SUCCESS: Tritium Team workflow successfully initialized!"
Write-Host "Start the live coordination dashboard by running: tritium serve"
Write-Host "Ensure the Tritium Team server is running to let your agents communicate."
Write-Host ""
