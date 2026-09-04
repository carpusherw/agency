#!/usr/bin/env bash
#
# The deterministic half of an audit: where the agency is, who is in it, which
# plugin it is being compared against, which revision of a template a live file
# came from, and writing a patch the user has agreed to. Deterministic; no
# judgment here. The comparing and the proposing live in the agency:audit skill.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN="$(cd "$HERE/.." && pwd)"

die() { printf 'agency-audit: %s\n' "$1" >&2; exit 1; }

usage() {
  cat >&2 <<'USAGE'
usage: agency-audit.sh survey [--root <path>] [--no-fetch]
       agency-audit.sh base --file <path> --template <path under the plugin>
                            [--json]
       agency-audit.sh apply --file <path> --from <path>

  survey   the facts an audit starts from: the agency root, the roster parsed
           into agents and folders, which of a seat's files exist, the version
           of the plugin being compared against, and whether the marketplace
           carries a newer one.

    --root      the agency to audit. Default: the nearest roster.yaml at or
                above the working directory.
    --no-fetch  report the installed version without asking the marketplace
                whether a newer one exists. Skips the only step needing network.

  base     which revision of a template a live file came from, by matching its
           content against that template's history in the plugin's own git
           clone. One of:

             current    the live file is what the template says now
             matched    it is an earlier revision, so the plugin moved
             edited     it is no revision, and the history is complete
             truncated  no revision matched, and deepening the shallow
                        clone did not reach far enough, so this stays
                        unresolved
             no-history there is no clone to walk

    --file      the live content. Hand it a file whose rendered values have
                been put back as {{PLACEHOLDERS}}. Matched byte for byte
                unless --json is passed.
    --template  the template to walk, relative to the plugin root, e.g.
                templates/agency/CLAUDE.md
    --json      compare both sides as JSON rather than as bytes: each is
                parsed and re-emitted with its keys sorted and its spacing
                fixed, so a reformatted or reordered file is not a
                difference. Both sides must parse.

  apply    write a patch, keeping a backup of whatever was there.

    --file      what to write to
    --from      the file holding the new content

  --plugin <path> and --marketplace <path> override the installed plugin and
  the git clone its history is read from.
USAGE
  exit 2
}

[ $# -gt 0 ] || usage
COMMAND="$1"; shift
case "$COMMAND" in
  survey|base|apply) ;;
  -h|--help) usage ;;
  *) die "unknown command: $COMMAND" ;;
esac

ROOT="" FILE="" FROM="" TEMPLATE="" MARKETPLACE="" FETCH="yes" JSON="no"
while [ $# -gt 0 ]; do
  case "$1" in
    --root)        ROOT="${2-}"; shift 2 ;;
    --file)        FILE="${2-}"; shift 2 ;;
    --from)        FROM="${2-}"; shift 2 ;;
    --template)    TEMPLATE="${2-}"; shift 2 ;;
    --plugin)      PLUGIN="${2-}"; shift 2 ;;
    --marketplace) MARKETPLACE="${2-}"; shift 2 ;;
    --no-fetch)    FETCH="no"; shift ;;
    --json)        JSON="yes"; shift ;;
    -h|--help)     usage ;;
    *) die "unknown argument: $1" ;;
  esac
done

# Expand a leading ~ without eval.
expand() {
  case "$1" in
    "~")   printf '%s' "$HOME" ;;
    "~/"*) printf '%s/%s' "$HOME" "${1#\~/}" ;;
    *)     printf '%s' "$1" ;;
  esac
}
[ -n "$ROOT" ] && ROOT="$(expand "$ROOT")"
[ -n "$MARKETPLACE" ] && MARKETPLACE="$(expand "$MARKETPLACE")"
PLUGIN="$(expand "$PLUGIN")"
[ -d "$PLUGIN" ] || die "no such plugin directory: $PLUGIN"
PLUGIN="$(cd "$PLUGIN" && pwd -P)"

hash_of()  { shasum -a 256 < "$1" | cut -d' ' -f1; }
plural()   { [ "$1" = 1 ] && printf '1 revision' || printf '%s revisions' "$1"; }
hash_pipe() { shasum -a 256 | cut -d' ' -f1; }

