#!/bin/bash

function cleanup-dsstore() {
  local target_dir="$1"

  if [[ "$target_dir" == "-h" || "$target_dir" == "--help" ]]; then
    echo ""
    echo "Usage: cleanup-dsstore [directory]"
    echo ""
    echo "Cleans all .DS_Store files recursively in the specified directory."
    echo "If no directory is specified, it cleans the current directory."
    echo ""
    echo "Examples:"
    echo "  cleanup-dsstore          # Clean .DS_Store in current directory"
    echo "  cleanup-dsstore ~/Desktop # Clean .DS_Store on Desktop"
    echo ""
    return 0
  fi

  # Default to current directory if none specified
  if [[ -z "$target_dir" ]]; then
    target_dir="."
  fi

  # Check if directory exists
  if [[ ! -d "$target_dir" ]]; then
    echo "❌ Error: '$target_dir' is not a valid directory."
    return 1
  fi

  echo "🧹 Cleaning .DS_Store files in: $target_dir"
  local count=$(find "$target_dir" -name '*.DS_Store' -type f | wc -l)

  if [[ "$count" -eq 0 ]]; then
    echo "✅ No .DS_Store files found."
  else
    find "$target_dir" -name '*.DS_Store' -type f -delete
    echo "✅ Removed $count .DS_Store files."
  fi
}
