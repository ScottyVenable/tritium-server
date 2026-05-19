#!/usr/bin/env bash
# Tritium runtime dependency helper.
#
# Usage:
#   bash scripts/runtime-deps.sh ensure        # install runtime deps in the right place
#   bash scripts/runtime-deps.sh path          # print the active runtime/server path
#   bash scripts/runtime-deps.sh clean         # remove the staged runtime for this repo
#
# On normal filesystems this runs `npm ci` in runtime/server.
# On Android/shared storage or filesystems that fail a symlink probe, it stages
# runtime/server under ~/.tritium-os/runtime-server/<repo-key>/, runs `npm ci`
# there, and records the staged path for runtime preflight / serve.

set -euo pipefail

QUIET=0

if [ "${1:-}" = "--quiet" ]; then
    QUIET=1
    shift
fi

COMMAND="${1:-ensure}"

_log() {
    if [ "$QUIET" -eq 0 ]; then
        printf '%s\n' "$1"
    fi
}

_die() {
    printf 'error: %s\n' "$1" >&2
    exit 1
}

_hash_text() {
    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s' "$1" | sha256sum | awk '{print $1}'
        return
    fi
    if command -v shasum >/dev/null 2>&1; then
        printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
        return
    fi
    if command -v openssl >/dev/null 2>&1; then
        printf '%s' "$1" | openssl dgst -sha256 | awk '{print $NF}'
        return
    fi
    node -e "const crypto=require('node:crypto'); process.stdout.write(crypto.createHash('sha256').update(process.argv[1]).digest('hex'));" "$1"
}

_hash_file() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
        return
    fi
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | awk '{print $1}'
        return
    fi
    if command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 "$file" | awk '{print $NF}'
        return
    fi
    node -e "const crypto=require('node:crypto'); const fs=require('node:fs'); process.stdout.write(crypto.createHash('sha256').update(fs.readFileSync(process.argv[1])).digest('hex'));" "$file"
}

