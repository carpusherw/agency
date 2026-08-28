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

## Repo vs agency

This repo is the **mechanism** — a Claude Code plugin holding skills, templates,
and scripts. It is shareable.

Your **agency** is instance state and lives elsewhere (default `~/agency`):
the roster, the agents, their memory. It is never checked in here, and what you
do with it afterwards — version it, back it up, leave it alone — is yours to
decide.

## Install

```
claude plugin marketplace add carpusherw/agency
claude plugin install agency@agency
```

Then, in Claude Code:

```
/agency:open
```

It names the agency and picks its **logoji** — one emoji that marks every
session the agency runs — asks where it lives, offers a
name for the first agent, and works with you on that agent's job description
until you accept it. Then it creates:

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

### Naming

Agent names accept anything a directory can carry, in any language — `行政 助理`
is a valid name.

One caveat if you use non-ASCII names. Claude Code derives a per-project
storage directory from the agent's path, replacing every non-alphanumeric
character with `-`, so two agents whose names are the same length and entirely
non-ASCII resolve to the same directory. Their conversations stay separate —
each session records its own working directory — but they share one auto-memory
store. Give such agents names of different lengths, or include one ASCII
character, to keep them apart.

## Running an agent

Agents run as background sessions, so the office is `claude agents`. Opening an
agency starts its first agent for you and records the session id it was given.

To work with an agent directly:

```
claude attach <id>        # opens it in this terminal; Ctrl+Z drops back out
```

or pick it out of `claude agents`. The session keeps running either way.

If an agent has been stopped, start it again from its own folder:

```
cd ~/agency/agents/<agent.name>
claude --bg --resume <session_id> --name "<agency.logoji> [<agency.name>]: <agent.name>"
```

`session_id` comes from that agent's roster entry; the name is composed from the
roster's `agency.logoji` and `agency.name` plus the agent's own — `🏢 [MIB]: Agent
O` — so every session in `claude agents` reads as part of the same office.

The `cd` is what gives the session the agent's profile, the agency conventions
it inherits, and its permission scope. Pass `--name` every launch — it is not
remembered, and without it the agents view retitles the session after its
contents.

Agents reach each other with `SendMessage`, by that composed name.

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

## Layout

```
.claude-plugin/marketplace.json
plugins/agency/
  .claude-plugin/plugin.json
  skills/open/SKILL.md         the interview
  skills/hire/SKILL.md         the interview for a second seat
  scripts/agency-init.sh       the deterministic scaffold
  scripts/agency-hire.sh       the same, for hiring into an open agency
  templates/agency/            shared CLAUDE.md, roster.yaml
  templates/agent/             profile, STATE.md, settings.json
  templates/jd/ea.md           default executive-assistant job description
```
