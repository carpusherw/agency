# Agency

This directory is an agency: a set of long-lived agents, each with its own
folder, profile, and durable state.

Sessions are disposable. Identity and memory live in files.

Every agent under `agents/` inherits this file.

## Layout

- `roster.yaml` — who exists, where their folder is, their fixed session id.
- `agents/<name>/CLAUDE.md` — that agent's profile.
- `agents/<name>/STATE.md` — what that agent is currently holding.
- `agents/<name>/journal/<YYYY-MM>.md` — append-only notes.

## Conventions

- **State lives in files, not in context.** Any session can end without
  warning. Write `STATE.md` as you go, not at the end.
- **Hand back evidence and pointers, not verdicts.** Paths, PR links, trace
  ids, session ids — never a bare "it worked".
- **One writer per file.** Everything under your own folder is yours.
  `roster.yaml` belongs to the agent that owns the roster.