# What `base` compares two pieces of content by. Bytes, which is what Markdown
# wants: there a reflowed paragraph is a real difference. Under --json both
# sides are parsed and re-emitted with their keys sorted and their spacing
# fixed first, because an editor that rewrites a settings file without changing
# what it says would otherwise read as a human edit. Fails on content that does
# not parse — silently, because every caller reports that in its own words.
canonical() {
  if [ "$JSON" = "yes" ]; then
    python3 -c 'import json,sys; json.dump(json.load(sys.stdin), sys.stdout, sort_keys=True, separators=(",", ":"))' 2>/dev/null
  else
    cat
  fi
}
digest_pipe() { canonical | hash_pipe; }
digest_of()   { digest_pipe < "$1"; }

# Read one field out of a plugin manifest arriving on stdin.
manifest_field() {
  python3 -c 'import json,sys; print(json.load(sys.stdin).get(sys.argv[1], ""))' "$1" 2>/dev/null || true
}

# ----------------------------------------------------------------- the agency

# The root is the one value that cannot come from the roster, because the
# roster lives at the root. An agent runs inside its own agency, so walking up
# from the working directory answers it; --root is for everyone else.
find_root() {
  local dir="$PWD"
  while :; do
    [ -f "$dir/roster.yaml" ] && { printf '%s' "$dir"; return 0; }
    [ "$dir" = "/" ] && return 1
    dir="$(dirname "$dir")"
  done
}

# Read a double-quoted YAML scalar written by yaml_quote, undoing its escaping.
yaml_unquote() {
  perl -e '$s = shift; $s =~ s/\A"//; $s =~ s/"\z//; $s =~ s/\\(.)/$1/g; print $s' "$1"
}

# The agency block sits at the top of the roster, so its keys are the first at
# this indent. Agent entries are indented deeper and cannot match. A missing
# key is reported rather than fatal: finding those is what an audit is for.
agency_field() {
  local raw
  raw="$(sed -n "s/^  $1: //p" "$ROSTER" | head -1)"
  [ -n "$raw" ] || { printf '(missing)'; return 0; }
  yaml_unquote "$raw"
}

exists() { if [ -e "$1" ]; then printf 'present'; else printf 'missing'; fi; }

# What `claude plugin` calls this plugin: its manifest name, and the
# marketplace it was installed from when it came from one.
plugin_id() {
  local name
  name="$(manifest_field name < "$PLUGIN/.claude-plugin/plugin.json")"
  [ -n "$name" ] || name="$(basename "$PLUGIN")"
  [ -n "$MARKET" ] && name="$name@$MARKET"
  printf '%s' "$name"
}

journal_of() {
  local names
  [ -d "$1" ] || { printf 'missing'; return 0; }
  names="$(ls -1 "$1" 2>/dev/null | tr '\n' ' ')"
  [ -n "$names" ] && printf '%s' "${names% }" || printf 'empty'
}

# ---------------------------------------------------------- the plugin's clone

# A plugin installed from a marketplace is an unpacked copy of one revision and
# has no history of its own; the marketplace it came from is a git clone beside
# it. A plugin run out of a checkout is already in one.
SRC="" PREFIX="" SRC_NOTE="" MARKET=""
resolve_history() {
  [ -n "$SRC" ] && return 0
  local top name candidate

  if [ -n "$MARKETPLACE" ]; then
    top="$MARKETPLACE"
  elif top="$(git -C "$PLUGIN" rev-parse --show-toplevel 2>/dev/null)"; then
    SRC="$top"
    PREFIX="$(git -C "$PLUGIN" rev-parse --show-prefix)"
    return 0
  else
    # cache/<marketplace>/<plugin>/<version> sits beside marketplaces/<marketplace>
    local versions plugins markets
    versions="$(dirname "$PLUGIN")"
    plugins="$(dirname "$versions")"
    markets="$(dirname "$plugins")"
    if [ "$(basename "$markets")" != "cache" ]; then
      SRC_NOTE="$PLUGIN is neither in a git clone nor in a marketplace cache"
      return 1
    fi
    MARKET="$(basename "$plugins")"
    top="$(dirname "$markets")/marketplaces/$MARKET"
  fi

  if ! git -C "$top" rev-parse --git-dir >/dev/null 2>&1; then
    SRC_NOTE="$top is not a git clone"
    return 1
  fi
  SRC="$(cd "$top" && pwd -P)"

  # The plugin sits either under the marketplace's plugin root or at the top.
  name="$(manifest_field name < "$PLUGIN/.claude-plugin/plugin.json")"
  [ -n "$name" ] || name="$(basename "$PLUGIN")"
  for candidate in "plugins/$name/" ""; do
    if git -C "$SRC" cat-file -e "HEAD:${candidate}.claude-plugin/plugin.json" 2>/dev/null; then
      PREFIX="$candidate"
      return 0
    fi
  done

  SRC_NOTE="$SRC holds no plugin called $name"
  SRC=""
  return 1
}

