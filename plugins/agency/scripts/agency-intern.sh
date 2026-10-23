#!/usr/bin/env bash
#
# Start an intern: a background session that works for an agency without being
# in its roster. Deterministic; no judgment here. Writing the brief lives in the
# agency:intern skill.

set -euo pipefail

die() { printf 'agency-intern: %s\n' "$1" >&2; exit 1; }

usage() {
  cat >&2 <<'USAGE'
usage: agency-intern.sh --root <path> --agent <agent name> --label <label>
                        --dir <path> --brief-file <path>
                        [--permission-mode <mode>]

  --root             the agency the intern works for. Must hold a roster.yaml.
  --agent            the agent starting the intern, as the roster names it. The
                     intern reports to this agent.
  --label            a few words for the job. Goes into the session's name.
  --dir              where the intern works. Any directory, inside the agency
                     or not; the agency's CLAUDE.md is loaded either way.
  --brief-file       file holding the brief: the whole of the intern's job.
  --permission-mode  what the intern may do without asking. One of: default,
                     acceptEdits, auto, plan. Default: whatever applies in --dir.
USAGE
  exit 2
}

ROOT="" AGENT="" LABEL="" DIR="" BRIEF_FILE="" PERMISSION_MODE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root)            ROOT="${2-}"; shift 2 ;;
    --agent)           AGENT="${2-}"; shift 2 ;;
    --label)           LABEL="${2-}"; shift 2 ;;
    --dir)             DIR="${2-}"; shift 2 ;;
    --brief-file)      BRIEF_FILE="${2-}"; shift 2 ;;
    --permission-mode) PERMISSION_MODE="${2-}"; shift 2 ;;
    -h|--help)         usage ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -n "$ROOT" ] && [ -n "$AGENT" ] && [ -n "$LABEL" ] && [ -n "$DIR" ] && [ -n "$BRIEF_FILE" ] || usage
[ -s "$BRIEF_FILE" ] || die "brief file is missing or empty: $BRIEF_FILE"

# Same limit as a hire: nothing a scaffold starts may bypass every check.
case "$PERMISSION_MODE" in
  ""|default|acceptEdits|auto|plan) ;;
  *) die "unsupported permission mode: $PERMISSION_MODE (use default, acceptEdits, auto or plan)" ;;
esac

case "$LABEL" in
  *$'\n'*|*$'\t'*) die "label cannot contain newlines or tabs" ;;
esac

# Expand a leading ~ without eval.
for v in ROOT DIR; do
  p="${!v}"
  case "$p" in "~") p="$HOME" ;; "~/"*) p="$HOME/${p#\~/}" ;; esac
  printf -v "$v" '%s' "$p"
done

ROSTER="$ROOT/roster.yaml"
[ -d "$ROOT" ] || die "no such agency: $ROOT"
[ -f "$ROSTER" ] || die "no agency at $ROOT (roster.yaml is missing). Open one with the agency:open skill."
[ -d "$DIR" ] || die "no such directory: $DIR"
ROOT="$(cd "$ROOT" && pwd -P)"
DIR="$(cd "$DIR" && pwd -P)"

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

# An intern reports to someone in the office, so the starter must be on the roster.
found="no"
while IFS= read -r raw; do
  [ "$(yaml_unquote "$raw")" = "$AGENT" ] && found="yes"
done < <(sed -n 's/^  - name: //p' "$ROSTER")
[ "$found" = "yes" ] || die "the roster has no agent called $AGENT"

DISPLAY_NAME="$LOGOJI [$AGENCY_NAME]: $AGENT's intern - $LABEL"

PROMPT="You are an intern of the $AGENCY_NAME agency at $ROOT, started by $AGENT. The agency's CLAUDE.md is loaded in your context; its Interns section says what that means. Your brief follows.

$(cat "$BRIEF_FILE")"

command -v claude >/dev/null 2>&1 || die "claude is not on PATH"
command -v jq >/dev/null 2>&1 || die "jq is not on PATH"

# --add-dir alone does not load the agency's CLAUDE.md; the setting below does,
# and it has to travel in --settings. A background session is launched by the
# background service, not this shell, so an exported variable never reaches it.
set -- --bg --add-dir "$ROOT" \
  --settings '{"env":{"CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD":"1"}}' \
  --name "$DISPLAY_NAME"
[ -n "$PERMISSION_MODE" ] && set -- "$@" --permission-mode "$PERMISSION_MODE"
set -- "$@" "$PROMPT"

launch_out="$( (cd "$DIR" && claude "$@") 2>&1 )" \
  || die "the intern could not be started: $(printf '%s' "$launch_out" | tail -1)"

# --bg prints "backgrounded · <short id> · <name>". The working directory cannot
# identify the session: several interns may share one repository.
SHORT_ID="$(printf '%s\n' "$launch_out" | sed -n 's/^backgrounded · \([0-9a-f]\{8\}\) · .*/\1/p' | head -1)"
[ -n "$SHORT_ID" ] || die "the intern started, but its id could not be read from: $(printf '%s' "$launch_out" | head -1)"

SESSION_ID=""
for _ in 1 2 3 4 5; do
  SESSION_ID="$(claude agents --json 2>/dev/null \
    | jq -r --arg s "$SHORT_ID" '[.[] | select(.sessionId | startswith($s))] | last | .sessionId // empty' 2>/dev/null || true)"
  [ -n "$SESSION_ID" ] && break
  sleep 1
done

cat <<EOF
Intern started: $DISPLAY_NAME
  working in  $DIR
  short id    $SHORT_ID
  session id  ${SESSION_ID:-not yet listed by claude agents --json}

  claude attach $SHORT_ID     open it in a terminal
  claude logs $SHORT_ID       show its recent output
  claude stop $SHORT_ID       stop it once its job is done
  claude rm $SHORT_ID         then remove its background record
EOF
