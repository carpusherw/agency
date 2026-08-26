#!/usr/bin/env bash
#
# Scaffold a new agency and its first agent. Deterministic; no judgment here.
# The interview lives in the agency:open skill.
#
# Refuses to touch an agency that already exists.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN="$(cd "$HERE/.." && pwd)"

die() { printf 'agency-init: %s\n' "$1" >&2; exit 1; }

usage() {
  cat >&2 <<'USAGE'
usage: agency-init.sh --root <path> --jd-file <path> [--name <name>] [--title <title>]

  --root     where the agency lives (e.g. ~/agency)
  --jd-file  file holding the agent's job description (becomes its profile)
  --name     agent name, [a-z0-9_-]. Random if omitted.
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

[ -n "$ROOT" ] && [ -n "$JD_FILE" ] || usage
[ -s "$JD_FILE" ] || die "job description file is missing or empty: $JD_FILE"

[ -n "$NAME" ] || NAME="$("$HERE/random-name.sh")"
printf '%s' "$NAME" | grep -Eq '^[a-z0-9_-]+$' || die "agent name must match [a-z0-9_-]+ (got: $NAME)"

# Expand a leading ~ without eval.
case "$ROOT" in "~") ROOT="$HOME" ;; "~/"*) ROOT="$HOME/${ROOT#\~/}" ;; esac

[ -e "$ROOT/roster.yaml" ] && die "an agency already exists at $ROOT (roster.yaml present)"

AGENT_FOLDER="agents/$NAME"
AGENT_DIR="$ROOT/$AGENT_FOLDER"

export AGENCY_ROOT="$ROOT"
export AGENT_NAME="$NAME"
export AGENT_FOLDER
export TITLE="${TITLE//\"/}"
export JD="$(cat "$JD_FILE")"
export SESSION_ID="$(uuidgen | tr '[:upper:]' '[:lower:]')"
export DISPLAY_NAME="agency:$NAME"
export DATE="$(date +%Y-%m-%d)"
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

# Local history only — the agency is instance state and gets no remote.
if [ ! -d "$ROOT/.git" ]; then
  git -C "$ROOT" init -q
  git -C "$ROOT" add CLAUDE.md roster.yaml "$AGENT_FOLDER"
  git -C "$ROOT" commit -qm "Open agency with agent: $NAME"
fi

cat <<REPORT
agency opened at $ROOT

  agent        $NAME
  title        $TITLE
  folder       $AGENT_DIR
  session id   $SESSION_ID
  display name $DISPLAY_NAME

start the agent:
  cd $AGENT_DIR && claude --session-id $SESSION_ID --name $DISPLAY_NAME

resume it later:
  cd $AGENT_DIR && claude --resume $SESSION_ID
REPORT
