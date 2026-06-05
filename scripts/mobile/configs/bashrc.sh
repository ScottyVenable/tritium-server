#!/usr/bin/env bash
# Tritium Team v4.1 -- scripts/mobile/configs/bashrc.sh
# Source this from ~/.bashrc on Termux / Android to activate the Tritium CLI.
# Designed for Android shared storage constraints: no POSIX chmod, safe paths.

# -- Paths ----------------------------------------------------------------
export TRITIUM_HOME="${TRITIUM_HOME:-$HOME/.tritium-team}"
export TRITIUM_BIN="$TRITIUM_HOME/bin"
export TRITIUM_VAULT_DIR="${TRITIUM_VAULT_DIR:-$HOME/storage/shared/Coding/tritium_os/world_vault}"
export TRITIUM_MIRROR_DIR="${TRITIUM_MIRROR_DIR:-$HOME/storage/shared/Coding/tritium_os/.tritium_mirror}"
export TRITIUM_LEDGER_DB="${TRITIUM_LEDGER_DB:-$TRITIUM_HOME/ledger/ledger.db}"

# Add tritium bin to PATH if not already there
case ":$PATH:" in
  *":$TRITIUM_BIN:"*) ;;
  *) export PATH="$TRITIUM_BIN:$PATH" ;;
esac

# -- Aliases --------------------------------------------------------------
alias tc='python3 "$TRITIUM_BIN/tritium-crypt"'
alias tcp='python3 "$TRITIUM_BIN/tritium-cp"'
alias tdr='bash "$TRITIUM_BIN/tritium-doctor"'
alias ton='bash "$TRITIUM_BIN/tritium-open"'
alias tcl='bash "$TRITIUM_BIN/tritium-close"'
alias ta='bash "$TRITIUM_BIN/tier-auto"'
alias tid='bash "$TRITIUM_BIN/tritium-id"'

# -- Shield check (non-blocking) ------------------------------------------
_check_shield() {
    local sf="$TRITIUM_HOME/state/shield.ok"
    if [ -f "$sf" ]; then
        local now; now=$(date +%s)
        local mtime; mtime=$(stat -c %Y "$sf" 2>/dev/null || echo "$now")
        local age=$(( now - mtime ))
        if [ "$age" -gt 86400 ]; then
            printf '[tritium] Shield stale (%ds). Run: tritium-authorize\n' "$age"
        fi
    fi
}
_check_shield

# -- Welcome banner (quiet if not interactive) -----------------------------
if [[ "$-" == *i* ]]; then
    tier_file="$TRITIUM_HOME/state/current_tier"
    tier="$([ -f "$tier_file" ] && cat "$tier_file" || echo 0)"
    agents=("scout" "bridge" "sol" "rook")
    agent="${agents[$tier]:-unknown}"
    printf 'Tritium Team v4.1  |  agent=%s (T%s)  |  %s\n' \
        "$agent" "$tier" "$(date '+%Y-%m-%d %H:%M')"
fi
