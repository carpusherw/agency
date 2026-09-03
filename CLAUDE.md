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

## Layout

```
.claude-plugin/marketplace.json
plugins/agency/
  .claude-plugin/plugin.json
  skills/open/SKILL.md         the interview
  skills/hire/SKILL.md         the interview for a second seat
  skills/audit/SKILL.md        the comparison against an agency already open
  scripts/agency-init.sh       the deterministic scaffold
  scripts/agency-hire.sh       the same, for hiring into an open agency
  scripts/agency-audit.sh      root, roster, base revision, and applying a patch
  templates/agency/            shared CLAUDE.md, roster.yaml
  templates/agent/             profile, STATE.md, settings.json
  templates/jd/ea.md           default executive-assistant job description
```

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
  survives byte-exact, variation selectors included, so an agency's logoji is
  restricted to a single glyph and the script rejects the rest.
- **An `AskUserQuestion` option carrying a `preview` costs the question its
  `Type something.` row.** The preview switches the prompt to a side-by-side
  layout and the typed-answer row does not come with it, so a question that
  needs a free-typed answer cannot also preview its options. Option count is not
  the constraint — four options and the row coexist.
- **`--name` is remembered by the session, and passing it again forks a copy.**
  It sets the title shown in `claude agents`, and a resumed session comes back
  under the name it was started with. Passing it anyway — or any other flag
  beyond `--bg --resume <full id>` — starts a *copy* under a new id instead of
  resuming: the conversation comes across, whatever harness state the session was
  holding does not, and nothing says so. A new session must be given a name; a
  resume must not. `hire --resume-session` passes one deliberately and forks for
  that reason — taking the agency's name is the point of being hired.
- **A foreground `claude` cannot be launched from inside a tool call.** It wants
  a terminal and a person, so it hangs or returns nothing. Anything an agent is
  told to run must be `--bg` or `-p`.
  Inferred rather than observed — the only line here that is.
- **A stopped session resumed from another directory adopts it.** It takes that
  directory as its working directory and loads the `CLAUDE.md` there *and* in
  every parent, while keeping its whole conversation. This is what lets a
  long-running session be hired into a seat instead of rebuilt.
- **A session running as a background agent cannot be resumed elsewhere.** The
  attempt is refused, naming two ways out: stop it, or `--fork-session` to
  branch a copy. Relocating a live session means stopping it first.
- **`--bg --resume <full id>` resumes in place** — same id, same name, and the
  session's task list comes back with its statuses intact. A new id appears only
  when the launch carries a flag that forks a copy, and a copy starts with an
  empty task list while its conversation looks untouched. So a plain resume needs
  no roster write at all.
- **`--resume` with a shortened id does not resume anything.** It matches nothing
  and waits in the interactive session picker, so from inside a tool call it hangs
  exactly as a foreground `claude` does. Pass the id in full and lowercase, as
  `claude agents --json` prints it.
- **An untrusted workspace ignores `permissions.allow` entries**, warning that it
  did. A freshly scaffolded agent folder is untrusted, so a seat scoped by an
  allow or deny list needs `projects[<dir>].hasTrustDialogAccepted` in
  `~/.claude.json`. `defaultMode` applies either way. Whether `deny` survives
  an untrusted workspace is untested.
- **`auto` permission mode is unavailable on Haiku 4.5.** The session falls back
  to manual mode, so a seat written as `auto` is not `auto` on a small model.

## Scope

Opening an agency, hiring into it, and auditing one against the templates it
was rendered from are covered. Archiving, renaming, and migrating an older
layout are absent on purpose. Add them when something real needs them, not in
anticipation — the same reason there are no hooks, budgets, or headcount limits
yet.

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
