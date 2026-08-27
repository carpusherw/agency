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

### 1. Where should the agency live?

Default `~/agency`.

### 2. What should this agent be called?

Invent a name and offer it, rather than asking the user to produce one cold —
something short and pronounceable that reads as an identity. Any name a
directory can carry works, in any language; it does not have to be English or
lowercase. The name is an identity, not a job title — the title is a separate
field, so it does not need to describe the work.

### 3. What is this agent for?

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

Do not ask about permissions or conventions. Agents are created in `auto`
permission mode via their own `.claude/settings.json`, and shared conventions
come from the agency's `CLAUDE.md`. Both are files the user can edit
afterwards.

## Open it

Write the accepted job description to a file, then run:

```
${CLAUDE_PLUGIN_ROOT}/scripts/agency-init.sh \
  --root <root> --name <name> --jd-file <path> [--title <title>]
```

It creates the tree, assigns the session id, and writes `roster.yaml`.

## Report

Show the tree that was created, then the two commands the script printed: how
to start the agent for the first time, and how to resume it afterwards with
`claude --continue` from its own folder.

Point out that the agent's profile (`agents/<name>/CLAUDE.md`) and the agency's
shared conventions (`CLAUDE.md`) are meant to be edited by hand as the role
takes shape.
