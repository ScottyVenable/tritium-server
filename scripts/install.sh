#!/usr/bin/env bash
# Tritium OS -- canonical bootstrapper (Bash: Linux / macOS / Termux)
#
# Default behaviour: detect platform, check requirements, set up
# ~/.tritium-os/{bin,state,keys,ledger}, init the ledger DB, copy utility
# scripts to bin/, ensure agent mailboxes exist, print a summary block.
#
# Nothing invasive happens unless an opt-in flag is passed.
#
# Usage:
#   bash scripts/install.sh                    # check + local setup
#   bash scripts/install.sh --install-deps     # install missing system deps
#   bash scripts/install.sh --with-claude      # also install Claude CLI
#   bash scripts/install.sh --with-gemini      # also install Gemini CLI
#   bash scripts/install.sh --with-copilot     # also install Copilot CLI
#   bash scripts/install.sh --with-lmstudio    # detect LM Studio endpoint
#   bash scripts/install.sh --profile core     # default: just the local setup
#   bash scripts/install.sh --profile full     # honour every --with-* given
#   bash scripts/install.sh --dry-run          # show actions, do nothing
#   bash scripts/install.sh --force            # overwrite without .bak backup
#   bash scripts/install.sh --quiet            # suppress non-essential output
#   bash scripts/install.sh -h | --help        # this message
#
# Backward-compat: if --target/--adapter are passed, this delegates to
# scripts/install-adapter.sh (the per-repo adapter installer).

set -euo pipefail

VERSION="4.2"

# --- backward-compat dispatch to install-adapter.sh -------------------------
for a in "$@"; do
    case "$a" in
        --target|--adapter)
            HERE_BC="$(cd "$(dirname "$0")" && pwd)"
            echo "[tritium] --target/--adapter detected; delegating to install-adapter.sh" >&2
            exec bash "$HERE_BC/install-adapter.sh" "$@"
            ;;
    esac
done

# --- flag parsing -----------------------------------------------------------
DRY=0
QUIET=0
FORCE=0
INSTALL_DEPS=0
WITH_CLAUDE=0
WITH_GEMINI=0
WITH_COPILOT=0
WITH_LMSTUDIO=0
PROFILE="core"

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)        DRY=1 ;;
        --quiet)          QUIET=1 ;;
        --force)          FORCE=1 ;;
        --install-deps)   INSTALL_DEPS=1 ;;
        --with-claude)    WITH_CLAUDE=1 ;;
        --with-gemini)    WITH_GEMINI=1 ;;
        --with-copilot)   WITH_COPILOT=1 ;;
        --with-lmstudio)  WITH_LMSTUDIO=1 ;;
        --profile)        PROFILE="${2:-core}"; shift ;;
        --profile=*)      PROFILE="${1#--profile=}" ;;
        -h|--help)
            sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "unknown arg: $1" >&2
            echo "run: bash $0 --help" >&2
            exit 1
            ;;
    esac
    shift
done

# --- helpers ----------------------------------------------------------------
_log()  { [ "$QUIET" -eq 0 ] && printf '%s\n' "$1" || true; }
_warn() { printf 'WARN: %s\n' "$1" >&2; }
_run()  { if [ "$DRY" -eq 1 ]; then printf '  [dry] %s\n' "$*"; else "$@"; fi; }

# Compare semver-ish "MAJOR.MINOR" >= required. Returns 0 if ok.
_ver_ge() {
    local have="$1" req="$2"
    local have_major; have_major="$(printf '%s' "$have" | awk -F. '{print $1+0}')"
    local req_major;  req_major="$(printf  '%s' "$req"  | awk -F. '{print $1+0}')"
    [ "$have_major" -ge "$req_major" ]
}

# --- platform detection -----------------------------------------------------
PLATFORM="unknown"
PKG_HINT_NODE=""
PKG_HINT_PY=""
PKG_HINT_GIT=""
PKG_INSTALLER=""

