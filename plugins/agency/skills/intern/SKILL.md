---
name: intern
description: Start an intern — a background session that does one job for an agent in an agency, without a seat, a profile or state of its own. It reports to the agent that started it and can work with anyone else in the office. Use when an agent wants to hand a single job to a session of its own, or says "/agency:intern". Not for adding a long-lived agent, which is agency:hire.
---

# intern

Starts a session that works for the agency without joining it.

An intern is not in the roster. It has no folder, no profile, no `STATE.md` and
no journal. What it does have is the agency's `CLAUDE.md`, loaded wherever it
works, so it knows the office: who is in it, how to reach them, and that it
reports to the agent that started it. Everything about the job itself comes from
the brief.

## Gate

There must be an agency: `<root>/roster.yaml`. The agent starting the intern
must be in that roster, because the intern reports to someone in the office.

## The brief

The brief is the whole of the intern's job. Nothing else tells it what to do, so
write it as you would for a capable colleague who has seen none of this
conversation:

- what the job is, and where its materials are
- what is already known or decided, so it is not rediscovered
- what finished looks like, and what to do then

The agency's conventions reach the intern already. Do not restate them in the
brief.

## Where it works

Any directory: a repository, a scratch folder, a folder inside the agency. The
intern starts there and loads the `CLAUDE.md` files that directory would give
any session, plus the agency's.

## Start it

Write the brief to a file, then run:

```
${CLAUDE_PLUGIN_ROOT}/scripts/agency-intern.sh \
  --root <root> --agent <your name> --label <a few words> \
  --dir <where it works> --brief-file <path> \
  [--permission-mode <mode>]
```

The session is named `<logoji> [<agency name>]: <agent>'s intern - <label>`, so
it reads as the office's in `claude agents`. Without `--permission-mode` it runs
under whatever mode applies in that directory; a background session in
`default` mode blocks on its first tool call.

## Afterwards

Put the intern's session id in your `STATE.md` while it works. When its job is
done, stop it with `claude stop <short id>`, then `claude rm <short id>` to
remove its background record. The script prints both.
