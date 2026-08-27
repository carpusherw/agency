---
name: open
description: Open a new agency — an office of long-lived agents, each with its own folder, profile, permission scope, and durable file state — and hire its first agent. Use when the user asks to open, start, bootstrap, or set up an agency, or says "/agency:open". Not for adding an agent to an agency that already exists.
---

# open

Opens an agency and hires its first agent.

An agency is a directory of long-lived agents. Each agent gets a folder, a
profile (`CLAUDE.md`), its own permission scope (`.claude/settings.json`), a
state file it maintains across sessions, and a fixed session id so it can be
resumed rather than restarted. Sessions are disposable; identity and memory
live in files.

## Gate

The agency root must be empty or absent. If it holds a `roster.yaml`, the
agency is already open — say so and stop. Do not merge, repair, or migrate.
Adding agents to an existing agency, and migrating an older layout, are
separate jobs.

## Interview

### 1. What is the agency called?

Suggest a few, drawn from what this person actually works on — the
conversation, the repositories around them, or by asking what the agency is
for. An office has a name, not a job description, so something with a little
character beats something literal.

Include a "let me name it myself" choice alongside them, spelled out as one of
the choices — the interface's own free-text option appears on some questions and
not others, so do not rely on it. Whatever they answer is the name, including
something that means nothing to you.

Pair each suggestion with an emoji, so the choice is the whole prefix rather
than half of it. If they name the agency themselves, suggest an emoji for it
afterwards.

Show what the pair becomes, so the choice is concrete — this is the prefix on
every agent's session in `claude agents`:

```
🏢 [MIB]: Agent O
```

The emoji must be a single one, with no zero-width joiner. A combined emoji
like 🧑‍💼 — person, joiner, briefcase — is split apart in a session name and
arrives as `🧑 💼`. The script rejects those, so suggest one glyph: 🏢 💼 🎩 🛰
🗂 🧭 ✨ all survive intact.

### 2. Where should the agency live?

Default `~/agency`.

### 3. What should this agent be called?

Suggest a few — short, pronounceable, reading as an identity rather than a role
— and carry the same "let me name it myself" choice. Any name a directory can
hold works, in any language; it does not have to be English or lowercase. The
name is an identity, not a job title: the title is a separate field, so it does
not need to describe the work.

### 4. What is this agent for?

Start from the default executive-assistant job description:

```
cat ${CLAUDE_PLUGIN_ROOT}/templates/jd/ea.md
```

Show it in full and ask whether to use it as is, or what to change.

**Then iterate.** A vague answer — "make it more hands-on", "it should handle
my email too", "less formal" — is a normal answer, not a request for
clarification. Rewrite the job description yourself to match it, show the new
version, and ask again. Keep going until the user accepts it. Do not hand the
drafting back to them, do not ask them to write the text, and do not cap the
length. This becomes the agent's profile and shapes everything it does.

If the role drifts away from an executive assistant, set a title to match.
Otherwise the title is `Executive Assistant`.

Do not ask about permissions or conventions. This first agent is an executive
assistant — it routes and acts on the person's behalf, so `auto` permission
mode fits it, set in its own `.claude/settings.json`. That is this seat's
default, not the agency's rule: a later agent can be scoped differently in its
own settings file. Shared conventions come from the agency's `CLAUDE.md`. Both
are files the user can edit afterwards.

## Open it

Write the accepted job description to a file, then run:

```
${CLAUDE_PLUGIN_ROOT}/scripts/agency-init.sh \
  --root <root> --agency <agency name> --name <name> --jd-file <path> \
  [--emoji <emoji>] [--title <title>]
```

It creates the tree, starts the agent as a background session, reads back the
session id it was given, and writes `roster.yaml`.

The agent is started rather than left for the user to launch because `--bg`
assigns its own session id: the roster can only record a real one by reading it
back afterwards. If the launch fails the script still succeeds — the agency is
written, `session_id` is left null, and the report says how to start the agent
by hand.

## Report

Show the tree that was created, then tell the user their agent is already
running in the background — that `claude attach <id>` opens it in the terminal,
that it also appears in `claude agents`, and how to start it again if it is ever
stopped. The script prints all of these.

Point out that the agent's profile (`agents/<name>/CLAUDE.md`) and the agency's
shared conventions (`CLAUDE.md`) are meant to be edited by hand as the role
takes shape.
