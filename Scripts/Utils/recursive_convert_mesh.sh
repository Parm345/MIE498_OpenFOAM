#!/bin/bash

# Input parameters
input_dir="$1"        # The directory containing subdirectories
input_file="$2"       # The file you want to copy into each subdirectory

# Check if the input directory exists
if [ ! -d "$input_dir" ]; then
  echo "Error: $input_dir is not a valid directory."
  exit 1
fi

# Check if the input file exists
if [ ! -f "$input_file" ]; then
  echo "Error: $input_file is not a valid file."
  exit 1
fi

# Loop through all folders (directories) in the input directory
for dir in "$input_dir"/*/; do
  # Check if it is a directory
  if [ -d "$dir" ]; then
    # Copy the input file into the directory
    cp "$input_file" "$dir"

    # Get the absolute path of the newly copied file
    new_file="$dir$(basename "$input_file")"
    # Convert to an absolute path (in case $dir doesn't have a trailing slash)
    new_file_abs=$(realpath "$new_file")

    # Change into the directory before running the script
    cd "$dir" || { echo "Failed to change directory to $dir"; exit 1; }

    # Run the provided script on the copied file
    fluent3DMeshToFoam "$new_file_abs"

    # Optionally, print what was done
    echo "Copied $input_file to $dir and ran $script_to_run on $new_file"
    cd - || exit 1
  fi
done