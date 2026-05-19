#!/usr/bin/env bash
# Verify a Tritium-OS checkout: toolchain, repo structure, agent coverage,
# inbox CLI smoke test, and (warn-only) optional integrations.
#
# Exits 0 on PASS, 1 on FAIL. Pass --quiet to suppress per-check OK lines.

set -u

QUIET=0
for arg in "$@"; do
    case "$arg" in
        --quiet|-q) QUIET=1 ;;
        -h|--help)
            cat <<'EOF'
usage: verify.sh [--quiet]

Checks toolchain, repo layout, all 9 agents have agent.md + adapter prompts,
mailboxes exist, and the live inbox CLI works against the runtime API. Warns on
optional integrations.
EOF
            exit 0 ;;
    esac
done

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

AGENTS=(bridge sol jesse vex rook robert lux nova scout)

FAILS=()
WARNS=()

_ok()   { [ "$QUIET" -eq 0 ] && printf '  OK    %s\n' "$1"; }
_fail() { FAILS+=("$1"); printf '  FAIL  %s\n' "$1"; }
_warn() { WARNS+=("$1"); printf '  WARN  %s\n' "$1"; }

# --- toolchain --------------------------------------------------------------
NODE_VER=""
NODE_STATUS="MISSING"
if command -v node >/dev/null 2>&1; then
    NODE_VER="$(node -v 2>/dev/null | sed 's/^v//')"
    NODE_MAJOR="${NODE_VER%%.*}"
    if [ -n "$NODE_MAJOR" ] && [ "$NODE_MAJOR" -ge 20 ] 2>/dev/null; then
        NODE_STATUS="OK"; _ok "Node v$NODE_VER (>=20)"
    else
        NODE_STATUS="OLD"; _fail "Node v$NODE_VER is too old (need >=20)"
    fi
else
    _fail "Node not found on PATH (need >=20)"
fi

PY_VER=""
PY_STATUS="MISSING"
PY_BIN=""
for cand in python3 python; do
    if command -v "$cand" >/dev/null 2>&1; then
        v="$("$cand" --version 2>&1 | awk '{print $2}')"
        if [ -n "$v" ]; then PY_BIN="$cand"; PY_VER="$v"; break; fi
    fi
done
if [ -n "$PY_VER" ]; then
    PY_MAJOR="${PY_VER%%.*}"
    PY_REST="${PY_VER#*.}"
    PY_MINOR="${PY_REST%%.*}"
    if [ "$PY_MAJOR" -gt 3 ] 2>/dev/null \
        || { [ "$PY_MAJOR" -eq 3 ] 2>/dev/null && [ "$PY_MINOR" -ge 11 ] 2>/dev/null; }; then
        PY_STATUS="OK"; _ok "Python $PY_VER (>=3.11)"
    else
        PY_STATUS="OLD"; _fail "Python $PY_VER is too old (need >=3.11)"
    fi
else
    _fail "Python not found on PATH (need >=3.11)"
fi

GIT_VER=""
if command -v git >/dev/null 2>&1; then
    GIT_VER="$(git --version 2>/dev/null | awk '{print $3}')"
    _ok "git $GIT_VER"
else
    _fail "git not found on PATH"
fi

# --- repo structure ---------------------------------------------------------
_check_path() {
    local kind="$1" rel="$2"
    local p="$ROOT/$rel"
    if [ "$kind" = "f" ] && [ -f "$p" ]; then _ok "file  $rel"
    elif [ "$kind" = "d" ] && [ -d "$p" ]; then _ok "dir   $rel"
    else _fail "missing $kind $rel"
    fi
}

_check_path f runtime/cli/tritium.js
_check_path d runtime/server
_check_path d runtime/heartbeat
_check_path f data/registry/models.json

# Mailboxes
MAILBOX_PRESENT=0
for a in "${AGENTS[@]}"; do
    if [ -d "$ROOT/world/social/mailbox/$a" ]; then
        MAILBOX_PRESENT=$((MAILBOX_PRESENT + 1))
        _ok "mbox  world/social/mailbox/$a"
    else
        _fail "missing mailbox world/social/mailbox/$a"
    fi
done

# agent.md per agent
AGENT_MD_PRESENT=0
for a in "${AGENTS[@]}"; do
    if [ -f "$ROOT/agents/$a/agent.md" ]; then
        AGENT_MD_PRESENT=$((AGENT_MD_PRESENT + 1))
        _ok "agent agents/$a/agent.md"
    else
        _fail "missing agents/$a/agent.md"
    fi
done

# Adapter coverage
_capitalize() {
    local s="$1"
    printf '%s%s' "$(printf '%s' "${s:0:1}" | tr '[:lower:]' '[:upper:]')" "${s:1}"
}

CLAUDE_OK=0; GEMINI_OK=0; COPILOT_OK=0
for a in "${AGENTS[@]}"; do
    f="$ROOT/adapters/claude-cli/agents/$a.md"
    if [ -f "$f" ]; then CLAUDE_OK=$((CLAUDE_OK + 1)); _ok "adapter claude-cli/agents/$a.md"
    else _fail "missing adapters/claude-cli/agents/$a.md"; fi

    f="$ROOT/adapters/gemini-cli/agents/$a.md"
    if [ -f "$f" ]; then GEMINI_OK=$((GEMINI_OK + 1)); _ok "adapter gemini-cli/agents/$a.md"
    else _fail "missing adapters/gemini-cli/agents/$a.md"; fi

    cap="$(_capitalize "$a")"
    f="$ROOT/adapters/github-copilot-local/.github/agents/$cap.agent.md"
    if [ -f "$f" ]; then COPILOT_OK=$((COPILOT_OK + 1)); _ok "adapter github-copilot-local/.github/agents/$cap.agent.md"
    else _fail "missing adapters/github-copilot-local/.github/agents/$cap.agent.md"; fi
