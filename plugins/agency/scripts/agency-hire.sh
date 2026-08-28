#!/usr/bin/env bash
#
# Hire an agent into an agency that already exists. Deterministic; no judgment
# here. The interview lives in the agency:hire skill.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN="$(cd "$HERE/.." && pwd)"

die() { printf 'agency-hire: %s\n' "$1" >&2; exit 1; }

usage() {
  cat >&2 <<'USAGE'
usage: agency-hire.sh --root <path> --name <agent name> --jd-file <path>
                      [--title <agent title>] [--resume-session <session id>]
                      [--permission-mode <mode>] [--trust]

  --root             the agency to hire into. Must already hold a roster.yaml.
  --name             what this agent is called. Anything a directory can be
                     called, in any language. Must not already be in the roster.
  --jd-file          file holding the agent's job description (becomes its
                     profile)
  --title            this agent's title for the roster. Default: Agent
  --resume-session   hire an existing session into the seat instead of starting
                     a fresh one. The session keeps its conversation and adopts
                     the seat's profile, conventions and permissions. It must
                     already be stopped.
  --permission-mode  what this seat may do without asking, written to its own
                     .claude/settings.json. One of: default, acceptEdits, auto,
                     plan. Default: default.
  --trust            mark the new agent's folder as a trusted workspace, so
                     permissions.allow and permissions.deny entries in its
                     settings are honoured. Only pass this with the user's
                     explicit consent.
USAGE
  exit 2
}

ROOT="" NAME="" JD_FILE="" TITLE="Agent"
RESUME_SESSION="" PERMISSION_MODE="default" TRUST="no"
while [ $# -gt 0 ]; do
  case "$1" in
    --root)            ROOT="${2-}"; shift 2 ;;
    --name)            NAME="${2-}"; shift 2 ;;
    --jd-file)         JD_FILE="${2-}"; shift 2 ;;
    --title)           TITLE="${2-}"; shift 2 ;;
    --resume-session)  RESUME_SESSION="${2-}"; shift 2 ;;
    --permission-mode) PERMISSION_MODE="${2-}"; shift 2 ;;
    --trust)           TRUST="yes"; shift ;;
    -h|--help)         usage ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -n "$ROOT" ] && [ -n "$NAME" ] && [ -n "$JD_FILE" ] || usage
[ -s "$JD_FILE" ] || die "job description file is missing or empty: $JD_FILE"

# A seat that may bypass every permission check is not something a scaffold
# should be able to mint. Editing the settings file afterwards remains open.
case "$PERMISSION_MODE" in
  default|acceptEdits|auto|plan) ;;
  *) die "unsupported permission mode: $PERMISSION_MODE (use default, acceptEdits, auto or plan)" ;;
esac

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

ROSTER="$ROOT/roster.yaml"
[ -d "$ROOT" ] || die "no such agency: $ROOT"
[ -f "$ROSTER" ] || die "no agency at $ROOT (roster.yaml is missing). Open one with the agency:open skill."

# Read a double-quoted YAML scalar written by yaml_quote, undoing its escaping.
yaml_unquote() {
  perl -e '$s = shift; $s =~ s/\A"//; $s =~ s/"\z//; $s =~ s/\\(.)/$1/g; print $s' "$1"
}

# The agency block sits at the top of the roster, so its keys are the first at
# this indent. Agent entries are indented deeper and cannot match.
agency_field() {
  local raw
  raw="$(sed -n "s/^  $1: //p" "$ROSTER" | head -1)"
  [ -n "$raw" ] || die "roster.yaml has no agency.$1 — is $ROSTER from an older layout?"
  yaml_unquote "$raw"
}

AGENCY_NAME="$(agency_field name)"
LOGOJI="$(agency_field logoji)"

AGENT_FOLDER="agents/$NAME"
AGENT_DIR="$ROOT/$AGENT_FOLDER"

# One seat per name. The roster and the filesystem must agree, so check both.
[ -e "$AGENT_DIR" ] && die "a folder already exists for that name: $AGENT_DIR"
while IFS= read -r raw; do
  [ "$(yaml_unquote "$raw")" = "$NAME" ] && die "the roster already has an agent called $NAME"
