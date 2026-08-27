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
- **Agents run in the background, and only there.** `--bg` makes a session that
  `claude agents` lists and `claude attach <id>` opens interactively, so the
  foreground buys nothing and is not a second supported path.
- **`--bg` assigns its own session id and ignores `--session-id`**, warning
  `--bg manages the session id`. An id therefore cannot be chosen in advance;
  it is read back from `claude agents --json` after launch, matched on the
  agent's directory, and that is what the roster stores.
- **`--continue` does not work with `--bg`.** It exits with `No conversation
  found to continue` and the worker crash-loops. Agents are resumed by id.
- **A background session that is never prompted does not survive.** It writes no
  transcript, drops out of `claude agents`, and its id cannot be resumed — so
  the scaffold sends a first prompt rather than leaving the agent idle. One
  exchange is enough to make the session durable.
- **A session name loses a zero-width joiner.** U+200D is replaced with a
  space, so a combined emoji such as 🧑‍💼 arrives as `🧑 💼`. Everything else
  survives byte-exact, variation selectors included, so agency emoji are
  restricted to a single glyph and the script rejects the rest.
- **An `AskUserQuestion` option carrying a `preview` costs the question its
  `Type something.` row.** The preview switches the prompt to a side-by-side
  layout and the typed-answer row does not come with it, so a question that
  needs a free-typed answer cannot also preview its options. Option count is not
  the constraint — four options and the row coexist.
- **`--name` is per launch, not stored with the session.** It sets the title
  shown in `claude agents`; omit it on a resume and the view retitles the
  session from its content. Anything that launches an agent must pass it every
  time.
- **A foreground `claude` cannot be launched from inside a tool call.** It wants
  a terminal and a person, so it hangs or returns nothing. Anything an agent is
  told to run must be `--bg` or `-p`.

## Scope

v1 opens an agency and hires one agent. Hiring more, archiving, renaming, and
migrating an older layout are all absent on purpose. Add them when something
real needs them, not in anticipation — the same reason there are no hooks,
budgets, or headcount limits yet.

## Versioning

A plugin's version lives in `plugins/<name>/.claude-plugin/plugin.json`, and
that manifest is the source of truth for everything the marketplace shows.
`.claude-plugin/marketplace.json` is **generated** from it — never hand-edit its
`plugins` array, or the two drift and the marketplace advertises something the
plugin is not.

**Every change under `plugins/` is a change to the plugin.** A skill's wording,
a template, a script, a job description: if it ships to a user, it is the
plugin, and the version moves. Semantic versioning — MAJOR for a breaking
change, MINOR for a new capability, PATCH for a fix.

So a change to a plugin is three edits, not one:

```
# 1. make the change under plugins/<name>/
# 2. bump "version" in plugins/<name>/.claude-plugin/plugin.json
python3 scripts/build_marketplace.py    # 3. regenerate, and commit the result
```

Both halves are enforced on every pull request by
`.github/workflows/plugin-checks.yml`: one job fails if a plugin directory
changed without its version moving, the other fails if `marketplace.json` does
not regenerate byte-identical to what is committed.

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