_is_shared_storage_path() {
    case "$1" in
        /storage/*|/sdcard/*|/mnt/sdcard/*) return 0 ;;
        *) return 1 ;;
    esac
}

_probe_symlink_support() {
    local dir="$1"
    local probe_dir="$dir/.tritium-symlink-probe-$$"
    local target_file="$probe_dir/target"
    local link_file="$probe_dir/link"

    rm -rf "$probe_dir"
    mkdir -p "$probe_dir" >/dev/null 2>&1 || return 1
    printf 'ok\n' > "$target_file" || {
        rm -rf "$probe_dir"
        return 1
    }
    if ln -s "$target_file" "$link_file" >/dev/null 2>&1 && [ -L "$link_file" ]; then
        rm -rf "$probe_dir"
        return 0
    fi
    rm -rf "$probe_dir"
    return 1
}

_repo_root() {
    local here
    here="$(cd "$(dirname "$0")" && pwd)"
    cd "$here/.." && pwd
}

_write_stage_metadata() {
    mkdir -p "$STATE_DIR"
    node - "$REPO_ROOT" "$REPO_KEY" "$LOCK_HASH" "$STAGE_ROOT" "$RECORD_PATH" "$STAGE_MARKER" <<'NODE'
const fs = require('node:fs');
const path = require('node:path');

const [repoRoot, repoKey, lockHash, stageRoot, recordPath, markerPath] = process.argv.slice(2);
const payload = {
  version: 1,
  repoRoot,
  repoKey,
  lockHash,
  stageRoot,
  recordedAt: new Date().toISOString(),
};

fs.mkdirSync(path.dirname(recordPath), { recursive: true });
fs.mkdirSync(stageRoot, { recursive: true });
fs.writeFileSync(recordPath, `${JSON.stringify(payload, null, 2)}\n`);
fs.writeFileSync(markerPath, `${JSON.stringify(payload, null, 2)}\n`);
NODE
}

_stage_record_lock_hash() {
    if [ ! -f "$RECORD_PATH" ]; then
        return 1
    fi
    node -e "const fs=require('node:fs'); try { const parsed=JSON.parse(fs.readFileSync(process.argv[1], 'utf8')); if (parsed && parsed.lockHash) process.stdout.write(String(parsed.lockHash)); } catch {}" "$RECORD_PATH"
}

_deps_ready() {
    local dir="$1"
    if [ ! -f "$dir/package.json" ]; then
        return 1
    fi
    (
        cd "$dir"
        node -e "require.resolve('ws/package.json'); require.resolve('better-sqlite3/package.json');"
    ) >/dev/null 2>&1
}

_sync_stage_tree() {
    mkdir -p "$STAGE_ROOT"
    find "$STAGE_ROOT" -mindepth 1 -maxdepth 1 \
        ! -name node_modules \
        ! -name .tritium-runtime-stage.json \
        -exec rm -rf {} +
    find "$SERVER_REPO_ROOT" -mindepth 1 -maxdepth 1 \
        ! -name node_modules \
        -exec cp -a {} "$STAGE_ROOT/" \;
}

REPO_ROOT="$(_repo_root)"
SERVER_REPO_ROOT="$REPO_ROOT/runtime/server"
TRITIUM_HOME="${TRITIUM_HOME:-$HOME/.tritium-os}"
STATE_DIR="$TRITIUM_HOME/state/runtime-deps"
REPO_KEY="$(_hash_text "$REPO_ROOT" | cut -c1-16)"
LOCK_HASH="$(_hash_file "$SERVER_REPO_ROOT/package-lock.json")"
STAGE_ROOT="$TRITIUM_HOME/runtime-server/$REPO_KEY"
RECORD_PATH="$STATE_DIR/$REPO_KEY.json"
STAGE_MARKER="$STAGE_ROOT/.tritium-runtime-stage.json"

[ -d "$SERVER_REPO_ROOT" ] || _die "runtime/server not found under $REPO_ROOT"
[ -f "$SERVER_REPO_ROOT/package-lock.json" ] || _die "runtime/server/package-lock.json is missing"
command -v npm >/dev/null 2>&1 || _die "npm is required"
command -v node >/dev/null 2>&1 || _die "node is required"

NEEDS_WORKAROUND=0
if _is_shared_storage_path "$REPO_ROOT" || ! _probe_symlink_support "$SERVER_REPO_ROOT"; then
    NEEDS_WORKAROUND=1
fi

case "$COMMAND" in
    ensure)
        if [ "$NEEDS_WORKAROUND" -eq 0 ]; then
            _log "[tritium] runtime deps: npm ci in $SERVER_REPO_ROOT"
            (
                cd "$SERVER_REPO_ROOT"
                npm ci
            )
            if [ "$QUIET" -eq 0 ]; then
                printf '%s\n' "$SERVER_REPO_ROOT"
            fi
            exit 0
        fi

        _log "[tritium] runtime deps: staging runtime/server -> $STAGE_ROOT"
        _sync_stage_tree

        RECORDED_LOCK_HASH="$(_stage_record_lock_hash || true)"
        if [ "$RECORDED_LOCK_HASH" = "$LOCK_HASH" ] && _deps_ready "$STAGE_ROOT"; then
            _log "[tritium] runtime deps: reusing staged node_modules"
        else
            rm -rf "$STAGE_ROOT/node_modules"
            (
                cd "$STAGE_ROOT"
                npm ci
            )
        fi

        _write_stage_metadata
        if [ "$QUIET" -eq 0 ]; then
            printf '%s\n' "$STAGE_ROOT"
        fi
        ;;

    path)
        if [ "$NEEDS_WORKAROUND" -eq 1 ]; then
            printf '%s\n' "$STAGE_ROOT"
        else
            printf '%s\n' "$SERVER_REPO_ROOT"
        fi
        ;;

    clean)
        rm -rf "$STAGE_ROOT"
        rm -f "$RECORD_PATH"
        _log "[tritium] runtime deps: removed staged runtime for $REPO_ROOT"
        ;;

    *)
        _die "unknown subcommand: $COMMAND"
        ;;
esac
