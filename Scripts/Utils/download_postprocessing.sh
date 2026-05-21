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
REMOTE_ROOT="/home/parmghai/links/scratch/MIE498/final_data/simulation"
REMOTE_USER="parmghai"
REMOTE_HOST="rorqual.alliancecan.ca"
LOCAL_DEST="/home/proparm/OneDrive/Year 4/MIE498/Data/sims"

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
 
REMOTE_ROOT="${REMOTE_ROOT%/}"
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
 
echo "Connecting to $REMOTE (you will be prompted for 2FA once)..."
ssh $SSH_OPTS "$REMOTE" -o BatchMode=no true
 
echo ""
echo "Remote source : $REMOTE:$REMOTE_ROOT"
echo "Local dest    : $LOCAL_DEST"
echo "Syncing       : postProcessing folders, job_runtime.txt files"
echo "Skipping      : purely numeric timestep dirs, constant, system, processor*, log, log.*"
echo "──────────────────────────────────────────────────────────"
 
# ── Helper: run find on remote, pruning OpenFOAM internal dirs ───────────────
remote_find() {
    local type="$1"   # -type f or -type d
    local name="$2"   # e.g. postProcessing or job_runtime.txt
    ssh $SSH_OPTS "$REMOTE" "find '$REMOTE_ROOT' \
        -type d \( \
            -regex '.*/[0-9][0-9eE.+-]*' \
            -o -name 'constant' \
            -o -name 'system' \
            -o -name 'processor*' \
            -o -name 'log' \
            -o -name 'log.*' \
        \) -prune \
        -o $type -name '$name' -print" \
    | tr -d '\r'
}
 
# ── Discover postProcessing folders ──────────────────────────────────────────
PP_DIRS=()
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    PP_DIRS+=("$line")
done < <(remote_find "-type d" "postProcessing")
 
# ── Discover job_runtime.txt files ───────────────────────────────────────────
RUNTIME_FILES=()
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    RUNTIME_FILES+=("$line")
done < <(remote_find "-type f" "job_runtime.txt")
 
echo "Found ${#PP_DIRS[@]} postProcessing folder(s) and ${#RUNTIME_FILES[@]} job_runtime.txt file(s)."
echo ""
 
found=0
failed=0
 
# ── Rsync postProcessing folders ─────────────────────────────────────────────
for pp_dir in "${PP_DIRS[@]}"; do
    rel_path="${pp_dir#"$REMOTE_ROOT"/}"
    dest_parent="$LOCAL_DEST/$(dirname "$rel_path")"
    mkdir -p "$dest_parent"
 
    echo "Syncing dir : $rel_path"
    echo "  → $dest_parent/"
 
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
 
# ── Rsync job_runtime.txt files ───────────────────────────────────────────────
for rt_file in "${RUNTIME_FILES[@]}"; do
    rel_path="${rt_file#"$REMOTE_ROOT"/}"
    dest_parent="$LOCAL_DEST/$(dirname "$rel_path")"
    mkdir -p "$dest_parent"
 
    echo "Syncing file: $rel_path"
    echo "  → $dest_parent/"
 
    rsync_exit=0
    rsync -az --info=progress2 \
        -e "ssh $SSH_OPTS" \
        "$REMOTE:$rt_file" \
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