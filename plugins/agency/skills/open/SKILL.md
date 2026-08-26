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

The agency root must not already exist. If `roster.yaml` is there, stop and
tell the user the agency is already open — do not merge, repair, or migrate.
Adding agents to an existing agency, and migrating an older layout, are
separate jobs.

## Interview

Prepare first, so the user sees concrete defaults rather than blanks:

```
${CLAUDE_PLUGIN_ROOT}/scripts/random-name.sh          # a name to suggest
cat ${CLAUDE_PLUGIN_ROOT}/templates/jd/ea.md          # the default job description
```

Then ask:

1. **Where should the agency live?** Default `~/agency`.
2. **What should this agent be called?** Suggest the generated name. Any
   lowercase `[a-z0-9_-]` name works. The name is an identity, not a job title —
   the title is a separate field, so a neutral name is fine.
3. **Show the default job description in full**, then ask whether to use it as
   is or how they want it changed. Take whatever they give you: a note to
   rewrite a section, a replacement, additions, a different role entirely. Do
   not compress their answer into one line and do not cap its length — this
   text becomes the agent's profile and shapes everything it does.

If they change the role substantially, set a title to match. Otherwise the
title is `Executive Assistant`.

Do not ask about permissions, budgets, or conventions. Agents are created in
`auto` permission mode via their own `.claude/settings.json`, and shared
conventions come from the agency's `CLAUDE.md`. Both are files the user can
edit afterwards.

## Open it

Write the final job description to a file, then run:

```
${CLAUDE_PLUGIN_ROOT}/scripts/agency-init.sh \
  --root <root> --jd-file <path> [--name <name>] [--title <title>]
```

Omit `--name` to let it pick a random one. It creates the tree, assigns the
session id, writes `roster.yaml`, and makes the agency root a local git
repository with no remote — history for the roster without any sharing risk.

## Report

Show the tree that was created, then the two commands the script printed: how
to start the agent for the first time, and how to resume it.

Point out that the agent's profile (`agents/<name>/CLAUDE.md`) and the agency's
shared conventions (`CLAUDE.md`) are meant to be edited by hand as the role
takes shape.