is_shallow() { [ "$(git -C "$SRC" rev-parse --is-shallow-repository)" = "true" ]; }

# -------------------------------------------------------------------- survey

cmd_survey() {
  if [ -z "$ROOT" ]; then
    ROOT="$(find_root)" || die "no roster.yaml at or above $PWD. Name the agency with --root, or open one with the agency:open skill."
  fi
  [ -d "$ROOT" ] || die "no such agency: $ROOT"
  [ -f "$ROOT/roster.yaml" ] || die "no agency at $ROOT (roster.yaml is missing). Open one with the agency:open skill."
  ROOT="$(cd "$ROOT" && pwd -P)"
  ROSTER="$ROOT/roster.yaml"

  local installed history published
  installed="$(manifest_field version < "$PLUGIN/.claude-plugin/plugin.json")"
  [ -n "$installed" ] || installed="(unversioned)"

  if resolve_history; then
    history="$SRC — ${PREFIX:-the repository root}, history $(is_shallow && printf shallow || printf complete)"
  else
    history="none: $SRC_NOTE. Which side of a difference moved cannot be told apart."
  fi

  if [ "$FETCH" = "no" ]; then
    published="not checked (--no-fetch)"
  elif [ -z "$SRC" ]; then
    published="not checked — there is no clone to ask, so whether a newer plugin exists is unknown"
  else
    published="unreachable, so a newer plugin may exist that this audit did not compare against"
    if git -C "$SRC" fetch --quiet origin 2>/dev/null; then
      local ref newest there
      ref="$(git -C "$SRC" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || printf 'origin/HEAD')"
      there="$(git -C "$SRC" show "$ref:${PREFIX}.claude-plugin/plugin.json" 2>/dev/null | manifest_field version)"
      newest="$(printf '%s\n%s\n' "$installed" "$there" | sort -V | tail -1)"
      if [ -z "$there" ]; then
        published="answered, but carries no version for this plugin"
      elif [ "$there" = "$installed" ]; then
        published="$there — the installed plugin is the newest"
      elif [ "$newest" = "$there" ]; then
        published="$there — newer than the $installed being compared against. Install it first: claude plugin update $(plugin_id)"
      else
        published="$there — older than the installed $installed, so the installed plugin is ahead of the marketplace"
      fi
    fi
  fi

  cat <<REPORT
root         $ROOT
agency       $(agency_field name)
logoji       $(agency_field logoji)
opened       $(agency_field opened)

plugin       $installed at $PLUGIN
history      $history
marketplace  $published

CLAUDE.md    $(exists "$ROOT/CLAUDE.md")
roster.yaml  present
REPORT

  # Roster order is what makes a seat the first one, and only the first seat's
  # job description has an upstream.
  local seat=0 name="" title="" folder="" session="" status="" dir line
  emit() {
    [ -n "$name" ] || return 0
    seat=$((seat + 1))
    dir="$ROOT/$folder"
    cat <<AGENT

agent        $name
  title      $title
  folder     $folder
  session    ${session:-null}
  status     ${status:-(missing)}
  seat       $([ "$seat" = 1 ] && printf 'first' || printf '%s' "$seat")
  on disk    $(exists "$dir")
  profile    $(exists "$dir/CLAUDE.md")
  state      $(exists "$dir/STATE.md")
  settings   $(exists "$dir/.claude/settings.json")
  journal    $(journal_of "$dir/journal")
AGENT
  }

  while IFS= read -r line; do
    case "$line" in
      "  - name: "*)       emit; name="$(yaml_unquote "${line#  - name: }")"
                           title="" folder="" session="" status="" ;;
      "    title: "*)      title="$(yaml_unquote "${line#    title: }")" ;;
      "    folder: "*)     folder="$(yaml_unquote "${line#    folder: }")" ;;
      "    session_id: "*) session="$(yaml_unquote "${line#    session_id: }")" ;;
      "    status: "*)     status="$(yaml_unquote "${line#    status: }")" ;;
    esac
  done < "$ROSTER"
  emit

  [ "$seat" -gt 0 ] || printf '\nagents       none in the roster\n'
  return 0
}

# ---------------------------------------------------------------------- base

