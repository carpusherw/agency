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
       agency-audit.sh collapse --agent <name> --what frame|jd|settings
                                [--root <path>]
       agency-audit.sh base --file <path> --template <path under the plugin>
                            [--json]
       agency-audit.sh apply --file <path> --from <path>

  survey   the facts an audit starts from: the agency root, the roster parsed
           into agents and folders, which of a seat's files exist, when an
           audit last wrote a patch here, the version of the plugin being
           compared against, and whether the marketplace carries a newer one.

    --root      the agency to audit. Default: the nearest roster.yaml at or
                above the working directory.
    --no-fetch  report the installed version without asking the marketplace
                whether a newer one exists. Skips the only step needing network.

  collapse one seat's live content on stdout with the values it was rendered
           with put back as {{PLACEHOLDERS}} — the shape `base` has to be
           handed. Where the job description begins and ends is read off the
           template rather than assumed, and a value is put back only where it
           occurs exactly once. Anything it cannot reverse exits non-zero
           saying so: that is a base which cannot be determined, and it is not
           the same as a difference.

           A value the roster gives that is nowhere in the profile is that
           case — something else stands where the placeholder belongs, and
           handing that on still rendered is how a base gets answered
           confidently and wrongly. A key the live file simply does not have
           is not that case: the absence is faithful, so it is emitted as it
           stands and the difference is `base`'s to report.

    --agent  the seat, by the name the roster gives it.
    --what   frame     the profile, its job description collapsed to {{JD}};
                       compare against templates/agent/CLAUDE.md
             jd        that job description on its own; compare against
                       templates/jd/ea.md
             settings  the seat's settings.json; compare against
                       templates/agent/settings.json
    --root   as for survey.

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

    --file      the live content, as `collapse` writes it: a file whose
                rendered values have been put back as {{PLACEHOLDERS}}.
    --template  the template to walk, relative to the plugin root, e.g.
                templates/agency/CLAUDE.md. Its path decides how the two
                sides are compared: byte for byte, or as JSON where the
                template is a .json.
    --json      compare as JSON even where the template's path does not say
                so. Both sides are parsed and re-emitted with their keys
                sorted and their spacing fixed, so a reformatted or reordered
                file is not a difference; both must parse.

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
  survey|collapse|base|apply) ;;
  -h|--help) usage ;;
  *) die "unknown command: $COMMAND" ;;
esac

# JSON starts at auto: the template's path decides, and --json overrides it.
ROOT="" FILE="" FROM="" TEMPLATE="" MARKETPLACE="" FETCH="yes" JSON="auto"
AGENT="" WHAT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root)        ROOT="${2-}"; shift 2 ;;
    --agent)       AGENT="${2-}"; shift 2 ;;
    --what)        WHAT="${2-}"; shift 2 ;;
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

# Whether a program is here, and whether it works, asked separately: they are
# different things to tell someone, and being on PATH is not the same as being
# able to run. Every program asked about below answers --version.
on_path() { command -v "$1" >/dev/null 2>&1; }
runs()    { "$1" --version >/dev/null 2>&1; }

# Every verb runs programs of its own, and one that is missing or broken has to
# be named here. Unchecked it arrives as the shell's own "command not found" on
# stderr while the script either carries on with a hole in its report or dies
# about something else entirely — which is how a missing hasher came to be
# reported as a file that would not parse.
require() {
  local tool
  for tool in "$@"; do
    if ! on_path "$tool"; then
      die "$COMMAND needs $tool, which is not on PATH"
    elif ! runs "$tool"; then
      die "$COMMAND needs $tool, which is at $(command -v "$tool") but would not run"
    fi
  done
}

# What `base` compares two pieces of content by. Bytes, which is what Markdown
# wants: there a reflowed paragraph is a real difference. For a JSON template
# both sides are parsed and re-emitted with their keys sorted and their spacing
# fixed first, because an editor that rewrites a settings file without changing
# what it says would otherwise read as a human edit.
#
# Content that does not parse exits 3, and nothing else does, so a caller can
# tell that from the canonicaliser having failed to run at all. Those are
# opposite findings — one is the user's file, the other is this machine — and
# reporting the second as the first is the whole reason for the exit code.
CANNOT_PARSE=3
canonical() {
  if [ "$JSON" = "yes" ]; then
    python3 -c 'import json, sys
try:
    document = json.load(sys.stdin)
except ValueError:
    sys.exit(3)
json.dump(document, sys.stdout, sort_keys=True, separators=(",", ":"))'
  else
    cat
  fi
}
digest_pipe() { canonical | hash_pipe; }
digest_of()   { digest_pipe < "$1"; }

