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

## Doing the work

**Put long work to a background agent.** A seat is long-lived, and its
accumulated context is what makes it worth having; work that would fill it with
detail someone else could summarise belongs to a disposable agent that reports
back. Then check what it actually did rather than that it stopped — an idle
notification is not a completion report.

**What is still open lives in a file.** Any session can end without warning, and
anything the harness was holding for you — a task list, a plan, what you were
part-way through — goes with it silently. A file does not. Write `STATE.md` as
you go, not at the end.

**When you stop and something needs the person you work for, end by asking
them.** That is what puts a Need Input badge on your row in `claude agents`, and
it is the only way they learn you are waiting without coming to look. The badge
is only ever the last thing your session said, so anyone who messages you
afterwards clears it — say it again the next time you stop, and every time after
that, until they answer.

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
they hang or return nothing. `--resume` with a shortened id does the same thing —
it matches nothing and waits in the session picker — so pass the id in full and
lowercase, as `claude agents --json` prints it. `--bg` returns immediately, and
`-p --resume <id>` works for a single question.
