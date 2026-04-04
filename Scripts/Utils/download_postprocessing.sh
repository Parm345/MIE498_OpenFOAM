#!/bin/bash
# sync_postProcessing.sh
# Run on your LOCAL machine to pull postProcessing folders from the remote server.
# Requires rsync and SSH key access to the remote.
#
# Usage:
#   ./sync_postProcessing.sh -s <remote_source_root> -u <remote_user> -h <remote_host> -d <local_dest>
#
# Options:
#   -s  Source root on the remote server (e.g. /data/simulations)
#   -u  Remote username (e.g. john)
#   -h  Remote hostname or IP (e.g. hpc.university.edu)
#   -d  Local destination root (e.g. /home/john/simulations)
#
# Example:
#   ./sync_postProcessing.sh -s /data/simulations -u john -h hpc.university.edu -d ~/simulations

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
REMOTE_ROOT=""
REMOTE_USER=""
REMOTE_HOST="rorqual.alliancecan.ca"
LOCAL_DEST=""

# ── Argument parsing ──────────────────────────────────────────────────────────
while getopts "s:u:h:d:" opt; do
    case $opt in
        s) REMOTE_ROOT="$OPTARG" ;;
        u) REMOTE_USER="$OPTARG" ;;
        h) REMOTE_HOST="$OPTARG" ;;
        d) LOCAL_DEST="$OPTARG" ;;
        *) echo "Unknown option: -$opt"; exit 1 ;;
    esac
done
 
# ── Validation ────────────────────────────────────────────────────────────────
if [[ -z "$REMOTE_ROOT" || -z "$REMOTE_USER" || -z "$REMOTE_HOST" || -z "$LOCAL_DEST" ]]; then
    echo "Error: all options are required."
    echo "Usage: $0 -s <remote_root> -u <remote_user> -h <remote_host> -d <local_dest>"
    exit 1
fi
 
# Strip trailing slash from remote root for consistent prefix stripping later
REMOTE_ROOT="${REMOTE_ROOT%/}"
# Expand ~ in local dest
LOCAL_DEST="${LOCAL_DEST/#\~/$HOME}"
 
REMOTE="$REMOTE_USER@$REMOTE_HOST"
 
# ── SSH ControlMaster setup ───────────────────────────────────────────────────
SOCKET=$(mktemp -u /tmp/ssh_ctrl_XXXXXX)
SSH_OPTS="-o ControlMaster=auto -o ControlPath=$SOCKET -o ControlPersist=yes"
 
cleanup() {
    echo ""
    echo "Closing SSH master connection..."
    ssh -O exit -o ControlPath="$SOCKET" "$REMOTE" 2>/dev/null || true
    rm -f "$SOCKET"
}
trap cleanup EXIT
 
# Open the master connection (only 2FA prompt)
echo "Connecting to $REMOTE (you will be prompted for 2FA once)..."
ssh $SSH_OPTS "$REMOTE" -o BatchMode=no true
 
echo ""
echo "Remote source : $REMOTE:$REMOTE_ROOT"
echo "Local dest    : $LOCAL_DEST"
echo "Skipping      : timestep dirs, constant, system, 0, processor*, log, log.*"
echo "──────────────────────────────────────────────────────────"
 
# ── Discover postProcessing folders on the remote ─────────────────────────────
PP_DIRS=()
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    PP_DIRS+=("$line")
done < <(
    ssh $SSH_OPTS "$REMOTE" "find '$REMOTE_ROOT' \
        -type d \( \
            -name '[0-9]*' \
            -o -name 'constant' \
            -o -name 'system' \
            -o -name 'processor*' \
            -o -name 'log' \
            -o -name 'log.*' \
        \) -prune \
        -o -type d -name 'postProcessing' -print" \
    | tr -d '\r'
)
 
if [[ ${#PP_DIRS[@]} -eq 0 ]]; then
    echo "No postProcessing folders found under $REMOTE_ROOT"
    exit 0
fi
 
echo "Found ${#PP_DIRS[@]} postProcessing folder(s):"
for p in "${PP_DIRS[@]}"; do echo "  $p"; done
echo ""
 
found=0
failed=0
 
# ── Rsync each postProcessing folder ─────────────────────────────────────────
for pp_dir in "${PP_DIRS[@]}"; do
    # pp_dir is the full absolute remote path, e.g.
    #   /home/parmghai/.../sst_kw/coarse_mesh/ts0005/postProcessing
    # Strip the remote root prefix to get the relative path
    rel_path="${pp_dir#"$REMOTE_ROOT"/}"
 
    # Build the full local destination parent directory
    dest_parent="$LOCAL_DEST/$(dirname "$rel_path")"
    mkdir -p "$dest_parent"
 
    echo "Syncing: $rel_path"
    echo "  → $dest_parent/"
 
    # Use the full absolute remote path in rsync
    rsync_exit=0
    rsync -az --info=progress2 \
        -e "ssh $SSH_OPTS" \
        "$REMOTE:$pp_dir" \
        "$dest_parent/" || rsync_exit=$?
 
    if [[ $rsync_exit -eq 0 ]]; then
        echo "  ✓ Done"
        ((found++)) || true
    else
        echo "  ✗ rsync failed (exit $rsync_exit) for: $rel_path"
        ((failed++)) || true
    fi
 
    echo ""
done
 
# ── Summary ───────────────────────────────────────────────────────────────────
echo "──────────────────────────────────────────────────────────"
echo "Complete. Transferred: $found | Failed: $failed"