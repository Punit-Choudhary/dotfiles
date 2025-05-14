function del() {
  if [[ $# -eq 0 ]] || [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "Usage: del <file_or_folder>"
    return 1
  fi
  for item in "$@"; do
    if [ ! -e "$item" ]; then
      echo "Error: '$item' does not exist."
      continue
    fi

    if ! osascript -e "tell application \"Finder\" to delete POSIX file \"$(realpath "$item")\"" >/dev/null; then
      echo "Failed to delete: $item"
    fi
  done
}
