function mkcd() {
  if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo ""
    echo "Usage: mkcd <path>"
    echo ""
    echo "Creates a directory (including intermediate parents) and cd into it."
    echo ""
    echo "Examples:"
    echo "  mkcd new-project          # Create and enter new-project/"
    echo "  mkcd a/b/c/d              # Create nested dirs and enter a/b/c/d/"
    echo "  mkcd ~/work/my-app        # Works with absolute paths too"
    echo ""
    return 0
  fi

  if [[ $# -eq 0 ]]; then
    printf '  \033[31m✕\033[0m No path specified. Run "mkcd --help" for usage.\n' >&2
    return 1
  fi

  local existed=false
  [[ -d "$1" ]] && existed=true

  if ! mkdir -p "$1" 2>/dev/null; then
    printf '  \033[31m✕\033[0m Failed to create directory: %s\n' "$1" >&2
    return 1
  fi

  cd "$1" || return 1

  echo ""
  if $existed; then
    printf '  \033[32m✓\033[0m Moved to %s\n' "$(pwd)"
  else
    printf '  \033[32m✓\033[0m Created and moved to %s\n' "$(pwd)"
  fi
  echo ""
}
