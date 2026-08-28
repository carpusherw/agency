---
name: hire
description: Hire another agent into an agency that already exists — either from a long-running session, which keeps its conversation and moves into the new seat, or from a job description worked out with the user. Use when the user asks to hire, add, or take on another agent, or says "/agency:hire". Not for opening an agency, which is agency:open.
---

# hire

Adds a seat to an agency that already exists.

The agent gets a folder, a profile (`CLAUDE.md`), its own permission scope
(`.claude/settings.json`), and a state file it maintains, exactly as the first
one did. What is new here is that the agency already has a roster to join, and
that the agent can come from a session the user is already running.

## Gate

There must be an agency: `<root>/roster.yaml`. If the root holds no roster,
nothing is open yet — say so and point at the `agency:open` skill. Do not open
one here.

Read the roster before the interview. It carries the agency's name and logoji,
and who is already in the office; the interview needs both.

## Which kind of hire

Two ways in. They differ only at the start, and converge once the job
description, the name, and the scope are settled.

### From a session that is already running

`claude agents --json` lists every live session, and the user will usually name
the one they mean. Show what you found before going further: its name, its
working directory, how long it has been running.

A stopped session resumed from an agent folder adopts that folder — its profile,
the agency conventions above it, and its permission scope — while keeping its
entire conversation. So this is a relocation, not a rebuild, and **the interview
is not a context transfer.** What you are drawing out is the job description.
Ask the session directly with `SendMessage`: what it does, what it owns, what
recurs, what someone taking over would otherwise have to rediscover. Its answer
is your raw material, not the final text.

Then draft the job description yourself and iterate with the user, as below.

Before anything is created, tell the user the session has to be stopped to be
relocated, and get an explicit yes. A running background session cannot be
resumed into another directory; the harness refuses it. Stop it with
`claude stop <short id>` only once they have agreed, and never as a side effect
of some other step.

### From a job description

The user describes the job, or hands you text. Start from what they gave you and
show a draft.

## The job description

**Iterate.** A vague answer — "make it more hands-on", "it should watch CI too",
"less formal" — is a normal answer, not a request for clarification. Rewrite the
job description yourself to match it, show the new version, and ask again. Keep
going until the user accepts it. Do not hand the drafting back to them, do not
ask them to write the text, and do not cap the length. This becomes the agent's
profile and shapes everything it does.

Keep it to this role. Anything true of every agent already reaches it from the
agency's `CLAUDE.md`, and restating it here is duplication.

Set a title that matches the role.

## Naming

Read the whole roster, not just the agency's name. The names already in it carry
the theme: `Round Table` plus an agent called Merlin means knights, and `MIB`
plus `Agent O` means `Agent <letter>`. Suggest a few that fit the theme, the job,
and what this person actually works on, and say what the theme is, so the user
can send it somewhere else.

If no theme is discernible, suggest short, pronounceable names that read as an
identity rather than a role. Any name a directory can hold works, in any
language. The user may take one, ask for more, or change the theme the
suggestions come from — keep going until they settle on a name.

Never suggest a name already in the roster or already on disk. Avoid an
all-non-ASCII name the same length as one already there: Claude Code derives a
project directory by replacing every non-alphanumeric character with `-`, so two
such names resolve to one directory and share a memory store.

## What this seat may do without asking

Ask. The first seat is an executive assistant and gets `auto` without a
question, but a later agent's scope is a real choice — suggest one from the job
description and let the user settle it.

- `default` — asks before acting. A background agent in this mode blocks on its
  first tool call, so choose it only for a seat someone will attend to.
- `acceptEdits` — edits files without asking, asks for the rest. It still blocks
  on reading anything outside its own folder, the agency's roster included, so
  it suits a seat that works within its own directory and has someone attending.
- `auto` — acts on the user's behalf, and the only one of these a background
  seat runs unattended on. What an assistant or an operator wants.
- `plan` — reads and plans, changes nothing.

The mode is enforced because it lives in the seat's own `settings.json`. A limit
written into a profile is a suggestion.

If the seat needs more than a mode — a specific allow or deny list — say that
those entries are ignored until the folder is a trusted workspace, and ask
whether to mark it trusted as part of the hire. That is a change to the user's
global config, so it happens only if they say yes: pass `--trust`. If they
decline, write the settings anyway and tell them plainly that the entries are
inert until the folder is trusted.

## Hire

Write the accepted job description to a file, then run:

```
${CLAUDE_PLUGIN_ROOT}/scripts/agency-hire.sh \
  --root <root> --name <name> --jd-file <path> \
  [--title <title>] [--permission-mode <mode>] [--trust] \
  [--resume-session <session id>]
```

It creates the seat, starts the agent, reads back the session id it was given,
and appends the entry to the roster.

Resuming under `--bg` mints a new session id and keeps the conversation, so a
relocated seat is recorded under its new id, not the one it was hired from.

If the launch fails the script still succeeds — the seat is written, the roster
entry says `session_id: null`, and the report says how to start it by hand.

## Report

Show where the seat was created and that the agent is already running: that
`claude attach <id>` opens it, that it appears in `claude agents`, and how to
start it again if it is ever stopped. The script prints all of these.

For a relocation, say which session it came from and that the old id no longer
runs — the seat carries that conversation now.

Tell the agency's roster owner that someone new is in the office, if that is not
who ran this.