if command -v pkg >/dev/null 2>&1 && [ -d "/data/data/com.termux" ]; then
    PLATFORM="Termux"
    PKG_INSTALLER="pkg"
    PKG_HINT_NODE="pkg install nodejs"
    PKG_HINT_PY="pkg install python"
    PKG_HINT_GIT="pkg install git"
elif command -v pkg >/dev/null 2>&1 && uname -a 2>/dev/null | grep -qi android; then
    PLATFORM="Termux"
    PKG_INSTALLER="pkg"
    PKG_HINT_NODE="pkg install nodejs"
    PKG_HINT_PY="pkg install python"
    PKG_HINT_GIT="pkg install git"
else
    case "$(uname -s 2>/dev/null)" in
        Linux*)
            PLATFORM="Linux"
            if command -v apt-get >/dev/null 2>&1; then
                PKG_INSTALLER="apt"
                PKG_HINT_NODE="sudo apt install nodejs"
                PKG_HINT_PY="sudo apt install python3"
                PKG_HINT_GIT="sudo apt install git"
            elif command -v dnf >/dev/null 2>&1; then
                PKG_INSTALLER="dnf"
                PKG_HINT_NODE="sudo dnf install nodejs"
                PKG_HINT_PY="sudo dnf install python3"
                PKG_HINT_GIT="sudo dnf install git"
            elif command -v pacman >/dev/null 2>&1; then
                PKG_INSTALLER="pacman"
                PKG_HINT_NODE="sudo pacman -S nodejs"
                PKG_HINT_PY="sudo pacman -S python"
                PKG_HINT_GIT="sudo pacman -S git"
            fi
            ;;
        Darwin*)
            PLATFORM="macOS"
            PKG_INSTALLER="brew"
            PKG_HINT_NODE="brew install node"
            PKG_HINT_PY="brew install python"
            PKG_HINT_GIT="brew install git"
            ;;
    esac
fi

# --- paths ------------------------------------------------------------------
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
TRITIUM_HOME="${TRITIUM_HOME:-$HOME/.tritium-os}"
BIN_DIR="$TRITIUM_HOME/bin"
STATE_DIR="$TRITIUM_HOME/state"
KEYS_DIR="$TRITIUM_HOME/keys"
LEDGER_DIR="$TRITIUM_HOME/ledger"
LEDGER_DB="$LEDGER_DIR/ledger.db"
REPO_ROOT_FILE="$STATE_DIR/repo-root"
ENV_FILE="$STATE_DIR/env"

