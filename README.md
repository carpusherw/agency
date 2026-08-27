# agency

An office of long-lived agents. It adds no infrastructure of its own — an
agency is a directory, and the agents are ordinary Claude Code sessions.

An **agency** is a directory of agents. Each agent has its own folder, its own
profile (`CLAUDE.md`), its own permission scope (`.claude/settings.json`), a
state file it maintains, its own project memory and session history — Claude
Code keys those to the folder — and a fixed session id so it can be resumed
instead of restarted.

The design premise: **persistent identity, disposable sessions.** A session can
die at any time — crash, restart, compaction. So continuity lives in files, and
a session is just a worker that picks the folder up and puts it back.

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

It asks where the agency lives, offers a name for the first agent, and works
with you on that agent's job description until you accept it. Then it creates:

```
~/agency/
  CLAUDE.md                    inherited by every agent
  roster.yaml                  who exists, and their fixed session ids
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
cd ~/agency/agents/<name>
claude --bg --resume <session_id> --name "agency:<name>"
```

The `cd` is what gives the session the agent's profile, the agency conventions
it inherits, and its permission scope. Pass `--name` every launch — it is not
remembered, and without it the agents view retitles the session after its
contents.

Agents reach each other with `SendMessage`, by the display name in the roster.

## Layout

```
.claude-plugin/marketplace.json
plugins/agency/
  .claude-plugin/plugin.json
  skills/open/SKILL.md         the interview
  scripts/agency-init.sh       the deterministic scaffold
  templates/agency/            shared CLAUDE.md, roster.yaml
  templates/agent/             profile, STATE.md, settings.json
  templates/jd/ea.md           default executive-assistant job description
```
