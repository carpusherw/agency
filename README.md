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

```
cd ~/agency/agents/<name>
claude --continue                  # resumes that agent
```

`--continue` picks up the most recent session in the current directory, and
each agent has its own directory — so you never type a session id. The
`session_id` in the roster is the durable address for naming one exact session
(`claude --resume <id>`) and for finding the agent among live sessions.

Agents address each other by display name via `SendMessage`; `claude agents
--json` reports who is actually live.

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