# Run the canonicaliser for its exit status alone, and turn that into words.
# Doing it before the digest is what keeps the two apart: after this the only
# thing left in the pipeline is the hasher, and `require` has already found it.
# Both modes are checked, not only JSON — a reader of bytes that does not run
# is the same wrong answer as a parser that does not run, just quieter.
parses() {
  local status=0
  # Asked before the redirection rather than after it: a file that cannot be
  # opened fails the same way a canonicaliser that will not run does, and the
  # message would then blame a program that never started.
  [ -r "$1" ] || die "$2 cannot be read — check its permissions"
  canonical < "$1" >/dev/null || status=$?
  if [ "$status" = 0 ]; then
    return 0
  fi
  # Only the exit code below is a finding about the content. Anything else is
  # undecided, and saying so is the whole point — claiming either way is what
  # this function exists to stop.
  if [ "$JSON" = "yes" ]; then
    case "$status" in
      "$CANNOT_PARSE")
        die "$2 does not parse as JSON, and $TEMPLATE is compared as JSON" ;;
      *)
        die "python3 exited $status reading $2, which is neither success nor a parse failure, so whether the content parses is unknown" ;;
    esac
  fi
  die "cat exited $status reading $2, so its bytes could not be read"
}

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

# The agency a command is about, and its roster. --root names it; otherwise it
# is the nearest one at or above the working directory, which is what an agent
# auditing its own agency gets by passing nothing.
ROSTER=""
resolve_root() {
  if [ -z "$ROOT" ]; then
    ROOT="$(find_root)" || die "no roster.yaml at or above $PWD. Name the agency with --root, or open one with the agency:open skill."
  fi
  [ -d "$ROOT" ] || die "no such agency: $ROOT"
  [ -f "$ROOT/roster.yaml" ] || die "no agency at $ROOT (roster.yaml is missing). Open one with the agency:open skill."
  ROOT="$(cd "$ROOT" && pwd -P)"
  ROSTER="$ROOT/roster.yaml"
}

# One seat out of the roster. The roster is the only place a seat's rendered
# values survive, which is what makes putting them back possible at all.
SEAT_NAME="" SEAT_TITLE="" SEAT_FOLDER=""
roster_seat() {
  local want="$1" line name=""
  SEAT_NAME="" SEAT_TITLE="" SEAT_FOLDER=""
  while IFS= read -r line; do
    case "$line" in
      "  - name: "*)   name="$(yaml_unquote "${line#  - name: }")"
                       if [ "$name" = "$want" ]; then SEAT_NAME="$name"; fi ;;
      "    title: "*)  if [ "$name" = "$want" ]; then SEAT_TITLE="$(yaml_unquote "${line#    title: }")"; fi ;;
      "    folder: "*) if [ "$name" = "$want" ]; then SEAT_FOLDER="$(yaml_unquote "${line#    folder: }")"; fi ;;
    esac
  done < "$ROSTER"
  [ -n "$SEAT_NAME" ] || die "no agent called $want in $ROSTER"
  [ -n "$SEAT_FOLDER" ] || die "the roster gives $want no folder, so there is nothing to read"
}

# What a previous audit left behind. `apply` backs a file up before writing it,
# so a backup is the only record that an audit ever wrote here, and the newest
# timestamp is when this office was last brought into line.
audit_history() {
  local file stamp count=0 newest="" newest_stamp="" label
  while IFS= read -r -d '' file; do
    stamp="${file##*.agency-audit.}"
    stamp="${stamp%.bak}"
    case "$stamp" in
      [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]) ;;
      *) continue ;;
    esac
    count=$((count + 1))
    if [ "$stamp" \> "$newest_stamp" ]; then
      newest_stamp="$stamp"
      newest="$file"
    fi
  done < <(find "$ROOT" -type f -name '*.agency-audit.*.bak' -print0 2>/dev/null)

  if [ "$count" = 0 ]; then
    printf 'never — nothing here carries a backup, so no audit has written a patch'
    return 0
  fi
  if [ "$count" = 1 ]; then label="1 backup"; else label="the newest of $count backups"; fi
  printf '%s-%s-%s %s:%s:%s — %s, at %s' \
    "${newest_stamp:0:4}" "${newest_stamp:4:2}" "${newest_stamp:6:2}" \
    "${newest_stamp:9:2}" "${newest_stamp:11:2}" "${newest_stamp:13:2}" \
    "$label" "${newest#"$ROOT"/}"
}

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

  # Named rather than left to fall through: without git every probe below fails
  # the same way a plugin outside a clone does, and the note would report this
  # machine's missing tool as a fact about the user's plugin.
  if ! on_path git; then
    SRC_NOTE="git is not on PATH, so the plugin's own history cannot be read"
    return 1
  elif ! runs git; then
    SRC_NOTE="git is at $(command -v git) but would not run, so the plugin's own history cannot be read"
    return 1
  fi

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
  # A survey that cannot name the plugin version is not a survey: the whole
  # audit rests on that number, and reporting `(unversioned)` at rc=0 is a
  # clean bill of health against templates that may have moved.
  require perl python3
  resolve_root

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
audited      $(audit_history)

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