done

# --- inbox CLI smoke test ---------------------------------------------------
INBOX_STATUS="SKIP"
if [ "$NODE_STATUS" = "OK" ] && [ -f "$ROOT/runtime/cli/tritium.js" ]; then
    if (cd "$ROOT" && node runtime/cli/tritium.js inbox check --agent sol --require-api) >/dev/null 2>&1; then
        INBOX_STATUS="OK"; _ok "tritium inbox check --agent sol --require-api"
    else
        INBOX_STATUS="FAIL"; _fail "tritium inbox check --agent sol --require-api exited non-zero"
    fi
fi

# --- ledger (warn only) -----------------------------------------------------
LEDGER_PATH="${HOME:-$USERPROFILE}/.tritium-os/ledger/ledger.db"
if [ -f "$LEDGER_PATH" ]; then
    LEDGER_STATUS="present at $LEDGER_PATH"
    _ok "ledger $LEDGER_PATH"
else
    LEDGER_STATUS="not yet initialized -- run: bash scripts/install.sh"
    _warn "ledger not initialized at $LEDGER_PATH"
fi

# --- optional CLIs (warn only) ----------------------------------------------
CLAUDE_VER=""; GEMINI_VER=""; COPILOT_VER=""; LMSTUDIO_STATUS="not reachable"
if command -v claude >/dev/null 2>&1; then
    CLAUDE_VER="$(claude --version 2>/dev/null | head -n1)"
    _ok "claude CLI: $CLAUDE_VER"
else
    _warn "claude CLI not on PATH (optional)"
fi
if command -v gemini >/dev/null 2>&1; then
    GEMINI_VER="$(gemini --version 2>/dev/null | head -n1)"
    _ok "gemini CLI: $GEMINI_VER"
else
    _warn "gemini CLI not on PATH (optional)"
fi
if command -v copilot >/dev/null 2>&1; then
    COPILOT_VER="$(copilot --version 2>/dev/null | head -n1)"
    _ok "copilot CLI: $COPILOT_VER"
else
    _warn "copilot CLI not on PATH (optional)"
fi
if command -v curl >/dev/null 2>&1; then
    if curl -fsS -m 2 http://localhost:1234/v1/models >/dev/null 2>&1; then
        LMSTUDIO_STATUS="reachable at http://localhost:1234"
        _ok "LM Studio reachable"
    else
        _warn "LM Studio not reachable at http://localhost:1234"
    fi
else
    _warn "curl missing; cannot probe LM Studio"
fi

# --- summary ----------------------------------------------------------------
OVERALL="PASS"
[ "${#FAILS[@]}" -gt 0 ] && OVERALL="FAIL"

echo ""
echo "Tritium-OS verify summary"
if [ "$NODE_STATUS" = "OK" ]; then echo "- Node:    found v$NODE_VER"
elif [ "$NODE_STATUS" = "OLD" ]; then echo "- Node:    v$NODE_VER (TOO OLD, need >=20)"
else echo "- Node:    MISSING (need >=20)"; fi
if [ "$PY_STATUS" = "OK" ]; then echo "- Python:  found $PY_VER"
elif [ "$PY_STATUS" = "OLD" ]; then echo "- Python:  $PY_VER (TOO OLD, need >=3.11)"
else echo "- Python:  MISSING (need >=3.11)"; fi
if [ -n "$GIT_VER" ]; then echo "- Git:     found $GIT_VER"
else echo "- Git:     MISSING"; fi
echo "- Mailboxes: $MAILBOX_PRESENT/9 present"
echo "- Agent docs: $AGENT_MD_PRESENT/9 present"
echo "- Adapters: claude-cli $CLAUDE_OK/9, gemini-cli $GEMINI_OK/9, copilot-local $COPILOT_OK/9"
echo "- Inbox CLI: $INBOX_STATUS"
echo "- Ledger:  $LEDGER_STATUS"
echo "- Optional integrations:"
if [ -n "$CLAUDE_VER" ]; then  echo "    Claude CLI:  found $CLAUDE_VER";  else echo "    Claude CLI:  not found -- run: bash scripts/install.sh --with-claude"; fi
if [ -n "$GEMINI_VER" ]; then  echo "    Gemini CLI:  found $GEMINI_VER";  else echo "    Gemini CLI:  not found -- run: bash scripts/install.sh --with-gemini"; fi
if [ -n "$COPILOT_VER" ]; then echo "    Copilot CLI: found $COPILOT_VER"; else echo "    Copilot CLI: not found -- run: bash scripts/install.sh --with-copilot"; fi
echo "    LM Studio:   $LMSTUDIO_STATUS"

if [ "${#FAILS[@]}" -gt 0 ]; then
    echo ""
    echo "Failures (${#FAILS[@]}):"
    for f in "${FAILS[@]}"; do echo "  - $f"; done
fi

echo "- Status: $OVERALL — see above"

[ "$OVERALL" = "PASS" ] && exit 0 || exit 1
