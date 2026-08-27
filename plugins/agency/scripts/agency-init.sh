#!/usr/bin/env bash
#
# Scaffold a new agency and its first agent. Deterministic; no judgment here.
# The interview lives in the agency:open skill.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN="$(cd "$HERE/.." && pwd)"

die() { printf 'agency-init: %s\n' "$1" >&2; exit 1; }

usage() {
  cat >&2 <<'USAGE'
usage: agency-init.sh --root <path> --name <name> --jd-file <path> [--title <title>]

  --root     where the agency lives (e.g. ~/agency). Must be empty or absent.
  --name     agent name. Anything a directory can be called, in any language.
  --jd-file  file holding the agent's job description (becomes its profile)
  --title    agent title for the roster. Default: Executive Assistant
USAGE
  exit 2
}

ROOT="" NAME="" JD_FILE="" TITLE="Executive Assistant"
while [ $# -gt 0 ]; do
  case "$1" in
    --root)    ROOT="${2-}"; shift 2 ;;
    --name)    NAME="${2-}"; shift 2 ;;
    --jd-file) JD_FILE="${2-}"; shift 2 ;;
    --title)   TITLE="${2-}"; shift 2 ;;
    -h|--help) usage ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -n "$ROOT" ] && [ -n "$NAME" ] && [ -n "$JD_FILE" ] || usage
[ -s "$JD_FILE" ] || die "job description file is missing or empty: $JD_FILE"

# A name is anything a directory can be called. Reject only what breaks a path.
case "$NAME" in
  .|..)     die "agent name cannot be '.' or '..'" ;;
  -*)       die "agent name cannot start with '-'" ;;
  */*)      die "agent name cannot contain '/'" ;;
  *$'\n'*|*$'\t'*) die "agent name cannot contain newlines or tabs" ;;
esac
case "$TITLE" in
  *$'\n'*) die "title cannot contain newlines" ;;
esac

# Expand a leading ~ without eval.
case "$ROOT" in "~") ROOT="$HOME" ;; "~/"*) ROOT="$HOME/${ROOT#\~/}" ;; esac

# The agency owns its directory. Opening into occupied ground would overwrite
# whatever CLAUDE.md or agents/ already lives there.
if [ -e "$ROOT" ]; then
  [ -d "$ROOT" ] || die "not a directory: $ROOT"
  [ -e "$ROOT/roster.yaml" ] && die "an agency already exists at $ROOT (roster.yaml present)"
  [ -z "$(ls -A "$ROOT")" ] || die "refusing to open an agency in a non-empty directory: $ROOT"
fi

AGENT_FOLDER="agents/$NAME"
AGENT_DIR="$ROOT/$AGENT_FOLDER"

# Serialize a value as a double-quoted YAML scalar, so a name, title, or path
# containing ':', '#', '"', '\' or a leading '-' cannot corrupt the roster.
yaml_quote() {
  printf '"%s"' "$(printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
}

export AGENCY_ROOT="$ROOT"
export AGENT_NAME="$NAME"
export AGENT_FOLDER
export TITLE
export JD="$(cat "$JD_FILE")"
export SESSION_ID="$(uuidgen | tr '[:upper:]' '[:lower:]')"
export DISPLAY_NAME="agency:$NAME"
export DATE="$(date +%Y-%m-%d)"
export AGENCY_ROOT_YAML="$(yaml_quote "$ROOT")"
export AGENT_NAME_YAML="$(yaml_quote "$NAME")"
export AGENT_FOLDER_YAML="$(yaml_quote "$AGENT_FOLDER")"
export TITLE_YAML="$(yaml_quote "$TITLE")"
export DISPLAY_NAME_YAML="$(yaml_quote "agency:$NAME")"
MONTH="$(date +%Y-%m)"

# Substitute {{PLACEHOLDER}} from the environment. perl (not sed) so that
# values containing /, &, | or newlines are safe.
render() {
  perl -pe 's/\{\{(\w+)\}\}/defined $ENV{$1} ? $ENV{$1} : $&/ge' "$1" > "$2"
}

mkdir -p "$AGENT_DIR/journal" "$AGENT_DIR/.claude"

render "$PLUGIN/templates/agency/CLAUDE.md"    "$ROOT/CLAUDE.md"
render "$PLUGIN/templates/agency/roster.yaml"  "$ROOT/roster.yaml"
render "$PLUGIN/templates/agent/CLAUDE.md"     "$AGENT_DIR/CLAUDE.md"
render "$PLUGIN/templates/agent/STATE.md"      "$AGENT_DIR/STATE.md"
cp     "$PLUGIN/templates/agent/settings.json" "$AGENT_DIR/.claude/settings.json"
: > "$AGENT_DIR/journal/$MONTH.md"

# Quote for copy-paste: a path or name with spaces still yields a usable command.
Q_DIR="$(printf %q "$AGENT_DIR")"
Q_NAME="$(printf %q "$DISPLAY_NAME")"

cat <<REPORT
agency opened at $ROOT

  agent        $NAME
  title        $TITLE
  folder       $AGENT_DIR
  session id   $SESSION_ID
  display name $DISPLAY_NAME

start the agent:
  cd $Q_DIR && claude --session-id $SESSION_ID --name $Q_NAME

resume it later:
  cd $Q_DIR && claude --continue
REPORT
