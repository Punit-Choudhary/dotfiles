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
    printf '\033[31m✕\033[0m No files specified. Run "del --help" for usage.\n' >&2
    return 1
  fi

  local -a valid=()
  local errors=0

  for item in "$@"; do
    if [[ ! -e "$item" && ! -L "$item" ]]; then
      ((errors++))
      continue
    fi
    valid+=("$item")
  done

  local trashed=0
  if [[ ${#valid[@]} -gt 0 ]]; then
    if /usr/bin/trash "${valid[@]}" 2>/dev/null; then
      trashed=${#valid[@]}
    else
      printf '\033[31m✕ Trash operation failed.\033[0m\n' >&2
      return 1
    fi
  fi

  if (( trashed > 0 && errors == 0 )); then
    printf '\033[32m🗑️  %d item%s trashed\033[0m\n' "$trashed" "$( (( trashed > 1 )) && echo 's')"
  elif (( trashed > 0 && errors > 0 )); then
    printf '\033[32m🗑️  %d trashed\033[0m, \033[31m%d not found\033[0m\n' "$trashed" "$errors"
  else
    printf '\033[31m✕ %d item%s not found\033[0m\n' "$errors" "$( (( errors > 1 )) && echo 's')" >&2
    return 1
  fi
}
