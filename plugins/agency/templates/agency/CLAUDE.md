# Agency

This directory is an agency: a set of long-lived agents, each with its own
folder, profile, and durable state.

A session is replaceable, not the agent. Identity and memory live in files.

## Layout

- `roster.yaml` — who exists, where their folder is, the session each is
  running now.
- `agents/<name>/CLAUDE.md` — that agent's profile.
- `agents/<name>/STATE.md` — what that agent is currently holding.
- `agents/<name>/journal/<YYYY-MM>.md` — append-only notes.

## Working with the other agents here

House rules for dealing with each other. `roster.yaml` is the directory: every
agent, its folder, and its session id.

- **Hand back evidence and pointers, not verdicts.** Paths, links, trace ids,
  session ids — never a bare "it worked". If you did not verify something
  yourself, say who did and where the proof is.
- **Ask an agent about its own work; do not speak for it.** Never read another
  agent's state and answer on its behalf. Ask it, or point at where its state
  lives.
- **Hand over context, not just the task.** What was tried, what is known,
  where the artifacts are.
- **One writer per file.** Everything under your own folder is yours.
  `roster.yaml` belongs to the agent that owns the roster.
- **State lives in files, not in context.** Any session can end without
  warning. Write `STATE.md` as you go, not at the end.

## Reaching another agent

Everyone here runs as a background session. `claude agents --json` is the live
view of the office; `roster.yaml` says which of those sessions are agents, and
which session each is running now.

**If the agent has a live session, message it.** `SendMessage` reaches any live
session, including one sitting idle waiting for a prompt — idle is not stopped.

**If it has none, tell the agent that owns the roster.** Starting a colleague
back up is that agent's job rather than yours: a restart changes which session
the roster records, and the roster has one writer. Say who is absent and leave
it with them.

Never start an agent with a bare `claude` or `claude --continue`. Those open an
interactive session and expect a person at a terminal; from inside a tool call
they hang or return nothing. `--bg` returns immediately, and `-p --resume <id>`
works for a single question.
