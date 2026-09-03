# agency

An office of long-lived agents. It adds no infrastructure of its own — an
agency is a directory, and the agents are ordinary Claude Code sessions.

An **agency** is a directory of agents. Each agent has its own folder, its own
profile (`CLAUDE.md`), its own permission scope (`.claude/settings.json`), a
state file it maintains, and its own project memory and session history —
Claude Code keys those to the folder.

The design premise: **persistent identity, replaceable sessions.** An agent's
session may run for months, but it is never the agent: it can end at any time,
and a new one started in the same folder comes back whole. Continuity lives in
files.

This repo is the mechanism, a shareable plugin of skills, templates and scripts.
Your agency is instance state and lives elsewhere — `~/agency` by default. It is
never checked in here, and what you do with it afterwards is yours to decide.

## Quick start

```
claude plugin marketplace add carpusherw/agency
claude plugin install agency@agency
```

Then, in Claude Code:

```
/agency:open
```

It names the agency and picks its **logoji** — one emoji that marks every
session the agency runs — asks where it lives, offers a name for the first agent
(anything a directory can carry, in any language — see [Naming](#naming)), and
works with you on that agent's job description until you accept it. Then it
creates:

```
~/agency/
  CLAUDE.md                    inherited by every agent
  roster.yaml                  the agency's name and logoji, and who exists
  agents/<name>/
    CLAUDE.md                  the agent's profile, from the job description
    STATE.md                   what it is currently holding
    journal/<YYYY-MM>.md       append-only notes
    .claude/settings.json      its permission scope
```

**Your agent is already running when that finishes.** Agents are background
sessions, so the office is `claude agents`, and you open one with:

```
claude attach <id>        # opens it in this terminal; Ctrl+Z drops back out
```

The session keeps running either way.

## Hiring another agent

```
/agency:hire
```

Adds a seat to an agency that is already open. It works out the job
description with you, suggests names that fit the agency's theme — the roster
carries it, so `Round Table` plus an agent called Merlin means knights —
asks what the seat may do without asking, then creates it, starts it, and
appends it to the roster.

An agent can also be hired **from a session you are already running**. A stopped
session resumed from an agent folder adopts that folder — its profile, the
agency conventions above it, its permission scope — while keeping its entire
conversation. So a long-running session becomes a seat without losing anything,
and the interview only has to work out its job description. The session has to
be stopped to be moved, which the skill asks you about first.

Once there is more than one, agents reach each other with `SendMessage`, by the
name their sessions carry in `claude agents`.

## When an agent stops

Sessions end, and that is the premise rather than a failure: the agent is its
folder, so it comes back whole, and `STATE.md` and its journal carry whatever it
was holding.

Telling your executive assistant is enough — the roster is theirs, and starting a
colleague back up is their job. To do it yourself, launch it from its own folder,
which is what gives the session its profile, the agency conventions it inherits,
and its permission scope:

```
cd <agency root>/agents/<agent.name>
claude --bg --resume <session_id>
```

The root is the one thing you supply — where you opened the agency, `~/agency`
unless you chose otherwise. `session_id` is that agent's own roster entry, in
full and lowercase. Pass nothing else: a resumed session already remembers its
name, and any extra flag starts a copy under a new id rather than resuming the
session itself.

## Keeping an agency current

```
/agency:audit
```

An agency is rendered from the templates once, when it is opened and again at
each hire, and never tracks them afterwards. So a plugin update reaches new
agencies only, and an office that has been open a while is quietly running on
what the plugin said the day it opened.

The audit compares your agency against the templates the installed plugin
carries now — the shared conventions, each agent's profile frame, the first
seat's job description, the shape of the roster — and says what each difference
means for the agents living under it. It reads the plugin's own git history to
work out whether the template moved or you edited your copy, and says so
plainly when it cannot tell.

Nothing is written until you have seen it and said yes, and whatever it
replaces is backed up first. Your own edits are yours: a file it cannot trace
back to a template it reports and leaves alone.

## Naming

Agent names accept anything a directory can carry, in any language — `行政 助理`
is a valid name.

One caveat if you use non-ASCII names. Claude Code derives a per-project
storage directory from the agent's path, replacing every non-alphanumeric
character with `-`, so two agents whose names are the same length and entirely
non-ASCII resolve to the same directory. Their conversations stay separate —
each session records its own working directory — but they share one auto-memory
store. Give such agents names of different lengths, or include one ASCII
character, to keep them apart.