# ------------------------------------------------------------------ collapse

cmd_collapse() {
  [ -n "$AGENT" ] && [ -n "$WHAT" ] || usage
  require perl python3
  resolve_root
  roster_seat "$AGENT"

  local dir="$ROOT/$SEAT_FOLDER" live template
  case "$WHAT" in
    frame|jd) live="$dir/CLAUDE.md";             template="templates/agent/CLAUDE.md" ;;
    settings) live="$dir/.claude/settings.json"; template="templates/agent/settings.json" ;;
    *) die "unknown --what: $WHAT. Expected frame, jd or settings." ;;
  esac
  [ -f "$live" ] || die "no such file: $live"
  [ -r "$live" ] || die "$live cannot be read — check its permissions"
  [ -f "$PLUGIN/$template" ] || die "the plugin has no template at $template"
  [ -r "$PLUGIN/$template" ] || die "the template $template cannot be read — check its permissions"

  WHAT="$WHAT" LIVE="$live" SHAPE="$PLUGIN/$template" \
  SEAT_NAME="$SEAT_NAME" SEAT_TITLE="$SEAT_TITLE" SEAT_FOLDER="$SEAT_FOLDER" \
  python3 - <<'COLLAPSE'
import json
import os
import re
import sys

what = os.environ["WHAT"]
live_path = os.environ["LIVE"]
shape_path = os.environ["SHAPE"]

PLACEHOLDER = re.compile(r"\{\{(\w+)\}\}")


def die(message):
    sys.stderr.write("agency-audit: %s\n" % message)
    raise SystemExit(1)


def note(message):
    sys.stderr.write("agency-audit: %s\n" % message)


