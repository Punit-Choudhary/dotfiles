function del() {
  if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo ""
    echo "Usage: del <file_or_folder> [...]"
    echo ""
    echo "Moves files and folders to the macOS Trash."
    echo ""
    echo "Examples:"
    echo "  del file.txt             # Trash a single file"
    echo "  del *.log                # Trash all .log files"
    echo "  del dir1 dir2 file.txt   # Trash multiple items"
    echo ""
    return 0
  fi

  if [[ $# -eq 0 ]]; then
    printf '  \033[31m✕\033[0m No files specified. Run "del --help" for usage.\n' >&2
    return 1
  fi

  local -a valid=()
  local errors=0

  for item in "$@"; do
    if [[ ! -e "$item" && ! -L "$item" ]]; then
      printf '  \033[31m✕\033[0m %s does not exist\n' "$item" >&2
      ((errors++))
      continue
    fi
    valid+=("$item")
  done

  if [[ ${#valid[@]} -eq 0 ]]; then
    return 1
  fi

  echo ""
  if /usr/bin/trash "${valid[@]}" 2>/dev/null; then
    for item in "${valid[@]}"; do
      printf '  \033[32m✓\033[0m %s\n' "$item"
    done
    echo ""
    local count=${#valid[@]}
    printf '  \033[32m🗑️  Trashed %d item%s.\033[0m\n' "$count" "$( (( count > 1 )) && echo 's')"
  else
    printf '  \033[31m✕ Trash operation failed.\033[0m\n' >&2
    return 1
  fi

  if [[ $errors -gt 0 ]]; then
    printf '  \033[2m(%d item%s not found)\033[0m\n' "$errors" "$( (( errors > 1 )) && echo 's')"
  fi
  echo ""
}