done < <(sed -n 's/^  - name: //p' "$ROSTER")

# A running background session cannot be resumed into another directory; the
# harness refuses it. Stopping is the user's call, so report rather than act.
if [ -n "$RESUME_SESSION" ] && command -v claude >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  if claude agents --json 2>/dev/null \
      | jq -e --arg s "$RESUME_SESSION" 'any(.[]; .sessionId == $s)' >/dev/null 2>&1; then
    die "session $RESUME_SESSION is still running. Stop it first: claude stop ${RESUME_SESSION%%-*}"
  fi
fi

yaml_quote() {
  printf '"%s"' "$(printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
}

export AGENT_NAME="$NAME"
export AGENT_FOLDER
export TITLE
export JD="$(cat "$JD_FILE")"
export PERMISSION_MODE
export DISPLAY_NAME="$LOGOJI [$AGENCY_NAME]: $NAME"
export DATE="$(date +%Y-%m-%d)"
MONTH="$(date +%Y-%m)"

# Substitute {{PLACEHOLDER}} from the environment. perl (not sed) so that
# values containing /, &, | or newlines are safe.
render() {
  perl -pe 's/\{\{(\w+)\}\}/defined $ENV{$1} ? $ENV{$1} : $&/ge' "$1" > "$2"
}

mkdir -p "$AGENT_DIR/journal" "$AGENT_DIR/.claude"
render "$PLUGIN/templates/agent/CLAUDE.md"     "$AGENT_DIR/CLAUDE.md"
render "$PLUGIN/templates/agent/STATE.md"      "$AGENT_DIR/STATE.md"
render "$PLUGIN/templates/agent/settings.json" "$AGENT_DIR/.claude/settings.json"
: > "$AGENT_DIR/journal/$MONTH.md"

# Trust is what makes permissions.allow and permissions.deny in the seat's own
# settings take effect; without it they are ignored. It is a change to the
# user's global config, so it happens only on an explicit --trust.
TRUST_NOTE=""
if [ "$TRUST" = "yes" ]; then
  CONFIG="$HOME/.claude.json"
  if ! command -v jq >/dev/null 2>&1; then
    TRUST_NOTE="jq is not on PATH, so the folder was not marked trusted"
  elif [ ! -f "$CONFIG" ]; then
    TRUST_NOTE="$CONFIG does not exist, so the folder was not marked trusted"
  else
    PHYS_DIR="$(cd "$AGENT_DIR" && pwd -P)"
    BACKUP="$CONFIG.agency-hire.bak"
    cp -p "$CONFIG" "$BACKUP"
    if jq --arg p "$PHYS_DIR" \
         '.projects[$p].hasTrustDialogAccepted = true' "$CONFIG" > "$CONFIG.tmp" 2>/dev/null \
       && jq -e . "$CONFIG.tmp" >/dev/null 2>&1; then
      # Keep the original's permissions rather than the temp file's.
      cat "$CONFIG.tmp" > "$CONFIG"
      rm -f "$CONFIG.tmp"
      TRUST_NOTE="trusted (previous config saved to $BACKUP)"
    else
      rm -f "$CONFIG.tmp"
      TRUST_NOTE="the config could not be rewritten, so the folder was not marked trusted (unchanged; backup at $BACKUP)"
    fi
  fi
fi

Q_DIR="$(printf %q "$AGENT_DIR")"
Q_NAME="$(printf %q "$DISPLAY_NAME")"

# Start the agent and record the id it is given.
#
# --bg assigns its own session id and ignores --session-id, so the roster can
# only hold a real id by reading it back afterwards. That is true of a resumed
# session too: resuming under --bg mints a new id and keeps the conversation.
#
# A relocated session already carries its context, so its first prompt asks it
# to put that context where a replaceable session can find it again.
if [ -n "$RESUME_SESSION" ]; then
  CLOCK_IN="You have been hired into an agency and this is your seat. Read your profile and the agency conventions above it, then write STATE.md and today's journal entry: what you are carrying right now, what is in flight, and anything a session replacing you would otherwise have to rediscover. Then say in one line who you are and that you are on duty."
else
  CLOCK_IN="You have just been hired. Read your profile and STATE.md, then say in one line who you are and that you are on duty."
