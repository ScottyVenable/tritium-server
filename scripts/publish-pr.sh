#!/usr/bin/env bash
# Tritium Team -- Publish Pull Request Helper (Bash)
#
# Pushes the rebrand-tritium-team branch and opens a Pull Request on GitHub.
# Run this from your interactive terminal to handle authentication prompts.
#

set -euo pipefail

# ANSI Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
GRAY='\033[0;90m'
NC='\033[0m'

echo -e ""
echo -e "${CYAN}====================================================================${NC}"
echo -e "${CYAN}                 PUBLISHING TRITIUM TEAM PULL REQUEST               ${NC}"
echo -e "${CYAN}====================================================================${NC}"
echo -e ""

# 1. Verify we are on the correct branch
branch=$(git branch --show-current)
if [ "$branch" != "rebrand-tritium-team" ]; then
    echo -e "${YELLOW}Warning: Currently on branch '$branch'. Switching to 'rebrand-tritium-team'...${NC}"
    git checkout rebrand-tritium-team
fi

# 2. Push the branch to origin
echo -e "${CYAN}Step 1: Pushing branch 'rebrand-tritium-team' to GitHub...${NC}"
git push -u origin rebrand-tritium-team

# 3. Check GitHub CLI Authentication status
echo -e "\n${CYAN}Step 2: Checking GitHub CLI authentication...${NC}"
if gh auth status &>/dev/null; then
    echo -e "  ${GREEN}GitHub CLI is authenticated.${NC}"
    
    # Create the Pull Request
    echo -e "\n${CYAN}Step 3: Creating Pull Request...${NC}"
    gh pr create --title "Rebrand to Tritium Team and consolidate template folders" \
                 --body "This PR rebrands the repository from Tritium Server to Tritium Team, deletes redundant copies of agent files, adds unified setup-team.ps1/setup-team.sh bootstrappers, and updates all AI editor guides." \
                 --web
else
    echo -e "  ${YELLOW}GitHub CLI is not authenticated or token is invalid.${NC}"
    echo -e "  Please authenticate by running: ${YELLOW}gh auth login${NC}"
    echo -e "  After logging in, you can create the PR by running:"
    echo -e "  ${NC}gh pr create --title 'Rebrand to Tritium Team' --web${NC}"
fi

echo -e "\n${GREEN}Done!${NC}\n"
