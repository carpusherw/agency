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

## Reaching an agent that is not running

`SendMessage` only reaches a live session; `claude agents --json` says who is
live right now. To reach one that is not:

```
cd <agency>/agents/<name> && claude --continue
```

That resumes the agent's most recent session from its own folder. Its
`session_id` in `roster.yaml` is the durable address when you need to name one
exact session (`claude --resume <id>`).