cmd_base() {
  [ -n "$FILE" ] && [ -n "$TEMPLATE" ] || usage
  FILE="$(expand "$FILE")"
  [ -f "$FILE" ] || die "no such file: $FILE"
  [ -f "$PLUGIN/$TEMPLATE" ] || die "the plugin has no template at $TEMPLATE"

  local live now
  live="$(digest_of "$FILE")" || die "--json was passed, but $FILE does not parse as JSON"
  now="$(digest_of "$PLUGIN/$TEMPLATE")" || die "--json was passed, but the template $TEMPLATE does not parse as JSON"

  printf 'template     %s\n' "$TEMPLATE"
  printf 'file         %s\n' "$FILE"

  if [ "$live" = "$now" ]; then
    printf 'outcome      current\n'
    return 0
  fi

  if ! resolve_history; then
    printf 'outcome      no-history\n'
    printf 'reason       %s\n' "$SRC_NOTE"
    return 0
  fi

  local tpath="${PREFIX}${TEMPLATE}"
  if ! git -C "$SRC" cat-file -e "HEAD:$tpath" 2>/dev/null; then
    printf 'outcome      no-history\n'
    printf 'reason       %s carries no %s\n' "$SRC" "$tpath"
    return 0
  fi

  # Walk the template's history for the revision whose content is what is live.
  # A shallow clone can hide that revision, which is a different answer from
  # having searched a whole history and found nothing — so deepen first, and
  # only call it an edit once there is nothing left to deepen.
  local rev found="" count=0 oldest=""
  for _ in 1 2 3 4; do
    count=0
    while IFS= read -r rev; do
      count=$((count + 1))
      oldest="$rev"
      # A revision that does not parse cannot be what is live under --json; it
      # digests to nothing and simply fails to match. Its stderr is dropped
      # because that is the only thing it can be: both the live file and the
      # current template were parsed before the walk began, so a canonicaliser
      # that were broken would have said so there.
      if [ "$(git -C "$SRC" show "$rev:$tpath" | digest_pipe 2>/dev/null)" = "$live" ]; then
        found="$rev"
        break
      fi
    done < <(git -C "$SRC" log --follow --format=%H -- "$tpath")
    [ -n "$found" ] && break
    is_shallow || break
    git -C "$SRC" fetch --quiet --deepen 50 origin 2>/dev/null || break
  done

  if [ -n "$found" ]; then
    printf 'outcome      matched\n'
    printf 'revision     %s\n' "$found"
    printf 'dated        %s\n' "$(git -C "$SRC" show -s --format=%as "$found")"
    printf 'subject      %s\n' "$(git -C "$SRC" show -s --format=%s "$found")"
    printf 'version      %s\n' "$(git -C "$SRC" show "$found:${PREFIX}.claude-plugin/plugin.json" 2>/dev/null | manifest_field version)"
    return 0
  fi

  if is_shallow; then
    printf 'outcome      truncated\n'
    printf 'searched     %s of %s, back to %s, where the clone is cut off\n' \
      "$(plural "$count")" "$tpath" "$(git -C "$SRC" rev-parse --short "$oldest")"
    return 0
  fi

  printf 'outcome      edited\n'
  printf 'searched     %s of %s, its whole history\n' "$(plural "$count")" "$tpath"
  return 0
}

# --------------------------------------------------------------------- apply

cmd_apply() {
  [ -n "$FILE" ] && [ -n "$FROM" ] || usage
  FILE="$(expand "$FILE")"
  FROM="$(expand "$FROM")"
  [ -f "$FROM" ] || die "no such file: $FROM"
  [ -d "$(dirname "$FILE")" ] || die "no such directory: $(dirname "$FILE")"

  local backup="" verb="created"
  if [ -e "$FILE" ]; then
    verb="updated"
    backup="$FILE.agency-audit.$(date +%Y%m%d-%H%M%S).bak"
    [ -e "$backup" ] && die "a backup already exists at $backup"
    cp -p "$FILE" "$backup"
  fi

  cat "$FROM" > "$FILE"

  # Read it back rather than trusting the write.
  [ "$(hash_of "$FILE")" = "$(hash_of "$FROM")" ] || die "$FILE was written but does not hold what $FROM does"

  printf '%s      %s\n' "$verb" "$FILE"
  [ -n "$backup" ] && printf 'backup       %s\n' "$backup"
  return 0
}

case "$COMMAND" in
  survey) cmd_survey ;;
  base)   cmd_base ;;
  apply)  cmd_apply ;;
esac
