#!/bin/bash
# =============================================================================
# cloneCase.sh
#
# Clones an OpenFOAM case folder and sets deltaT in system/controlDict
# to the value encoded in the new folder's name.
#
# Usage:
#   ./cloneCase.sh <source_folder> <deltaT_value> [output_folder_name]
#
# Examples:
#   ./cloneCase.sh baseCase 0.01
#       → creates folder "ts0.01" with deltaT set to 0.01
#
#   ./cloneCase.sh baseCase 0.005 myCase_dt0.005
#       → creates folder "myCase_dt0.005" with deltaT set to 0.005
# =============================================================================

set -e

# ---------------- argument parsing ----------------
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <source_folder> <deltaT_value> [output_folder_name]"
    echo ""
    echo "  source_folder     : path to the OpenFOAM case to clone"
    echo "  deltaT_value      : numeric value to use for deltaT (e.g. 0.01)"
    echo "  output_folder_name: (optional) name for the new folder;"
    echo "                      defaults to the deltaT value itself"
    exit 1
fi

SOURCE="$1"
DELTAT="$2"
DEST="${3:-ts${DELTAT//0./}}"  # default destination name = "ts" + deltaT value (no leading zero or period)

# ---------------- validation ----------------------
if [[ ! -d "$SOURCE" ]]; then
    echo "ERROR: Source folder '$SOURCE' does not exist."
    exit 1
fi

CONTROLDICT="$SOURCE/system/controlDict"
if [[ ! -f "$CONTROLDICT" ]]; then
    echo "ERROR: '$CONTROLDICT' not found. Is '$SOURCE' a valid OpenFOAM case?"
    exit 1
fi

# Validate deltaT is a positive number (including scientific notation e.g. 1e-4)
if ! [[ "$DELTAT" =~ ^[0-9]*\.?[0-9]+([eE][+-]?[0-9]+)?$ ]]; then
    echo "ERROR: deltaT value '$DELTAT' does not look like a positive number."
    exit 1
fi

if [[ -d "$DEST" ]]; then
    echo "ERROR: Destination folder '$DEST' already exists. Aborting."
    exit 1
fi

# ---------------- copy ----------------------------
echo "Cloning '$SOURCE' → '$DEST' ..."
cp -r "$SOURCE" "$DEST"

# ---------------- patch controlDict ---------------
NEW_CONTROLDICT="$DEST/system/controlDict"

# Replace the deltaT line (handles various spacings, preserves semicolon)
if grep -qE '^\s*deltaT\s' "$NEW_CONTROLDICT"; then
    sed -i -E "s|^(\s*deltaT\s+)[^;]+(;)|\1$DELTAT\2|" "$NEW_CONTROLDICT"
    echo "Updated deltaT → $DELTAT  in $NEW_CONTROLDICT"
else
    echo "WARNING: 'deltaT' entry not found in controlDict."
    echo "         Please add it manually: deltaT  $DELTAT;"
fi

echo "Done. New case folder: $DEST"