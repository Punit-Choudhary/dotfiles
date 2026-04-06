#!/bin/bash

function cleanup-dsstore() {
  local target_dir=""

  for arg in "$@"; do
    case "$arg" in
      -h|--help)
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
        ;;
      *) target_dir="$arg" ;;
    esac
  done

  if [[ -z "$target_dir" ]]; then
    target_dir="."
  fi

  if [[ ! -d "$target_dir" ]]; then
    echo "❌ Error: '$target_dir' is not a valid directory."
    return 1
  fi

  local count=0
  local dir_count=0
  local cols
  cols=$(tput cols 2>/dev/null || echo 80)

  # Shared state via temp files
  local state_dir
  state_dir=$(mktemp -d)
  local current_file="$state_dir/current"
  local found_file="$state_dir/found"
  local done_file="$state_dir/done"
  : > "$current_file"
  : > "$found_file"

  # Hide cursor
  printf '\033[?25l'

  # Suppress zsh/bash job control messages ([1] 12345 / [1]+ Done ...)
  local _had_monitor=false
  if [[ -o monitor ]] 2>/dev/null; then
    _had_monitor=true
    set +m
  fi

  local renderer_pid=""
  trap 'kill "$renderer_pid" 2>/dev/null; wait "$renderer_pid" 2>/dev/null; printf "\r\033[2K\033[?25h"; $_had_monitor && set -m; rm -rf "$state_dir"; trap - INT; return 130' INT

  echo ""
  printf '  \033[1;36m🧹 Cleaning .DS_Store files in: %s\033[0m\n' "$target_dir"
  echo ""

  # Background renderer — runs on a fixed 80ms timer, independent of find
  (
    trap 'exit 0' TERM
    i=0
    seen=0
    ml=$((cols - 20))

    while true; do
      [[ -f "$done_file" ]] && break

      # Pick spinner frame
      case $((i % 10)) in
        0) s='⠋';; 1) s='⠙';; 2) s='⠹';; 3) s='⠸';; 4) s='⠼';;
        5) s='⠴';; 6) s='⠦';; 7) s='⠧';; 8) s='⠇';; 9) s='⠏';;
      esac
      i=$((i + 1))

      # Render any newly found files above the spinner line
      total=$(wc -l < "$found_file" 2>/dev/null)
      total=${total//[[:space:]]/}
      total=${total:-0}
      if [ "$total" -gt "$seen" ] 2>/dev/null; then
        tail -n +$((seen + 1)) "$found_file" 2>/dev/null | while IFS= read -r line; do
          [ -n "$line" ] && printf '\r\033[2K  \033[31m✕\033[0m %s\n' "$line"
        done
        seen=$total
      fi

      # Animate spinner with current directory
      dir=$(cat "$current_file" 2>/dev/null)
      dd="$dir"
      if [ "$ml" -gt 0 ] 2>/dev/null && [ "${#dd}" -gt "$ml" ] 2>/dev/null; then
        dd="…${dd: -$ml}"
      fi
      printf '\r\033[2K  \033[36m%s\033[0m \033[2mScanning %s\033[0m' "$s" "$dd"

      sleep 0.08
    done

    # Final flush — render any remaining found files
    total=$(wc -l < "$found_file" 2>/dev/null)
    total=${total//[[:space:]]/}
    total=${total:-0}
    if [ "$total" -gt "$seen" ] 2>/dev/null; then
      tail -n +$((seen + 1)) "$found_file" 2>/dev/null | while IFS= read -r line; do
        [ -n "$line" ] && printf '\r\033[2K  \033[31m✕\033[0m %s\n' "$line"
      done
    fi
    printf '\r\033[2K'
  ) &
  renderer_pid=$!

  # Main worker loop — scans and deletes, updates state files
  while IFS= read -r -d '' dir; do
    ((dir_count++))
    printf '%s' "$dir" > "$current_file"

    if [[ -f "$dir/.DS_Store" ]]; then
      rm "$dir/.DS_Store"
      ((count++))
      printf '\033[2m%s/\033[0m.DS_Store\n' "$dir" >> "$found_file"
    fi
  done < <(find "$target_dir" -type d -print0 2>/dev/null)

  # Signal renderer to stop and wait for it
  touch "$done_file"
  wait "$renderer_pid" 2>/dev/null
  renderer_pid=""

  # Restore cursor, job control, clean up
  printf '\033[?25h'
  $_had_monitor && set -m
  trap - INT
  rm -rf "$state_dir"

  # Summary
  printf '  \033[2mScanned %d directories\033[0m\n' "$dir_count"
  echo ""
  if [[ "$count" -eq 0 ]]; then
    printf '  \033[32m✅ No .DS_Store files found.\033[0m\n'
  else
    printf '  \033[32m✅ Removed %d .DS_Store file%s.\033[0m\n' "$count" "$( (( count > 1 )) && echo 's')"
  fi
  echo ""
}
