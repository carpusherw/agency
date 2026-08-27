# Agency

This directory is an agency: a set of long-lived agents, each with its own
folder, profile, and durable state.

Sessions are disposable. Identity and memory live in files.

## Layout

- `roster.yaml` — who exists, where their folder is, their fixed session id.
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

Everyone here runs as a background session, so `claude agents --json` is the
live view of the office and `roster.yaml` says which of those sessions are
agents. Match the two by session id.

- **If it is listed, message it.** `SendMessage` reaches any live session,
  including one sitting idle waiting for a prompt. Idle is not stopped.
- **If it is not listed, start it again** from its own folder, in the
  background, so it keeps its profile and permissions:

  ```
  cd "<agency>/agents/<name>" && claude --bg --resume <session_id> --name "<display_name>"
  ```

  Take `session_id` and `display_name` from that agent's entry in
  `roster.yaml`, verbatim — the display name carries the agency's emoji and
  name, so composing it by hand gets it wrong. Quote both it and the path: an
  agent may be called anything a directory can hold, spaces included, and
  unquoted they split into separate arguments. Pass `--name` every time —
  without it the agents view retitles the session after its contents and the
  office stops being recognisable.

Never start an agent with a bare `claude` or `claude --continue`. Those open an
interactive session and expect a person at a terminal; from inside a tool call
they hang or return nothing. `--bg` returns immediately, and `-p --resume <id>`
works for a single question.
