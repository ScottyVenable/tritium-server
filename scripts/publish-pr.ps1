# Tritium Team -- Publish Pull Request Helper (PowerShell)
#
# Pushes the rebrand-tritium-team branch and opens a Pull Request on GitHub.
# Run this from your interactive terminal to handle authentication prompts.
#

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host "                 PUBLISHING TRITIUM TEAM PULL REQUEST               "
Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Verify we are on the correct branch
$branch = (git branch --show-current).Trim()
if ($branch -ne "rebrand-tritium-team") {
    Write-Warning "You are currently on branch '$branch'. Switching to 'rebrand-tritium-team'..."
    git checkout rebrand-tritium-team
}

# 2. Push the branch to origin
Write-Host "Step 1: Pushing branch 'rebrand-tritium-team' to GitHub..." -ForegroundColor Cyan
try {
    git push -u origin rebrand-tritium-team
} catch {
    Write-Error "Failed to push to remote repository. Make sure you have internet access and write permissions."
    exit 1
}

# 3. Check GitHub CLI Authentication status
Write-Host "`nStep 2: Checking GitHub CLI authentication..." -ForegroundColor Cyan
$authCheck = gh auth status 2>&1
if ($authCheck -match "Logged in to github.com") {
    Write-Host "  GitHub CLI is authenticated." -ForegroundColor Green
    
    # Create the Pull Request
    Write-Host "`nStep 3: Creating Pull Request..." -ForegroundColor Cyan
    gh pr create --title "Rebrand to Tritium Team and consolidate template folders" `
                 --body "This PR rebrands the repository from Tritium Server to Tritium Team, deletes redundant copies of agent files, adds unified setup-team.ps1/setup-team.sh bootstrappers, and updates all AI editor guides." `
                 --web
} else {
    Write-Host "  GitHub CLI is not authenticated or token is invalid." -ForegroundColor Yellow
    Write-Host "  Please authenticate by running: gh auth login" -ForegroundColor Yellow
    Write-Host "  After logging in, you can create the PR by running:" -ForegroundColor Gray
    Write-Host "  gh pr create --title 'Rebrand to Tritium Team' --web" -ForegroundColor White
}

Write-Host ""
Write-Host "Done!" -ForegroundColor Green
Write-Host ""