def read(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


live = read(live_path)
shape = read(shape_path)

if what == "settings":
    # The template is the authority on which values were substituted: a leaf
    # that is nothing but a placeholder marks a path whose live value is this
    # seat's own. Everything else the live file carries passes through, so a
    # key someone added stays a real difference rather than being tidied away.
    try:
        document = json.loads(live)
    except ValueError as error:
        die("%s does not parse as JSON: %s" % (live_path, error))
    try:
        wanted = json.loads(shape)
    except ValueError as error:
        die("the template %s does not parse as JSON: %s" % (shape_path, error))

    def placeholder_paths(node, path=()):
        if isinstance(node, dict):
            for key, value in node.items():
                for found in placeholder_paths(value, path + (key,)):
                    yield found
        elif isinstance(node, list):
            for index, value in enumerate(node):
                for found in placeholder_paths(value, path + (index,)):
                    yield found
        elif isinstance(node, str) and PLACEHOLDER.fullmatch(node):
            yield path, node

    for path, placeholder in placeholder_paths(wanted):
        node = document
        for step in path[:-1]:
            node = node.get(step) if isinstance(node, dict) else None
        leaf = path[-1]
        if isinstance(node, dict) and leaf in node:
            node[leaf] = placeholder
        else:
            note("%s has no %s, so there was nothing to put %s back over"
                 % (live_path, ".".join(str(step) for step in path), placeholder))

    sys.stdout.write(json.dumps(document, indent=2, ensure_ascii=False) + "\n")
    raise SystemExit(0)

# Where the job description sits is read off the template rather than written
# down anywhere: the literal run before {{JD}} is what closes the heading, and
# the run after it is what opens the next section. The description is
# everything between them, and the blank line before that section belongs to
# the section, not to the description.
marker = "{{JD}}"
at = shape.find(marker)
if at < 0:
    die("the template %s carries no %s, so there is no job description to collapse"
        % (shape_path, marker))

opens = PLACEHOLDER.split(shape[:at])[-1]
closes = re.match(r"\A\n*[^\n]*", PLACEHOLDER.split(shape[at + len(marker):])[0]).group(0)
if not opens or not closes.strip():
    die("%s puts %s against nothing that can be found in a rendered copy"
        % (shape_path, marker))

start = live.find(opens)
if start < 0:
    die("%s does not open the way %s does, so where its job description begins "
        "cannot be found. The base cannot be determined." % (live_path, shape_path))
start += len(opens)

end = live.find(closes, start)
if end < 0:
    die("%s carries no %r after its job description, so where the description "
        "ends cannot be found. The base cannot be determined."
        % (live_path, closes.strip()))

if what == "jd":
    # render substituted $(cat <file>), which drops the trailing newline. Put
    # it back, so this compares against a job description as a file.
    sys.stdout.write(live[start:end] + "\n")
    raise SystemExit(0)

# The two halves of the frame, held apart so a value can never be looked for
# inside the {{JD}} that replaces what was between them.
pieces = [live[:start], live[end:]]

# Longest value first, so one carrying another inside it — a folder holding the
# agent's name — is put back whole before its parts are looked for.
values = [
    ("AGENT_FOLDER", os.environ.get("SEAT_FOLDER", "")),
    ("AGENT_NAME", os.environ.get("SEAT_NAME", "")),
    ("TITLE", os.environ.get("SEAT_TITLE", "")),
]
for name, value in sorted(values, key=lambda pair: len(pair[1]), reverse=True):
    if not value:
        continue
    placeholder = "{{%s}}" % name
    seen = sum(piece.count(value) for piece in pieces)
    if seen > 1:
        die("%r appears %d times in %s outside the job description. Every "
            "template here substitutes a value once, so which occurrence is "
            "%s cannot be told and a collapse would be a guess. The base "
            "cannot be determined." % (value, seen, live_path, placeholder))
    if seen == 1:
        pieces = [piece.replace(value, placeholder) for piece in pieces]
    elif placeholder in shape:
        # Nothing was put back, so something else is standing where the
        # placeholder belongs and would reach `base` still rendered. Unlike a
        # key a JSON file does not have, an absence here cannot be written
        # down: this collapse is directed by value, and a value that is not
        # there leaves the output claiming a template shape it does not have.
        die("%s substitutes %s, but %r — what the roster gives this seat — is "
            "nowhere in %s outside the job description. Whatever stands in its "
            "place would reach `base` still rendered, so the base cannot be "
            "determined. The profile and the roster disagree about this value."
            % (shape_path, placeholder, value, live_path))

sys.stdout.write(pieces[0] + marker + pieces[1])
COLLAPSE
}

# ---------------------------------------------------------------------- base

cmd_base() {
  [ -n "$FILE" ] && [ -n "$TEMPLATE" ] || usage
  FILE="$(expand "$FILE")"
  [ -f "$FILE" ] || die "no such file: $FILE"
  [ -r "$FILE" ] || die "$FILE cannot be read — check its permissions"
  [ -f "$PLUGIN/$TEMPLATE" ] || die "the plugin has no template at $TEMPLATE"
  [ -r "$PLUGIN/$TEMPLATE" ] || die "the template $TEMPLATE cannot be read — check its permissions"

  # How to compare is a property of the template, not of the file handed over:
  # the template lives inside the plugin and its extension is the plugin
  # author saying what the format is, while --file is a scratch path the
  # caller invented and its name says nothing. --json stays for a JSON
  # template that is not named like one.
  if [ "$JSON" = "auto" ]; then
    case "$TEMPLATE" in
      *.json) JSON="yes" ;;
      *)      JSON="no" ;;
    esac
  fi

  require shasum
  [ "$JSON" = "no" ] || require python3

  # Which of the two possible failures it was, before either side is hashed.
  parses "$FILE" "$FILE"
  parses "$PLUGIN/$TEMPLATE" "the template $TEMPLATE"

  local live now
  live="$(digest_of "$FILE")" || die "$FILE canonicalises but could not be hashed"
  now="$(digest_of "$PLUGIN/$TEMPLATE")" || die "the template $TEMPLATE canonicalises but could not be hashed"

  printf 'template     %s\n' "$TEMPLATE"
  printf 'file         %s\n' "$FILE"
  printf 'compared     %s\n' "$([ "$JSON" = "yes" ] && printf 'as JSON' || printf 'byte for byte')"

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
  require shasum
  FILE="$(expand "$FILE")"
  FROM="$(expand "$FROM")"
  [ -f "$FROM" ] || die "no such file: $FROM"
  [ -r "$FROM" ] || die "$FROM cannot be read — check its permissions"
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
  survey)   cmd_survey ;;
  collapse) cmd_collapse ;;
  base)     cmd_base ;;
  apply)    cmd_apply ;;
esac
