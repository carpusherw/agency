# Working on this repo

This repo is the **mechanism**: a Claude Code plugin that opens agencies. An
**agency** is the instance it produces — a directory of agents somewhere else on
the user's machine, holding their roster, profiles, and memory.

Nothing about anyone's agency belongs in this repo. That is why `roster.yaml`
exists only as a template here: check a real one in and the next person to clone
this inherits someone else's staff. Any new skill has to keep that line —
mechanism here, instance under the agency root.

Note the name collision when reading paths: `CLAUDE.md` at this repo root is
*this* file, for working on the plugin. `templates/agency/CLAUDE.md` is the one
that ends up in a user's agency.

## Where a rule belongs

An agency has three layers of instruction, and every layer is loaded from a
different place. Putting a rule in the wrong one is the easiest mistake to make
here, because the result still works — it is just duplicated, or invisible.

| Layer | File | Holds |
| ----- | ---- | ----- |
| Agency | `<agency>/CLAUDE.md` | Anything true for every agent: how agents deal with each other, where state lives, how to reach a session |
| Agent | `<agency>/agents/<name>/CLAUDE.md` | Only what is specific to that role — what it owns, what it decides |
| Permissions | `<agency>/agents/<name>/.claude/settings.json` | What that agent may do without asking |

Claude Code reads `CLAUDE.md` from the working directory *and* every parent, so
an agent already carries the agency layer. Restating an agency-wide rule inside
a role's profile or job description is duplication, not emphasis — cut it and
let the inheritance do the work. Permissions are not prose: a limit stated only
in a profile is a suggestion, while one in `settings.json` is enforced.

## Claude Code behaviour this depends on

Verified on macOS. Each of these shapes a design decision, and guessing at them
produces something that looks right and is not.

- **`CLAUDE.md` is inherited from parent directories.** This is what makes the
  three-layer split work at all.
- **`--session-id` must be a UUID.** `claude --session-id agency-ea` fails with
  `Invalid session ID. Must be a valid UUID.` Agent names cannot be session ids.
- **`--continue` resumes the most recent session in the current directory.**
  Since every agent has its own directory, this is how an agent is resumed —
  the user never types an id.
- **Per-project storage is keyed on the path.** Claude Code derives a directory
  under `~/.claude/projects/` from the absolute path with every non-alphanumeric
  character replaced by `-`, and keeps session transcripts and auto-memory
  there. Sessions record their own `cwd` and are told apart by it; memory is not,
  so paths that collapse to the same slug share one memory store.
- **Renaming an agent folder breaks `--continue` and strands its memory**, because
  the slug changes. `--resume <uuid>` still works. The repair is to move the
  project directory to the new slug — verified sufficient on its own, with no
  edit to the transcripts.

## Scope

v1 opens an agency and hires one agent. Hiring more, archiving, renaming, and
migrating an older layout are all absent on purpose. Add them when something
real needs them, not in anticipation — the same reason there are no hooks,
budgets, or headcount limits yet.

## Verifying a change

Running `agency-init.sh` on a clean path proves very little; the bugs live in
the inputs. Before claiming a change works, open an agency with all three at
once:

- a root containing a space, a `#`, and a `: ` — e.g. `team #1: ops`
- an agent name that is non-ASCII and contains a space — e.g. `行政 助理`
- a title containing a quote, a colon, and a backslash

Then check that `roster.yaml` still parses as YAML and every value round-trips
byte-exact, that the printed commands survive copy-paste, and that the agent
actually boots and resumes.