AGENTS=(bridge jesse lux nova robert rook scout sol vex)
MAILBOX_ROOT="$REPO_ROOT/world/social/mailbox"
REPO_ON_SHARED_STORAGE=0
case "$REPO_ROOT" in
    /storage/*|/sdcard/*|/mnt/sdcard/*) REPO_ON_SHARED_STORAGE=1 ;;
esac

V41_SCRIPTS="tritium-crypt tritium-open tritium-close tritium-cp tritium-doctor tier-auto tritium-id tritium-authorize"
HELPER_SCRIPTS="tritium setup-ledger.py new-agent.sh new-agent.ps1 package.sh package.ps1 install-adapter.sh install-adapter.ps1 runtime-deps.sh"

_log ""
_log "+--- Tritium OS v${VERSION} install ---"
_log "  Platform   : $PLATFORM"
_log "  Repo       : $REPO_ROOT"
_log "  Tritium home: $TRITIUM_HOME"
_log "  Profile    : $PROFILE"
[ "$DRY" -eq 1 ] && _log "  Mode       : DRY-RUN (no changes will be made)"
if [ "$REPO_ON_SHARED_STORAGE" -eq 1 ]; then
    _warn "runtime/server npm ci may fail here because npm needs node_modules/.bin symlinks. Use bash scripts/runtime-deps.sh ensure to stage the runtime under \$HOME/.tritium-os before running doctor or serve."
fi

# --- requirements check -----------------------------------------------------
NODE_STATUS="MISSING"
NODE_VER=""
PY_STATUS="MISSING"
PY_VER=""
PY_BIN=""
GIT_STATUS="MISSING"
GIT_VER=""

if command -v node >/dev/null 2>&1; then
    NODE_VER="$(node --version 2>/dev/null | sed 's/^v//')"
    if _ver_ge "$NODE_VER" 20; then
        NODE_STATUS="OK"
    else
        NODE_STATUS="OLD"
    fi
fi

if command -v python3 >/dev/null 2>&1; then
    PY_BIN="python3"
    PY_VER="$(python3 -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])' 2>/dev/null || echo "")"
elif command -v python >/dev/null 2>&1; then
    PY_BIN="python"
    PY_VER="$(python -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])' 2>/dev/null || echo "")"
fi
if [ -n "$PY_VER" ]; then
    PY_MAJOR="$(printf '%s' "$PY_VER" | awk -F. '{print $1+0}')"
    PY_MINOR="$(printf '%s' "$PY_VER" | awk -F. '{print $2+0}')"
    if [ "$PY_MAJOR" -gt 3 ] || { [ "$PY_MAJOR" -eq 3 ] && [ "$PY_MINOR" -ge 11 ]; }; then
        PY_STATUS="OK"
    else
        PY_STATUS="OLD"
    fi
fi

if command -v git >/dev/null 2>&1; then
    GIT_VER="$(git --version 2>/dev/null | awk '{print $3}')"
    GIT_STATUS="OK"
fi

# --- optional: install missing system deps ----------------------------------
if [ "$INSTALL_DEPS" -eq 1 ] && [ -n "$PKG_INSTALLER" ]; then
    _log ""
    _log "[deps] --install-deps requested (using: $PKG_INSTALLER)"
    case "$PKG_INSTALLER" in
        apt)
            _run sudo apt-get update -y || true
            [ "$NODE_STATUS" != "OK" ] && _run sudo apt-get install -y nodejs npm || true
            [ "$PY_STATUS"   != "OK" ] && _run sudo apt-get install -y python3 python3-pip || true
            [ "$GIT_STATUS"  != "OK" ] && _run sudo apt-get install -y git || true
            ;;
        dnf)
            [ "$NODE_STATUS" != "OK" ] && _run sudo dnf install -y nodejs || true
            [ "$PY_STATUS"   != "OK" ] && _run sudo dnf install -y python3 python3-pip || true
            [ "$GIT_STATUS"  != "OK" ] && _run sudo dnf install -y git || true
            ;;
        pacman)
            [ "$NODE_STATUS" != "OK" ] && _run sudo pacman -S --noconfirm nodejs npm || true
            [ "$PY_STATUS"   != "OK" ] && _run sudo pacman -S --noconfirm python python-pip || true
            [ "$GIT_STATUS"  != "OK" ] && _run sudo pacman -S --noconfirm git || true
            ;;
        brew)
            [ "$NODE_STATUS" != "OK" ] && _run brew install node || true
            [ "$PY_STATUS"   != "OK" ] && _run brew install python || true
            [ "$GIT_STATUS"  != "OK" ] && _run brew install git || true
            ;;
        pkg)
            [ "$NODE_STATUS" != "OK" ] && _run pkg install -y nodejs || true
            [ "$PY_STATUS"   != "OK" ] && _run pkg install -y python || true
            [ "$GIT_STATUS"  != "OK" ] && _run pkg install -y git || true
            ;;
    esac
elif [ "$INSTALL_DEPS" -eq 1 ]; then
    _warn "--install-deps requested but no supported package manager detected; skipping."
fi

# --- directories ------------------------------------------------------------
_log ""
_log "[1/5] Tritium home directories"
for d in "$TRITIUM_HOME" "$BIN_DIR" "$STATE_DIR" "$KEYS_DIR" "$LEDGER_DIR"; do
    if [ -d "$d" ]; then
        _log "  exists $d"
    else
        _log "  mkdir  $d"
        _run mkdir -p "$d"
    fi
done
if [ "$DRY" -eq 1 ]; then
    _log "  [dry] record repo root -> $REPO_ROOT_FILE"
else
    printf '%s\n' "$REPO_ROOT" > "$REPO_ROOT_FILE"
    _log "  repo   $REPO_ROOT_FILE"
fi

# --- ledger DB --------------------------------------------------------------
LEDGER_STATUS="missing"
_log ""
_log "[2/5] Ledger DB"
if [ -f "$LEDGER_DB" ]; then
    LEDGER_STATUS="exists"
    _log "  exists $LEDGER_DB"
elif [ "$PY_STATUS" = "OK" ] && [ -f "$REPO_ROOT/scripts/setup-ledger.py" ]; then
    if [ "$DRY" -eq 1 ]; then
        _log "  [dry] $PY_BIN $REPO_ROOT/scripts/setup-ledger.py $LEDGER_DB"
        LEDGER_STATUS="initialized (dry)"
    else
        if "$PY_BIN" "$REPO_ROOT/scripts/setup-ledger.py" "$LEDGER_DB" >/dev/null 2>&1; then
            LEDGER_STATUS="initialized"
            _log "  initialized $LEDGER_DB"
        else
            LEDGER_STATUS="failed"
            _warn "ledger init failed"
        fi
    fi
else
    _warn "cannot init ledger (python missing or setup-ledger.py absent)"
fi

# --- copy utility scripts to bin -------------------------------------------
_log ""
_log "[3/5] Utility scripts -> $BIN_DIR"
_copy_one() {
    local name="$1"
    local src="$HERE/$name"
    local dst="$BIN_DIR/$name"
    if [ ! -f "$src" ]; then
        _log "  [skip] $name not found in scripts/"
        return
    fi
    if [ -f "$dst" ] && [ "$FORCE" -eq 0 ]; then
        if cmp -s "$src" "$dst"; then
            _log "  same   $name"
            return
        fi
        _run cp "$dst" "$dst.bak"
        _log "  backup $name -> $name.bak"
    fi
    _run cp "$src" "$dst"
    _run chmod +x "$dst" 2>/dev/null || true
    _log "  copy   $name"
}
for s in $V41_SCRIPTS $HELPER_SCRIPTS; do
    _copy_one "$s"
done

# --- agent mailboxes --------------------------------------------------------
_log ""
_log "[4/5] Agent mailboxes -> $MAILBOX_ROOT"
MAILBOX_PRESENT=0
if [ "$DRY" -eq 0 ]; then
    mkdir -p "$MAILBOX_ROOT"
fi
for a in "${AGENTS[@]}"; do
    d="$MAILBOX_ROOT/$a"
    if [ -d "$d" ]; then
        MAILBOX_PRESENT=$((MAILBOX_PRESENT + 1))
        _log "  exists $a"
    else
        _log "  mkdir  $a"
        _run mkdir -p "$d"
        MAILBOX_PRESENT=$((MAILBOX_PRESENT + 1))
    fi
done

# --- optional integrations --------------------------------------------------
_log ""
_log "[5/5] Optional integrations"

CLAUDE_VER=""
GEMINI_VER=""
COPILOT_VER=""
LMSTUDIO_STATUS="not detected"

if [ "$PROFILE" = "full" ]; then
    _log "  profile=full (only the --with-* flags you passed will run)"
fi

if command -v claude >/dev/null 2>&1; then
    CLAUDE_VER="$(claude --version 2>/dev/null | head -1 | awk '{print $NF}' || true)"
fi
if [ "$WITH_CLAUDE" -eq 1 ]; then
    if [ -z "$CLAUDE_VER" ]; then
        if command -v npm >/dev/null 2>&1; then
            _log "  installing Claude CLI (npm i -g @anthropic-ai/claude-cli)"
            _run npm install -g @anthropic-ai/claude-cli || _warn "Claude CLI install failed"
            command -v claude >/dev/null 2>&1 && CLAUDE_VER="$(claude --version 2>/dev/null | head -1 | awk '{print $NF}' || true)"
        else
            _warn "npm not found; cannot install Claude CLI"
        fi
    else
        _log "  Claude CLI present ($CLAUDE_VER)"
    fi
fi

if command -v gemini >/dev/null 2>&1; then
    GEMINI_VER="$(gemini --version 2>/dev/null | head -1 | awk '{print $NF}' || true)"
fi
if [ "$WITH_GEMINI" -eq 1 ]; then
    if [ -z "$GEMINI_VER" ]; then
        if command -v npm >/dev/null 2>&1; then
            _log "  installing Gemini CLI (npm i -g @google/gemini-cli)"
            _run npm install -g @google/gemini-cli || _warn "Gemini CLI install failed"
            command -v gemini >/dev/null 2>&1 && GEMINI_VER="$(gemini --version 2>/dev/null | head -1 | awk '{print $NF}' || true)"
        else
            _warn "npm not found; cannot install Gemini CLI"
        fi
    else
        _log "  Gemini CLI present ($GEMINI_VER)"
    fi
fi

if command -v gh >/dev/null 2>&1 && gh extension list 2>/dev/null | grep -q gh-copilot; then
    COPILOT_VER="$(gh copilot --version 2>/dev/null | head -1 | awk '{print $NF}' || true)"
elif command -v copilot >/dev/null 2>&1; then
    COPILOT_VER="$(copilot --version 2>/dev/null | head -1 | awk '{print $NF}' || true)"
fi
if [ "$WITH_COPILOT" -eq 1 ]; then
    if [ -z "$COPILOT_VER" ]; then
        if command -v gh >/dev/null 2>&1; then
            _log "  installing Copilot CLI (gh extension install github/gh-copilot)"
            _run gh extension install github/gh-copilot || _warn "Copilot CLI install failed"
            COPILOT_VER="$(gh copilot --version 2>/dev/null | head -1 | awk '{print $NF}' || true)"
        elif command -v npm >/dev/null 2>&1; then
            _log "  installing Copilot CLI (npm i -g @github/copilot)"
            _run npm install -g @github/copilot || _warn "Copilot CLI install failed"
            command -v copilot >/dev/null 2>&1 && COPILOT_VER="$(copilot --version 2>/dev/null | head -1 | awk '{print $NF}' || true)"
        else
            _warn "neither gh nor npm found; cannot install Copilot CLI"
        fi
    else
        _log "  Copilot CLI present ($COPILOT_VER)"
    fi
fi

if [ "$WITH_LMSTUDIO" -eq 1 ]; then
    LM_URL="http://localhost:1234/v1/models"
    if command -v curl >/dev/null 2>&1; then
        if curl -fsS -m 3 "$LM_URL" >/dev/null 2>&1; then
            LMSTUDIO_STATUS="reachable at http://localhost:1234"
            if [ "$DRY" -eq 0 ]; then
                mkdir -p "$STATE_DIR"
                if [ -f "$ENV_FILE" ] && grep -q '^LM_STUDIO_BASE_URL=' "$ENV_FILE"; then
                    :
                else
                    printf 'LM_STUDIO_BASE_URL=http://localhost:1234/v1\n' >> "$ENV_FILE"
                fi
                _log "  wrote LM_STUDIO_BASE_URL to $ENV_FILE"
            else
                _log "  [dry] would write LM_STUDIO_BASE_URL=http://localhost:1234/v1 to $ENV_FILE"
            fi
        else
            _log "  LM Studio not reachable at $LM_URL"
            _log "  start LM Studio desktop app and enable the local server (1234)."
        fi
    else
        _warn "curl not available; cannot probe LM Studio"
    fi
fi

# --- adapter file counts (informational) ------------------------------------
_count_agents() {
    local dir="$REPO_ROOT/adapters/$1/agents"
    if [ -d "$dir" ]; then
        find "$dir" -maxdepth 1 -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' '
    else
        echo 0
    fi
}
_count_copilot_local() {
    local dir="$REPO_ROOT/adapters/github-copilot-local/.github/agents"
    if [ -d "$dir" ]; then
        find "$dir" -maxdepth 1 -type f -name '*.agent.md' 2>/dev/null | wc -l | tr -d ' '
    else
        echo 0
    fi
}
CLAUDE_AGENT_COUNT="$(_count_agents claude-cli)"
GEMINI_AGENT_COUNT="$(_count_agents gemini-cli)"
COPILOT_AGENT_COUNT="$(_count_copilot_local)"

# --- summary ----------------------------------------------------------------
_status_line() {
    local label="$1" status="$2" ver="$3" hint="$4"
    case "$status" in
        OK)  printf '%-12s found %s\n' "$label" "$ver" ;;
        OLD) printf '%-12s found %s (TOO OLD) -- run: %s\n' "$label" "$ver" "$hint" ;;
        *)   printf '%-12s MISSING -- run: %s\n' "$label" "$hint" ;;
    esac
}

OVERALL="READY"
[ "$NODE_STATUS" != "OK" ] && OVERALL="INCOMPLETE"
[ "$PY_STATUS"   != "OK" ] && OVERALL="INCOMPLETE"
[ "$GIT_STATUS"  != "OK" ] && OVERALL="INCOMPLETE"

if [ "$QUIET" -eq 0 ]; then
    echo ""
    echo "Tritium-OS install summary"
    echo "- Platform: $PLATFORM"
    printf -- "- "; _status_line "Node:"   "$NODE_STATUS" "v$NODE_VER" "${PKG_HINT_NODE:-install Node 20+}"
    printf -- "- "; _status_line "Python:" "$PY_STATUS"   "$PY_VER"    "${PKG_HINT_PY:-install Python 3.11+}"
    printf -- "- "; _status_line "Git:"    "$GIT_STATUS"  "$GIT_VER"   "${PKG_HINT_GIT:-install git}"
    if [ -d "$TRITIUM_HOME" ] || [ "$DRY" -eq 1 ]; then
        if [ -d "$TRITIUM_HOME" ]; then
            echo "- Tritium home: $TRITIUM_HOME (exists)"
        else
            echo "- Tritium home: $TRITIUM_HOME (created)"
        fi
    fi
    echo "- Ledger:   $LEDGER_STATUS"
    echo "- Mailboxes: $MAILBOX_PRESENT/9 present"
    echo "- Adapters: claude-cli $CLAUDE_AGENT_COUNT/9, gemini-cli $GEMINI_AGENT_COUNT/9, copilot-local $COPILOT_AGENT_COUNT/9"
    echo "- Optional integrations:"
    if [ -n "$CLAUDE_VER" ]; then
        echo "    Claude CLI:  found $CLAUDE_VER"
    else
        echo "    Claude CLI:  not found -- run: bash scripts/install.sh --with-claude"
    fi
    if [ -n "$GEMINI_VER" ]; then
        echo "    Gemini CLI:  found $GEMINI_VER"
    else
        echo "    Gemini CLI:  not found -- run: bash scripts/install.sh --with-gemini"
    fi
    if [ -n "$COPILOT_VER" ]; then
        echo "    Copilot CLI: found $COPILOT_VER"
    else
        echo "    Copilot CLI: not found -- run: bash scripts/install.sh --with-copilot"
    fi
    echo "    LM Studio:   $LMSTUDIO_STATUS"
    echo "- Status: $OVERALL"
fi

exit 0
