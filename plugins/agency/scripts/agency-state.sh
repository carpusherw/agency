#!/usr/bin/env bash
#
# A seat's STATE.md, measured. Deterministic; no judgment here. Deciding what is
# still open, and what to keep of the rest, lives in the agency:tidy skill.
#
# `check` is what the plugin's SessionStart hook runs, in every session on the
# machine. It must never be the reason a session fails to start, so it exits 0
# whatever it finds and says nothing at all unless the session is a seat whose
# STATE.md is over its budget.

set -uo pipefail

die() { printf 'agency-state: %s\n' "$1" >&2; exit 1; }

usage() {
  cat >&2 <<'USAGE'
usage: agency-state.sh check
       agency-state.sh measure [--dir <seat folder>]
       agency-state.sh archive [--dir <seat folder>]

  check    for the SessionStart hook. Reads the hook's JSON from stdin when
           there is any, finds the seat the session is running in, and prints
           one notice when that seat's STATE.md is over its budget. Silent
           otherwise, and always exits 0.
  measure  the file's size against its budget, then every section with its
           size in bytes, largest first.
  archive  copy STATE.md, byte for byte, to journal/state-archive-<date>.md
           without overwriting an earlier archive, and print where it landed.

  --dir    the seat's folder. Default: the working directory.

  The budget is 30000 bytes. AGENCY_STATE_BUDGET_BYTES overrides it, per seat
  through that seat's settings.json `env` or for the whole machine.
USAGE
  exit 2
}

# Where a seat holding many open threads still fits after an honest trim. The
# check is for a file that has run away, not for one that is merely full.
DEFAULT_BUDGET=30000

# A budget that is not a positive whole number is a typo in someone's settings,
# and the default is a better answer to it than a check that never fires.
budget() {
  local b="${AGENCY_STATE_BUDGET_BYTES:-}"
  case "$b" in
    ""|*[!0-9]*|0*) printf '%s' "$DEFAULT_BUDGET" ;;
    *) printf '%s' "$b" ;;
  esac
}

kb() { printf '%s' $(( ($1 + 500) / 1000 )); }

find_root() {
  local dir="$1"
  while :; do
    [ -f "$dir/roster.yaml" ] && { printf '%s' "$dir"; return 0; }
    [ "$dir" = "/" ] && return 1
    dir="$(dirname "$dir")"
  done
}

# Read a double-quoted YAML scalar as the scaffold writes it, undoing its
# escaping. The same reading agency-audit.sh gives the roster.
yaml_unquote() {
  perl -e '$s = shift; $s =~ s/\A"//; $s =~ s/"\z//; $s =~ s/\\(.)/$1/g; print $s' "$1"
}

