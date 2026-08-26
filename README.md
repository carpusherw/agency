# agency

An office of long-lived agents, built on stock Claude Code.

An **agency** is a directory of agents. Each agent has its own folder, its own
profile (`CLAUDE.md`), its own permission scope (`.claude/settings.json`), a
state file it maintains, and a fixed session id so it can be resumed instead of
restarted.

The design premise: **persistent identity, disposable sessions.** A session can
die at any time — crash, restart, compaction. So continuity lives in files, and
a session is just a worker that picks the folder up and puts it back.

## Repo vs agency

This repo is the **mechanism** — a Claude Code plugin holding skills, templates,
and scripts. It is shareable.

Your **agency** is instance state and lives elsewhere (default `~/agency`):
the roster, the agents, their memory. It is never checked in here. `agency:open`
makes it a local git repo with no remote, so you get history without exposure.

## Install

```
claude plugin marketplace add carpusherw/agency
claude plugin install agency@agency
```

Then, in Claude Code:

```
/agency:open
```

It asks three things — where the agency lives, what the first agent is called
(a random name is suggested), and whether to keep the default job description
or change it — and creates:

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

## Running an agent

```
cd ~/agency/agents/<name>
claude --session-id <id> --name agency:<name>   # first time
claude --resume <id>                            # every time after
```

Agents address each other by display name via `SendMessage`; `claude agents
--json` reports who is actually live. The roster stores the permanent session
id, so liveness is derived rather than tracked.

## Layout

```
.claude-plugin/marketplace.json
plugins/agency/
  .claude-plugin/plugin.json
  skills/open/SKILL.md         the interview
  scripts/agency-init.sh       the deterministic scaffold
  scripts/random-name.sh
  templates/agency/            shared CLAUDE.md, roster.yaml
  templates/agent/             profile, STATE.md, settings.json
  templates/jd/ea.md           default executive-assistant job description
```

## Scope

v1 opens an agency and hires one agent. Hiring more agents, archiving them, and
migrating an older layout are deliberately not here yet — they get added when
there is a real use case, not an imagined one.
