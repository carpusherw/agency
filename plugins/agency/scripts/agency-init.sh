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
usage: agency-init.sh --root <path> --agency <agency name> --name <agent name>
                      --jd-file <path> [--emoji <emoji>] [--title <agent title>]

  --root     where the agency lives (e.g. ~/agency). Must be empty or absent.
  --agency   what the agency is called, e.g. MIB. Appears in every session name.
  --name     what this agent is called. Anything a directory can be called, in
             any language.
  --jd-file  file holding the agent's job description (becomes its profile)
  --emoji    one emoji for the agency: no whitespace, no zero-width joiner.
             Default: 🏢
  --title    this agent's title for the roster. Default: Executive Assistant
USAGE
  exit 2
}

ROOT="" NAME="" JD_FILE="" TITLE="Executive Assistant" AGENCY="" EMOJI="🏢"
while [ $# -gt 0 ]; do
  case "$1" in
    --root)    ROOT="${2-}"; shift 2 ;;
    --name)    NAME="${2-}"; shift 2 ;;
    --jd-file) JD_FILE="${2-}"; shift 2 ;;
    --title)   TITLE="${2-}"; shift 2 ;;
    --agency)  AGENCY="${2-}"; shift 2 ;;
    --emoji)   EMOJI="${2-}"; shift 2 ;;
    -h|--help) usage ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -n "$ROOT" ] && [ -n "$NAME" ] && [ -n "$JD_FILE" ] && [ -n "$AGENCY" ] || usage
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
case "$AGENCY" in
  *$'\n'*|*$'\t'*) die "agency name cannot contain newlines or tabs" ;;
esac

# One emoji, and it has to survive a session name. A zero-width joiner there is
# replaced with a space, so a combined emoji like the office worker (person +
# ZWJ + briefcase) arrives as two. Whitespace is rejected rather than a
# codepoint count, because a legitimate emoji may carry a variation selector —
# 🗂️ is U+1F5C2 U+FE0F — and those survive intact.
[ -n "$EMOJI" ] || die "emoji cannot be empty"
case "$EMOJI" in
  *$'\u200d'*) die "emoji cannot contain a zero-width joiner: a combined emoji is split apart in session names. Use a single one." ;;
  *[[:space:]]*) die "emoji cannot contain whitespace: pass a single emoji, not several" ;;
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
export AGENCY_NAME="$AGENCY"
export EMOJI
export DISPLAY_NAME="$EMOJI [$AGENCY]: $NAME"
export DATE="$(date +%Y-%m-%d)"
export AGENCY_ROOT_YAML="$(yaml_quote "$ROOT")"
export AGENT_NAME_YAML="$(yaml_quote "$NAME")"
export AGENT_FOLDER_YAML="$(yaml_quote "$AGENT_FOLDER")"
export TITLE_YAML="$(yaml_quote "$TITLE")"
export DISPLAY_NAME_YAML="$(yaml_quote "$DISPLAY_NAME")"
export AGENCY_NAME_YAML="$(yaml_quote "$AGENCY")"
export EMOJI_YAML="$(yaml_quote "$EMOJI")"
MONTH="$(date +%Y-%m)"

# Substitute {{PLACEHOLDER}} from the environment. perl (not sed) so that
# values containing /, &, | or newlines are safe.
render() {
  perl -pe 's/\{\{(\w+)\}\}/defined $ENV{$1} ? $ENV{$1} : $&/ge' "$1" > "$2"
}

mkdir -p "$AGENT_DIR/journal" "$AGENT_DIR/.claude"

render "$PLUGIN/templates/agency/CLAUDE.md"    "$ROOT/CLAUDE.md"
render "$PLUGIN/templates/agent/CLAUDE.md"     "$AGENT_DIR/CLAUDE.md"
render "$PLUGIN/templates/agent/STATE.md"      "$AGENT_DIR/STATE.md"
cp     "$PLUGIN/templates/agent/settings.json" "$AGENT_DIR/.claude/settings.json"
: > "$AGENT_DIR/journal/$MONTH.md"

# Quote for copy-paste: a path or name with spaces still yields a usable command.
Q_DIR="$(printf %q "$AGENT_DIR")"
Q_NAME="$(printf %q "$DISPLAY_NAME")"

# Start the agent in the background and record the id it is given.
#
# --bg assigns its own session id and ignores --session-id, so the roster can
# only hold a real id by reading it back after the fact. The agent is given a
# first prompt rather than being left idle: a background session that is never
# prompted writes no transcript, is dropped from `claude agents`, and leaves an
# id that cannot be resumed. One exchange makes it durable.
#
# Every failure here is non-fatal — the agency is already written and stays
# valid without an id.
CLOCK_IN="You have just been hired. Read your profile and STATE.md, then say in one line who you are and that you are on duty."
SESSION_ID=""
LAUNCH_NOTE=""
if ! command -v claude >/dev/null 2>&1; then
  LAUNCH_NOTE="claude is not on PATH, so the agent was not started"
elif ! command -v jq >/dev/null 2>&1; then
  LAUNCH_NOTE="jq is not on PATH, so the session id could not be read back"
elif launch_err="$( (cd "$AGENT_DIR" && claude --bg --name "$DISPLAY_NAME" "$CLOCK_IN") 2>&1 >/dev/null )"; then
  PHYS="$(cd "$AGENT_DIR" && pwd -P)"
  for _ in 1 2 3 4 5; do
    SESSION_ID="$(claude agents --json 2>/dev/null \
      | jq -r --arg c "$PHYS" '[.[] | select(.cwd == $c)] | last | .sessionId // empty' 2>/dev/null || true)"
    [ -n "$SESSION_ID" ] && break
    sleep 1
  done
  [ -n "$SESSION_ID" ] || LAUNCH_NOTE="the agent started, but its session id could not be read back"
else
  LAUNCH_NOTE="the agent could not be started: $(printf '%s' "$launch_err" | tail -1)"
fi

if [ -n "$SESSION_ID" ]; then
  export SESSION_ID_YAML="$(yaml_quote "$SESSION_ID")"
else
  export SESSION_ID_YAML="null"
fi
render "$PLUGIN/templates/agency/roster.yaml" "$ROOT/roster.yaml"

cat <<REPORT
$EMOJI $AGENCY opened at $ROOT

  agent        $NAME
  title        $TITLE
  folder       $AGENT_DIR
  display name $DISPLAY_NAME
REPORT

if [ -n "$SESSION_ID" ]; then
  cat <<REPORT
  session id   $SESSION_ID

The agent is running in the background and has read its profile.

open it in this terminal:
  claude attach ${SESSION_ID%%-*}

or pick it out of:
  claude agents

if it is ever stopped, start it again with:
  cd $Q_DIR && claude --bg --resume $SESSION_ID --name $Q_NAME
REPORT
else
  cat <<REPORT

The agency is ready, but $LAUNCH_NOTE.
Start the agent yourself, then put its id in roster.yaml:

  cd $Q_DIR && claude --bg --name $Q_NAME '$CLOCK_IN'
  claude agents --json

The prompt matters: a background session that is never prompted writes no
transcript and drops out of \`claude agents\`, leaving an id that cannot be
resumed.
REPORT
fi