# Which seat a directory is, if it is one. A seat is a folder the roster names,
# and only that folder: a subdirectory of it, the agency root, or a repository
# somewhere else is not a seat even when an agent is working there.
SEAT_NAME="" SEAT_DIR=""
resolve_seat() {
  local dir="$1" root line name="" folder path
  SEAT_NAME="" SEAT_DIR=""
  [ -d "$dir" ] || return 1
  dir="$(cd "$dir" 2>/dev/null && pwd -P)" || return 1
  root="$(find_root "$dir")" || return 1
  while IFS= read -r line; do
    case "$line" in
      "  - name: "*)   name="$(yaml_unquote "${line#  - name: }")" ;;
      "    folder: "*)
        folder="$(yaml_unquote "${line#    folder: }")"
        case "$folder" in /*) path="$folder" ;; *) path="$root/$folder" ;; esac
        path="$(cd "$path" 2>/dev/null && pwd -P)" || continue
        if [ "$path" = "$dir" ]; then
          SEAT_NAME="$name" SEAT_DIR="$dir"
          return 0
        fi
        ;;
    esac
  done < "$root/roster.yaml"
  return 1
}

size_of()     { wc -c < "$1" | tr -d ' '; }
lines_of()    { wc -l < "$1" | tr -d ' '; }
sections_of() { grep -c '^## ' "$1" || true; }

# ---------------------------------------------------------------------- check

cmd_check() {
  local dir="" state bytes limit
  # The hook hands over the session's working directory on stdin. Run by hand
  # there is no stdin to read, and waiting on a terminal would hang.
  if [ ! -t 0 ]; then
    dir="$(python3 -c 'import json, sys
try:
    print(json.load(sys.stdin).get("cwd", ""))
except Exception:
    pass' 2>/dev/null || true)"
  fi
  [ -n "$dir" ] || dir="$PWD"

  resolve_seat "$dir" || return 0
  state="$SEAT_DIR/STATE.md"
  [ -f "$state" ] || return 0
  bytes="$(size_of "$state")"
  limit="$(budget)"
  case "$bytes" in ""|*[!0-9]*) return 0 ;; esac
  [ "$bytes" -gt "$limit" ] || return 0

  cat <<NOTICE
[agency] $SEAT_NAME's STATE.md is $(kb "$bytes") kB — over its $(kb "$limit") kB budget ($(lines_of "$state") lines, $(sections_of "$state") sections).
Every session of this seat reads that file first, so it holds only what is still open.
If you are $SEAT_NAME, finish the step you are in the middle of, then trim it with the agency:tidy skill before you take on anything new; any other session in this folder leaves the file alone.
NOTICE
  return 0
}

# -------------------------------------------------------------------- measure

seat_or_die() {
  local dir="${1:-$PWD}"
  resolve_seat "$dir" \
    || die "$dir is not a seat: no roster.yaml above it names this folder. Pass the seat's folder with --dir."
  [ -f "$SEAT_DIR/STATE.md" ] || die "$SEAT_NAME has no STATE.md at $SEAT_DIR"
}

cmd_measure() {
  local state bytes limit verdict
  seat_or_die "$1"
  state="$SEAT_DIR/STATE.md"
  bytes="$(size_of "$state")"
  limit="$(budget)"
  if [ "$bytes" -gt "$limit" ]; then
    verdict="over by $((bytes - limit))"
  else
    verdict="under by $((limit - bytes))"
  fi
  printf '%s\n' "$state"
  printf '%s bytes, %s lines, %s sections — budget %s (%s)\n\n' \
    "$bytes" "$(lines_of "$state")" "$(sections_of "$state")" "$limit" "$verdict"
  printf 'sections, largest first (bytes, heading):\n'
  # Sizes are counted in bytes, which is what the budget is in. Headings are
  # cut by character, so a long one in any script still prints whole letters.
  perl -e '
    use strict; use warnings; use Encode ();
    open(my $fh, "<:raw", $ARGV[0]) or exit 1;
    my ($head, @rows) = ("(before the first heading)");
    my $size = 0;
    while (my $line = <$fh>) {
      if ($line =~ /\A## (.*)/) {
        push @rows, [$size, $head] if $size > 0;
        ($head, $size) = ($1, 0);
      }
      $size += length $line;
    }
    push @rows, [$size, $head] if $size > 0;
    for my $row (sort { $b->[0] <=> $a->[0] } @rows) {
      my $text = Encode::decode("UTF-8", $row->[1]);
      $text =~ s/\s+\z//;
      $text = substr($text, 0, 110) . "\x{2026}" if length($text) > 110;
      printf "%8d  %s\n", $row->[0], Encode::encode("UTF-8", $text);
    }
  ' "$state" || die "could not read $state"
}

# -------------------------------------------------------------------- archive

cmd_archive() {
  local state journal day dest n=1
  seat_or_die "$1"
  state="$SEAT_DIR/STATE.md"
  journal="$SEAT_DIR/journal"
  mkdir -p "$journal" || die "could not create $journal"
  day="$(date +%Y-%m-%d)"
  dest="$journal/state-archive-$day.md"
  # An earlier archive is the only copy of what an earlier trim took out, so a
  # second one on the same day gets its own name rather than the first one's.
  while [ -e "$dest" ]; do
    n=$((n + 1))
    dest="$journal/state-archive-$day-$n.md"
  done
  cp "$state" "$dest" || die "could not copy $state to $dest"
  cmp -s "$state" "$dest" || die "$dest does not match $state byte for byte. Do not edit STATE.md until an archive does."
  printf 'archived %s bytes to %s\n' "$(size_of "$dest")" "$dest"
}

# ----------------------------------------------------------------------- main

COMMAND="${1-}"
[ -n "$COMMAND" ] || usage
shift

DIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dir)     DIR="${2-}"; [ -n "$DIR" ] || usage; shift 2 ;;
    -h|--help) usage ;;
    *) die "unknown argument: $1" ;;
  esac
done
case "$DIR" in "~") DIR="$HOME" ;; "~/"*) DIR="$HOME/${DIR#\~/}" ;; esac

case "$COMMAND" in
  check)     cmd_check; exit 0 ;;
  measure)   cmd_measure "$DIR" ;;
  archive)   cmd_archive "$DIR" ;;
  -h|--help) usage ;;
  *) die "unknown command: $COMMAND" ;;
esac
