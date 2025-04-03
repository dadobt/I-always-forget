#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Configuration
BASE_NOTE_DIR="$HOME/daily_notes"
GENERAL_NOTES_DIR="$HOME/notes"
EDITOR="${EDITOR:-vim}"

# Sections that carry over from the last existing note
CARRYOVER_SECTIONS=("To do" "Tomorrow" "Reminder" "Keep")

# Sections that do NOT carry over
NONCARRYOVER_SECTIONS=("Journal")

# Helper Functions

inplace_edit() {
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

# Return today's date in YYYY-MM-DD format
get_today() {
  if date --version >/dev/null 2>&1; then
    # GNU date (Linux)
    date +'%F'
  else
    # BSD date (macOS)
    date +'%Y-%m-%d'
  fi
}

# Return a date that is one day before the given date (YYYY-MM-DD).
# Supports both Linux (GNU date) and macOS (BSD date).
date_minus_one() {
  local date_str="$1"
  if date --version >/dev/null 2>&1; then
    # GNU date
    date -d "$date_str -1 day" +'%Y-%m-%d'
  else
    # BSD date (macOS)
    date -j -f '%Y-%m-%d' -v-1d "$date_str" +'%Y-%m-%d'
  fi
}

# Find the last date before 'target_date' that actually has a daily note file.
# If none is found, prints nothing.
get_last_existing_note_before() {
  local target_date="$1"
  local limit_date="1970-01-01"  # Arbitrary lower bound
  local current_date="$target_date"

  while :; do
    # Step back one day
    current_date="$(date_minus_one "$current_date")"

    # If we can't parse or we've reached the limit_date, stop
    if [[ -z "$current_date" || "$current_date" == "$limit_date" ]]; then
      break
    fi

    local path
    path="$(get_note_file "$current_date")"
    if [ -f "$path" ]; then
      echo "$current_date"
      return
    fi
  done
}

# Return the directory path for a given date's daily note (YYYY-MM-DD)
get_note_directory() {
  local date_str="$1"
  local year="${date_str:0:4}"
  local month="${date_str:5:2}"
  echo "$BASE_NOTE_DIR/$year/$month"
}

# Return the full path for a date's daily note, ensuring the directory exists
get_note_file() {
  local date_str="$1"
  local note_dir
  note_dir="$(get_note_directory "$date_str")"
  mkdir -p "$note_dir"
  echo "$note_dir/$date_str.txt"
}

# Extract lines from a "## Section" in a file, skipping lines ending with [x]
extract_section() {
  local file="$1"
  local section="$2"
  local header="## $section"

  awk -v header="$header" '
    $0 == header {flag=1; next}
    /^## /       {if (flag) exit}
    flag && $0 !~ /\[x\]$/ {
      print
    }
  ' "$file"
}


# Daily Note Functions

# Create or open a daily note for the given DATE.
# (No tags for daily notes—this logic has been removed.)
open_daily_note_by_date() {
  local date_str="$1"
  local note_file
  note_file="$(get_note_file "$date_str")"

  # If the note doesn't exist, create it
  if [ ! -f "$note_file" ]; then
    local last_note_date last_note_file carry template
    # Find the last existing note date
    last_note_date="$(get_last_existing_note_before "$date_str")"
    if [ -n "$last_note_date" ]; then
      last_note_file="$(get_note_file "$last_note_date")"
    else
      last_note_file=""
    fi

    # If we have a daily note template, use it
    if [ -f "$HOME/.daily_note_template" ]; then
      template="$(< "$HOME/.daily_note_template")"

      # Replace date placeholder
      template="${template//\{\{DATE\}\}/$date_str}"

      # Remove any leftover {{TAGS}} placeholder if present
      # (We no longer use tags for daily notes.)
      template="${template//\{\{TAGS\}\}/}"

      # Carryover sections
      for section in "${CARRYOVER_SECTIONS[@]}"; do
        local placeholder="{{CARRYOVER:$section}}"
        if [ -n "$last_note_file" ] && [ -f "$last_note_file" ]; then
          carry="$(extract_section "$last_note_file" "$section")"
        else
          carry=""
        fi
        template="${template//$placeholder/$carry}"
      done

      # Remove placeholders for non-carryover sections
      for section in "${NONCARRYOVER_SECTIONS[@]}"; do
        local placeholder="{{${section}}}"
        template="${template//$placeholder/}"
      done

      echo "$template" > "$note_file"

    else
      # No template: build a basic file with the configured sections
      {
        echo "# Daily Notes for $date_str"
        echo ""
        for section in "${CARRYOVER_SECTIONS[@]}"; do
          echo "## $section"
          if [ -n "$last_note_file" ] && [ -f "$last_note_file" ]; then
            carry="$(extract_section "$last_note_file" "$section")"
            [ -n "$carry" ] && echo "$carry"
          fi
          echo ""
        done
        for section in "${NONCARRYOVER_SECTIONS[@]}"; do
          echo "## $section"
          echo ""
        done
      } > "$note_file"
    fi
  fi

  "$EDITOR" "$note_file"
}

# Shortcut: open today's note
open_today() {
  open_daily_note_by_date "$(get_today)"
}

# NEW FEATURE: open "yesterday" note quickly if it exists
open_yesterday() {
  local yesterday_date
  yesterday_date="$(date_minus_one "$(get_today)")"
  local note_file
  note_file="$(get_note_file "$yesterday_date")"

  if [ -f "$note_file" ]; then
    "$EDITOR" "$note_file"
  else
    echo "No note found for $yesterday_date."
    exit 1
  fi
}

list_notes() {
  echo "Available daily notes in $BASE_NOTE_DIR:"
  find "$BASE_NOTE_DIR" -type f -name '*.txt' | sort || echo "No daily notes found."
}

# Extended Searching Features

# Recursively search daily notes (any subfolders) for a keyword
search_notes() {
  local keyword="$1"
  echo "Searching for '$keyword' in daily notes under $BASE_NOTE_DIR..."
  grep -rHin --include='*.txt' "$keyword" "$BASE_NOTE_DIR" 2>/dev/null || echo "No matches found."
}

show_calendar() {
  local input_month="${1:-}"
  local year month note_dir

  if [[ "$input_month" =~ ^[0-9]{4}-[0-9]{2}$ ]]; then
    year="${input_month%%-*}"
    month="${input_month#*-}"
  else
    year="$(date +'%Y')"
    month="$(date +'%m')"
  fi

  echo "Calendar for $year-$month:"
  cal "$month" "$year"
  echo ""

  note_dir="$BASE_NOTE_DIR/$year/$month"
  if [ -d "$note_dir" ]; then
    local days=()
    for file in "$note_dir"/*.txt; do
      [ -e "$file" ] || continue
      local base day
      base="$(basename "$file" .txt)"
      day="${base:8:2}"
      days+=("$((10#$day))")
    done
    if [ ${#days[@]} -gt 0 ]; then
      IFS=$'\n'
      local sorted=($(sort -nu <<<"${days[*]}"))
      unset IFS
      echo "Notes exist for day(s): ${sorted[*]}"
    else
      echo "No daily notes found for this month."
    fi
  else
    echo "No daily notes found for this month."
  fi
}


# Archive Feature

# NEW FEATURE: Archive all daily notes from a given year into a tar.gz
archive_year() {
  local year="$1"
  if [ -z "$year" ]; then
    echo "Error: Please specify a year to archive (e.g., 2022)."
    exit 1
  fi

  local year_dir="$BASE_NOTE_DIR/$year"
  if [ ! -d "$year_dir" ]; then
    echo "No daily notes found for $year."
    exit 1
  fi

  local archive_name="daily_notes_$year.tar.gz"
  echo "Archiving daily notes from $year_dir to $archive_name..."
  tar -czf "$archive_name" -C "$BASE_NOTE_DIR" "$year"
  
  # Optionally remove the archived directory (uncomment if you want to delete after archiving)
  # rm -rf "$year_dir"

  echo "Done. Created archive: $archive_name"
}


# General Note Functions (keeps tags for general notes)

create_or_open_general_note() {
  local title="$1"
  # Safely handle second argument for tags (avoid unbound var)
  local tags="${2:-}"

  if [ -z "$title" ]; then
    echo "Error: Please provide a title for the general note."
    usage
  fi

  local slug
  slug="$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/ /_/g' | tr -cd 'a-z0-9_-')"
  mkdir -p "$GENERAL_NOTES_DIR"
  local note_file="$GENERAL_NOTES_DIR/$slug.txt"

  if [ ! -f "$note_file" ]; then
    if [ -f "$HOME/.general_note_template" ]; then
      local template
      template="$(< "$HOME/.general_note_template")"
      template="${template//\{\{TITLE\}\}/$title}"
      if [ -n "$tags" ]; then
        template="${template//\{\{TAGS\}\}/Tags: $tags}"
      else
        template="${template//\{\{TAGS\}\}/}"
      fi
      template="${template//\{\{DATE\}\}/$(get_today)}"
      echo "$template" > "$note_file"
    else
      {
        echo "# General Note: $title"
        [ -n "$tags" ] && echo "Tags: $tags"
        echo "Created on: $(get_today) $(date +'%T')"
        echo ""
      } > "$note_file"
    fi
  fi

  "$EDITOR" "$note_file"
}

list_general_notes() {
  echo "Available general notes in $GENERAL_NOTES_DIR:"
  ls -1 "$GENERAL_NOTES_DIR"/*.txt 2>/dev/null || echo "No general notes found."
}

search_general_notes() {
  local keyword="$1"
  echo "Searching for '$keyword' in $GENERAL_NOTES_DIR..."
  grep -rHin --include='*.txt' "$keyword" "$GENERAL_NOTES_DIR" 2>/dev/null || echo "No matches found."
}

search_general_notes_by_tag() {
  local tag="$1"
  echo "Searching for tag '$tag' in general notes under $GENERAL_NOTES_DIR..."
  grep -rHn --include='*.txt' -i "Tags:.*$tag" "$GENERAL_NOTES_DIR" 2>/dev/null || echo "No matches found."
}

update_general_tags() {
  local title="$1"
  local new_tags="$2"
  local slug
  slug="$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/ /_/g' | tr -cd 'a-z0-9_-')"
  local note_file="$GENERAL_NOTES_DIR/$slug.txt"

  if [ ! -f "$note_file" ]; then
    echo "General note for \"$title\" does not exist."
    exit 1
  fi

  if grep -q "^Tags:" "$note_file"; then
    inplace_edit "0,/^Tags:/s/^Tags:.*/Tags: $new_tags/" "$note_file"
    echo "Updated tags in general note for \"$title\"."
  else
    inplace_edit "1a\\
Tags: $new_tags
" "$note_file"
    echo "Added tags to general note for \"$title\"."
  fi
}


# Additional Feature: Summaries

show_summary() {
  echo "===== SUMMARY ====="
  
  # Count daily note files
  local daily_count
  daily_count="$(find "$BASE_NOTE_DIR" -type f -name '*.txt' 2>/dev/null | wc -l | tr -d ' ')"
  echo "Number of daily notes: $daily_count"

  # Count general note files
  local general_count
  general_count="$(find "$GENERAL_NOTES_DIR" -type f -name '*.txt' 2>/dev/null | wc -l | tr -d ' ')"
  echo "Number of general notes: $general_count"

  echo ""
  echo "Daily notes by year:"
  if [ -d "$BASE_NOTE_DIR" ]; then
    for year_dir in "$BASE_NOTE_DIR"/*; do
      [ -d "$year_dir" ] || continue
      local year_name
      year_name="$(basename "$year_dir")"
      local year_count
      year_count="$(find "$year_dir" -type f -name '*.txt' 2>/dev/null | wc -l | tr -d ' ')"
      echo "  $year_name: $year_count"
    done
  else
    echo "  No daily notes directory found."
  fi
  echo "===== END SUMMARY ====="
}


# Usage (man page–style)

usage() {
  local script_name
  script_name="$(basename "$0")"

cat <<EOF
NAME
    $script_name - Manage daily and general notes in a simple directory structure

SYNOPSIS
    $script_name [OPTION] [ARGUMENTS]

DESCRIPTION
    This script allows you to create or open date-based "daily notes" (no tags)
    and general notes (with optional tags), listing or searching through
    existing notes as needed. Daily notes can carry over specific sections
    from the most recent existing note, unless a line ends with "[x]"
    (which prevents it from carrying over). You can also archive old daily notes.

OPTIONS

    Daily Notes:
      -t, --today
          Open today's daily note (no tags).

      -y, --yesterday
          Open yesterday's daily note if it exists.

      -d, --date DATE
          Open or create a daily note for the specified DATE (YYYY-MM-DD).

      -l, --list
          List all existing daily note files.

      -s, --search KEYWORD
          Recursively search daily notes for KEYWORD.

      -c, --calendar [YYYY-MM]
          Display a calendar for the specified month (default: current),
          indicating which days have notes.

      -a, --archive-year YYYY
          Archive all daily notes for the specified year into a tar.gz.

    General Notes (with tags):
      -N, --newnote TITLE [--tags "tag1, tag2"]
          Create or open a general note with TITLE and optional tags.

      -ug, --update-general-tags TITLE "new tags"
          Update or set the 'Tags:' line in the general note for TITLE.

      -L, --list-general
          List all existing general note files.

      -S, --search-general KEYWORD
          Recursively search general notes for KEYWORD.

      -St, --search-general-tag TAG
          Recursively search general notes for lines that include TAG
          in the "Tags:" line.

    Summaries:
      -m, --summary
          Display a summary of how many daily and general notes exist,
          plus a breakdown of daily notes by year.

    Other:
      -h, --help
          Display this help text and exit.

TEMPLATES
    For daily notes (no tag placeholders):
      ~/.daily_note_template
      (placeholders: {{DATE}}, {{CARRYOVER:SectionName}})

    For general notes (tag placeholders allowed):
      ~/.general_note_template
      (placeholders: {{TITLE}}, {{DATE}}, {{TAGS}})

EXAMPLES
    $script_name --today
        Open today's daily note (creates it if needed).

    $script_name --yesterday
        Quickly open yesterday's note if it exists.

    $script_name --date 2025-02-14
        Create/open a daily note for 2025-02-14.

    $script_name --search "groceries"
        Search daily notes for the keyword "groceries".

    $script_name --archive-year 2022
        Archive all daily notes from 2022 into a .tar.gz file.

    $script_name --newnote "Project Ideas" --tags "brainstorm, personal"
        Create/open a general note titled "Project Ideas" with tags.

    $script_name --search-general "finance"
        Search general notes for the keyword "finance".

    $script_name --summary
        Show a summary of how many notes exist and how they are distributed by year.

FILES
    Daily notes:   \$HOME/daily_notes/YYYY/MM/YYYY-MM-DD.txt
    General notes: \$HOME/notes/TITLE_SLUG.txt

EOF
  exit 1
}


# Main Logic / Argument Parsing

if [ $# -eq 0 ]; then
  open_today
  exit 0
fi

while [ $# -gt 0 ]; do
case "$1" in
-t|--today)
  open_today
  exit 0
  ;;
-y|--yesterday)
  open_yesterday
  exit 0
  ;;
-d|--date)
  if [ -n "${2:-}" ]; then
    DATE_ARG="$2"
    shift
    open_daily_note_by_date "$DATE_ARG"
    exit 0
  else
    echo "Error: Missing date argument."
    usage
  fi
  ;;
-l|--list)
  list_notes
  exit 0
  ;;
-s|--search)
  if [ -n "${2:-}" ]; then
    search_notes "$2"
    exit 0
  else
    echo "Error: Missing search keyword for daily notes."
    usage
  fi
  ;;
-c|--calendar)
  if [ -n "${2:-}" ] && [[ "$2" =~ ^[0-9]{4}-[0-9]{2}$ ]]; then
    show_calendar "$2"
    exit 0
  else
    show_calendar
    exit 0
  fi
  ;;
-a|--archive-year)
  if [ -n "${2:-}" ]; then
    archive_year "$2"
    exit 0
  else
    echo "Error: Missing year for archive."
    usage
  fi
  ;;
-N|--newnote)
  if [ -n "${2:-}" ]; then
    TITLE="$2"
    shift
    # Define TAGS safely as empty by default
    TAGS=""
    # Check if next argument is --tags
    if [ "${1:-}" = "--tags" ]; then
      if [ -n "${2:-}" ]; then
        TAGS="$2"
        shift
      else
        echo "Error: Missing tags after --tags."
        usage
      fi
    fi
    create_or_open_general_note "$TITLE" "$TAGS"
    exit 0
  else
    echo "Error: Missing title for general note."
    usage
  fi
  ;;
-ug|--update-general-tags)
  # We need *two* arguments: the title and the new tags
  if [ -n "${2:-}" ] && [ -n "${3:-}" ]; then
    update_general_tags "$2" "$3"
    exit 0
  else
    echo "Error: Missing title or new tags for updating general note tags."
    usage
  fi
  ;;
-L|--list-general)
  list_general_notes
  exit 0
  ;;
-S|--search-general)
  if [ -n "${2:-}" ]; then
    search_general_notes "$2"
    exit 0
  else
    echo "Error: Missing search keyword for general notes."
    usage
  fi
  ;;
-St|--search-general-tag)
  if [ -n "${2:-}" ]; then
    search_general_notes_by_tag "$2"
    exit 0
  else
    echo "Error: Missing tag for general notes."
    usage
  fi
  ;;
-m|--summary)
  show_summary
  exit 0
  ;;
-h|--help)
  usage
  ;;
*)
  echo "Error: Unknown option: $1"
  usage
  ;;
esac
shift
done
