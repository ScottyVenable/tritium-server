#!/usr/bin/env bash
# Tritium Team -- Workflow Setup Bootstrapper (Bash)
#
# Sets up the Tritium Team workflow structure in a target repository.
# Drops in the agents, world/memory layers, and configures adapter rules
# for Claude CLI, VS Code Cline, Cursor, Antigravity, and GitHub Copilot.
#
# Usage:
#   bash scripts/setup-team.sh --target /path/to/your-project
#

set -euo pipefail

target="."
force=0

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) target="$2"; shift 2;;
    --force)  force=1; shift;;
    *) echo "Unknown argument: $1" >&2; exit 1;;
  esac
done

# ANSI Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Resolve paths
here="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$here/.." && pwd)"

if [ ! -d "$target" ]; then
  mkdir -p "$target"
fi
target_path="$(cd "$target" && pwd)"

echo -e ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                  TRITIUM TEAM WORKFLOW INITIALIZER                 ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════╝${NC}"
echo -e "  Source Template : ${GRAY}$repo_root${NC}"
echo -e "  Target Project  : ${GRAY}$target_path${NC}"
echo -e ""

copy_dir() {
  local src="$1"
  local dst="$2"
  
  if [ ! -d "$src" ]; then
    echo "Warning: Source directory $src does not exist"
    return
  fi
  
  mkdir -p "$dst"
  
  # Copy files using find to respect exclude patterns
  find "$src" -type f | while read -r file; do
    # Skip .bak files
    [[ "$file" == *.bak ]] && continue
    
    # Calculate relative path
    rel="${file#$src/}"
    dest_file="$dst/$rel"
    dest_dir="$(dirname "$dest_file")"
    
    mkdir -p "$dest_dir"
    
    if [ -f "$dest_file" ]; then
      if [ "$force" -eq 1 ]; then
        cp -f "$file" "$dest_file"
        echo -e "  ${YELLOW}[overwrote]${NC} $rel"
      else
        echo -e "  ${GRAY}[skipped]${NC}   $rel (already exists)"
      fi
    else
      cp "$file" "$dest_file"
      echo -e "  ${GREEN}[created]${NC}   $rel"
    fi
  done
}

# 1. Copy Agents Template
echo -e "Step 1: Installing Agent Personalities & Schemas..."
copy_dir "$repo_root/agents" "$target_path/agents"

# 2. Copy World/Memory Template
echo -e "\nStep 2: Installing World Memory & Mailbox Systems..."
copy_dir "$repo_root/world" "$target_path/world"

# 3. Setup Settings File
echo -e "\nStep 3: Configuring Master Settings..."
settings_dst="$target_path/SETTINGS.jsonc"
settings_src="$repo_root/SETTINGS.example.jsonc"
if [ -f "$settings_dst" ]; then
  echo -e "  ${GRAY}[skipped]${NC}   SETTINGS.jsonc already exists"
else
  cp "$settings_src" "$settings_dst"
  echo -e "  ${GREEN}[created]${NC}   SETTINGS.jsonc (default template copied)"
fi

# 4. Install Adapter Rules
echo -e "\nStep 4: Writing AI Tool Integration Adapters..."

# 4.a Claude CLI (CLAUDE.md)
if [ -f "$repo_root/adapters/claude-cli/CLAUDE.md" ]; then
  cp -f "$repo_root/adapters/claude-cli/CLAUDE.md" "$target_path/CLAUDE.md"
  echo -e "  ${GREEN}[installed]${NC} CLAUDE.md (Claude CLI adapter)"
fi

# 4.b VS Code Cline (.clinerules)
if [ -f "$repo_root/adapters/cline/.clinerules" ]; then
  cp -f "$repo_root/adapters/cline/.clinerules" "$target_path/.clinerules"
  echo -e "  ${GREEN}[installed]${NC} .clinerules (VS Code Cline adapter)"
fi

# 4.c Cursor (.cursorrules)
if [ -f "$repo_root/adapters/cursor/.cursorrules" ]; then
  cp -f "$repo_root/adapters/cursor/.cursorrules" "$target_path/.cursorrules"
  echo -e "  ${GREEN}[installed]${NC} .cursorrules (Cursor editor adapter)"
fi

# 4.d Antigravity / Gemini CLI (.antigravityrules & GEMINI.md)
if [ -f "$repo_root/adapters/antigravity/.antigravityrules" ]; then
  cp -f "$repo_root/adapters/antigravity/.antigravityrules" "$target_path/.antigravityrules"
  echo -e "  ${GREEN}[installed]${NC} .antigravityrules (Antigravity CLI adapter)"
fi
if [ -f "$repo_root/adapters/gemini-cli/GEMINI.md" ]; then
  cp -f "$repo_root/adapters/gemini-cli/GEMINI.md" "$target_path/GEMINI.md"
  echo -e "  ${GREEN}[installed]${NC} GEMINI.md (Gemini CLI adapter)"
fi

# 4.e VS Code GitHub Copilot (.github/copilot-instructions.md)
mkdir -p "$target_path/.github"
if [ -f "$repo_root/adapters/github-copilot-local/.github/copilot-instructions.md" ]; then
  cp -f "$repo_root/adapters/github-copilot-local/.github/copilot-instructions.md" "$target_path/.github/copilot-instructions.md"
  echo -e "  ${GREEN}[installed]${NC} .github/copilot-instructions.md (GitHub Copilot adapter)"
fi

echo -e ""
echo -e "${GREEN}🎉 Tritium Team workflow successfully initialized!${NC}"
echo -e "Start the live coordination dashboard by running: ${YELLOW}tritium serve${NC}"
echo -e "Ensure the Tritium Team server is running to let your agents communicate."
echo -e ""
