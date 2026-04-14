function _dups_format_size() {
  awk "BEGIN{
    b=$1;
    if(b>=1073741824) printf \"%.1f GB\",b/1073741824;
    else if(b>=1048576) printf \"%.1f MB\",b/1048576;
    else if(b>=1024) printf \"%.1f KB\",b/1024;
    else printf \"%d B\",b
  }"
}

function dups() {
  local target_dir=""

  for arg in "$@"; do
    case "$arg" in
      -h|--help)
        echo ""
        echo "Usage: dups [directory]"
        echo ""
        echo "Finds duplicate files by content hash in the specified directory."
        echo "If no directory is specified, scans the current directory."
        echo ""
        echo "Examples:"
        echo "  dups                    # Find duplicates in current directory"
        echo "  dups ~/Downloads        # Find duplicates in Downloads"
        echo "  dups /Volumes/USB       # Scan an external drive"
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
    printf '  \033[31m✕\033[0m %s is not a valid directory.\n' "$target_dir" >&2
    return 1
  fi

  local file_count=0
  local cols
  cols=$(tput cols 2>/dev/null || echo 80)

  # Shared state via temp files
  local state_dir
  state_dir=$(mktemp -d)
  local current_file="$state_dir/current"
  local phase_file="$state_dir/phase"
  local fcount_file="$state_dir/fcount"
  local hcount_file="$state_dir/hcount"
  local htotal_file="$state_dir/htotal"
  local done_file="$state_dir/done"
  local sizes_file="$state_dir/sizes"
  local hashes_file="$state_dir/hashes"
  : > "$current_file"
  : > "$sizes_file"
  : > "$hashes_file"
  printf 'indexing' > "$phase_file"
  printf '0' > "$fcount_file"
  printf '0' > "$hcount_file"
  printf '0' > "$htotal_file"

  # Hide cursor
  printf '\033[?25l'

  # Suppress job control messages
  local _had_monitor=false
  if [[ -o monitor ]] 2>/dev/null; then
    _had_monitor=true
    set +m
  fi

  local renderer_pid=""
  trap 'kill "$renderer_pid" 2>/dev/null; wait "$renderer_pid" 2>/dev/null; printf "\r\033[2K\033[?25h"; $_had_monitor && set -m; rm -rf "$state_dir"; trap - INT; return 130' INT

  echo ""
  printf '  \033[1;36m🔍 Scanning for duplicates in: %s\033[0m\n' "$target_dir"
  echo ""

  # Background renderer
  (
    trap 'exit 0' TERM
    i=0
    ml=$((cols - 40))

    while true; do
      [[ -f "$done_file" ]] && break

      case $((i % 10)) in
        0) s='⠋';; 1) s='⠙';; 2) s='⠹';; 3) s='⠸';; 4) s='⠼';;
        5) s='⠴';; 6) s='⠦';; 7) s='⠧';; 8) s='⠇';; 9) s='⠏';;
      esac
      i=$((i + 1))

      phase=$(cat "$phase_file" 2>/dev/null)

      if [ "$phase" = "indexing" ]; then
        fc=$(cat "$fcount_file" 2>/dev/null)
        fc=${fc:-0}
        printf '\r\033[2K  \033[36m%s\033[0m \033[2mIndexing files... (%s found)\033[0m' "$s" "$fc"
      elif [ "$phase" = "hashing" ]; then
        hc=$(cat "$hcount_file" 2>/dev/null)
        ht=$(cat "$htotal_file" 2>/dev/null)
        hc=${hc:-0}
        ht=${ht:-0}
        cf=$(cat "$current_file" 2>/dev/null)
        dd="$cf"
        if [ "$ml" -gt 0 ] 2>/dev/null && [ "${#dd}" -gt "$ml" ] 2>/dev/null; then
          dd="…${dd: -$ml}"
        fi
        printf '\r\033[2K  \033[36m%s\033[0m \033[2mHashing %s/%s: %s\033[0m' "$s" "$hc" "$ht" "$dd"
      fi

      sleep 0.08
    done
    printf '\r\033[2K'
  ) &
  renderer_pid=$!

  # Phase 1: Index all files by size
  local size
  while IFS= read -r -d '' file; do
    ((file_count++))
    printf '%d' "$file_count" > "$fcount_file"
    size=$(stat -f%z "$file" 2>/dev/null) || continue
    printf '%s\t%s\n' "$size" "$file" >> "$sizes_file"
  done < <(find "$target_dir" -type f -not -name '.DS_Store' -print0 2>/dev/null)

  # Phase 2: Hash only files with duplicate sizes
  printf 'hashing' > "$phase_file"

  # Find sizes that appear more than once
  local dup_sizes_file="$state_dir/dup_sizes"
  awk -F'\t' '{print $1}' "$sizes_file" | sort | uniq -d > "$dup_sizes_file"

  # Count candidates
  local hash_total
  hash_total=$(awk -F'\t' 'NR==FNR{a[$1];next} ($1 in a)' "$dup_sizes_file" "$sizes_file" | wc -l)
  hash_total=${hash_total//[[:space:]]/}
  hash_total=${hash_total:-0}
  printf '%s' "$hash_total" > "$htotal_file"

  # Hash each candidate
  local hash_count=0
  local hash
  while IFS=$'\t' read -r size filepath; do
    ((hash_count++))
    printf '%d' "$hash_count" > "$hcount_file"
    printf '%s' "$filepath" > "$current_file"
    hash=$(md5 -q "$filepath" 2>/dev/null) || continue
    printf '%s\t%s\t%s\n' "$hash" "$size" "$filepath" >> "$hashes_file"
  done < <(awk -F'\t' 'NR==FNR{a[$1];next} ($1 in a){print}' "$dup_sizes_file" "$sizes_file")

  # Stop renderer
  touch "$done_file"
  wait "$renderer_pid" 2>/dev/null
  renderer_pid=""

  # Restore cursor, job control
  printf '\033[?25h'
  $_had_monitor && set -m
  trap - INT

  # Display results
  if [[ ! -s "$hashes_file" ]]; then
    printf '  \033[2mScanned %d files\033[0m\n' "$file_count"
    echo ""
    printf '  \033[32m✅ No duplicate files found.\033[0m\n'
    echo ""
    rm -rf "$state_dir"
    return 0
  fi

  local total_dupes=0
  local total_wasted=0
  local set_count=0
  local current_hash=""
  local set_size=0
  local set_files=()

  _dups_flush_set() {
    if [[ ${#set_files[@]} -ge 2 ]]; then
      ((set_count++))
      printf '  \033[1;33m━━ Duplicate set %d\033[0m \033[2m(%s each, %d files)\033[0m\n' \
        "$set_count" "$(_dups_format_size "$set_size")" "${#set_files[@]}"
      for f in "${set_files[@]}"; do
        printf '    \033[2m%s\033[0m\n' "$f"
      done
      echo ""
      local wasted=$(( set_size * (${#set_files[@]} - 1) ))
      ((total_wasted += wasted))
      ((total_dupes += ${#set_files[@]} - 1))
    fi
  }

  while IFS=$'\t' read -r hash size filepath; do
    if [[ "$hash" != "$current_hash" ]]; then
      _dups_flush_set
      current_hash="$hash"
      set_size="$size"
      set_files=()
    fi
    set_files+=("$filepath")
  done < <(sort -t$'\t' -k1,1 "$hashes_file")

  # Flush last set
  _dups_flush_set

  # Summary
  printf '  \033[2mScanned %d files\033[0m\n' "$file_count"
  echo ""
  if [[ $set_count -eq 0 ]]; then
    printf '  \033[32m✅ No duplicate files found.\033[0m\n'
  else
    printf '  \033[32m📊 Found %d duplicate set%s (%d redundant file%s)\033[0m\n' \
      "$set_count" "$( (( set_count > 1 )) && echo 's')" \
      "$total_dupes" "$( (( total_dupes > 1 )) && echo 's')"
    printf '  \033[33m💾 Wasted space: %s\033[0m\n' "$(_dups_format_size $total_wasted)"
  fi
  echo ""

  rm -rf "$state_dir"
}