fi
# The relocation prompt contains an apostrophe, so the printed fallback command
# quotes it the same way it quotes the path and the name.
Q_CLOCK_IN="$(printf %q "$CLOCK_IN")"

SESSION_ID=""
LAUNCH_NOTE=""
if ! command -v claude >/dev/null 2>&1; then
  LAUNCH_NOTE="claude is not on PATH, so the agent was not started"
elif ! command -v jq >/dev/null 2>&1; then
  LAUNCH_NOTE="jq is not on PATH, so the session id could not be read back"
else
  if [ -n "$RESUME_SESSION" ]; then
    set -- --bg --resume "$RESUME_SESSION" --name "$DISPLAY_NAME" "$CLOCK_IN"
  else
    set -- --bg --name "$DISPLAY_NAME" "$CLOCK_IN"
  fi
  if launch_err="$( (cd "$AGENT_DIR" && claude "$@") 2>&1 >/dev/null )"; then
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
fi

if [ -n "$SESSION_ID" ]; then
  SESSION_ID_YAML="$(yaml_quote "$SESSION_ID")"
else
  SESSION_ID_YAML="null"
fi

# Append the seat to the roster. A text append, not a parse and re-emit: the
# roster carries a header comment and a field order that a YAML round-trip
# would discard, and the entry's shape is fixed by the template that wrote it.
TMP_ROSTER="$ROSTER.agency-hire.$$"
# -p, so the roster keeps its mode rather than taking one from the umask.
cp -p "$ROSTER" "$TMP_ROSTER"
# Guard against a file that does not end in a newline, which would fuse the
# first appended line onto the last existing one.
[ -n "$(tail -c 1 "$TMP_ROSTER")" ] && printf '\n' >> "$TMP_ROSTER"
{
  printf '  - name: %s\n' "$(yaml_quote "$NAME")"
  printf '    title: %s\n' "$(yaml_quote "$TITLE")"
  printf '    folder: %s\n' "$(yaml_quote "$AGENT_FOLDER")"
  printf '    session_id: %s\n' "$SESSION_ID_YAML"
  printf '    status: active\n'
} >> "$TMP_ROSTER"
mv "$TMP_ROSTER" "$ROSTER"

# Read the entry back rather than trusting the write.
APPENDED="no"
while IFS= read -r raw; do
  [ "$(yaml_unquote "$raw")" = "$AGENT_FOLDER" ] && APPENDED="yes"
done < <(sed -n 's/^    folder: //p' "$ROSTER")
[ "$APPENDED" = "yes" ] || die "the roster was written but $NAME is not in it — check $ROSTER"

cat <<REPORT
$LOGOJI $AGENCY_NAME hired $NAME

  agent        $NAME
  title        $TITLE
  folder       $AGENT_DIR
  display name $DISPLAY_NAME
  permissions  $PERMISSION_MODE
REPORT

[ -n "$TRUST_NOTE" ] && printf '  workspace    %s\n' "$TRUST_NOTE"

if [ -n "$SESSION_ID" ]; then
  cat <<REPORT
  session id   $SESSION_ID

REPORT
  if [ -n "$RESUME_SESSION" ]; then
    cat <<REPORT
The seat is running in the background. It kept the conversation from
$RESUME_SESSION and now reads its new profile; resuming under --bg mints a new
id, which is the one recorded above and in the roster.

REPORT
  else
    printf 'The agent is running in the background and has read its profile.\n\n'
  fi
  cat <<REPORT
open it in this terminal:
  claude attach ${SESSION_ID%%-*}

or pick it out of:
  claude agents

if it is ever stopped, start it again with:
  cd $Q_DIR && claude --bg --resume $SESSION_ID --name $Q_NAME
REPORT
else
  cat <<REPORT

The seat is written and in the roster, but $LAUNCH_NOTE.
Start the agent yourself, then put its id in roster.yaml:

  cd $Q_DIR && claude --bg --name $Q_NAME $Q_CLOCK_IN
  claude agents --json

The prompt matters: a background session that is never prompted writes no
transcript and drops out of \`claude agents\`, leaving an id that cannot be
resumed.
REPORT
fi
