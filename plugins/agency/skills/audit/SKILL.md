---
name: audit
description: Audit a live agency against the installed agency plugin's templates — what has drifted since the agency was rendered, what each difference means, and the patches the user agrees to. Use when the user asks to audit or check an agency, to see what it is missing, or to bring one up to date with the plugin, or says "/agency:audit". Not for opening an agency, which is agency:open, or hiring into one, which is agency:hire.
---

# audit

An agency is rendered from the templates once — at `open`, and again at each
`hire` — and never tracks them afterwards. Every later improvement to a
template reaches new agencies only: a rule added to the shared conventions, a
section added to a profile. An office open for a while is running on what the
plugin said the day it opened, and nothing in it says so.

This finds that drift, says what each difference means for the agents living
under it, and writes the ones the user agrees to.

## Gate

There must be an agency: `<root>/roster.yaml`. If there is none, say so and
point at the `agency:open` skill.

## The facts

Everything deterministic comes from one command:

```
${CLAUDE_PLUGIN_ROOT}/scripts/agency-audit.sh survey [--root <root>]
```

It walks up from the working directory to find the root, so an agent auditing
its own agency passes nothing. It reports the roster parsed into seats and
folders, which of each seat's files exist, the plugin version every comparison
below is made against, and whether the marketplace carries a newer plugin.

**Name that version in the report, every time.** If the marketplace carries a
newer one, install it and start again. A stale copy reports an agency current
against templates that have themselves moved on — the failure this skill exists
to catch, wearing a clean bill of health.

## What is compared

Read both sides and diff them.

| Live | Upstream |
| ---- | -------- |
| `<root>/CLAUDE.md` | `templates/agency/CLAUDE.md` — a copy, nothing substituted |
| the frame of `agents/<name>/CLAUDE.md`: its heading, `## Your files`, `## Your identity` | `templates/agent/CLAUDE.md` |
| the first seat's job description | `templates/jd/ea.md` |
| `roster.yaml` | `templates/agency/roster.yaml`, its keys only |

A profile is `templates/agent/CLAUDE.md` with a job description substituted into
it, so its frame and its job description come from different places and are
compared separately.

**A later seat's job description has no upstream.** It was written in that
seat's hire interview and nothing owns it, so the audit says nothing about it.

**The roster is compared on its keys, never its values.** The names, folders
and session ids in it are the office itself. A key the template carries and the
roster does not is what a renamed or dropped field looks like from here, and it
is the one thing in the roster worth reporting.

`STATE.md`, `journal/` and `.claude/settings.json` are checked for existence and
no further. Their contents are the seat's own, and the settings file in
particular is the scope the user is meant to edit.

## Which side moved

A live file differing from the current template has two possible causes that
want opposite answers: the plugin moved forward, or the user edited their copy.
Telling them apart needs the base — what the template said when this agency was
rendered — which is in the plugin's own git history:

```
${CLAUDE_PLUGIN_ROOT}/scripts/agency-audit.sh base \
  --file <path to the live content> --template <path under the plugin>
```

Matching is byte-exact, so hand it content in the shape the template is in.
`<root>/CLAUDE.md` already is. For a profile's frame, read
`templates/agent/CLAUDE.md`, see what it substitutes, and write the live profile
out with each of those values put back as its placeholder — the job description
collapsed to `{{JD}}`, the name, title and folder to theirs. For the first
seat's job description, write out the region the profile carries in its place.

That reversal is also the test of whether the base is knowable at all. A profile
someone has restructured — sections reordered, the job description broken up and
run together with the frame — has no region to collapse, so there is nothing
honest to hand over. Say the base is undetermined and recommend nothing; a
guessed reading of it is not evidence of anything.

A profile handed over as it stands, with its values still rendered, matches no
revision and comes back **edited** — a wrong answer that looks like a real one.
Collapse it first, or say the base is undetermined.

Each outcome is a different thing to say:

- **current** — no difference.
- **matched** — the live file is an earlier revision of the template, verbatim,
  so the difference is entirely the plugin's doing. It reports which revision,
  and the plugin version that revision carried. Propose the patch.
- **edited** — the whole history was searched and no revision holds this
  content, so this copy was edited by hand. Report the difference and say that
  is what it looks like. Leave the upstream text out of the proposal.

  Then show what the template itself did, separately. A file that was edited
  once differs for two reasons at once, and one diff cannot separate them —
  so every later improvement to that template arrives buried inside the
  user's own changes and reads as noise. `survey`'s `history` line names the
  clone and the plugin's path inside it; `git -C <clone> log -p -- <that
  path>` is the template's own record. Show it beside the difference: this is
  what the plugin changed, this is where your copy goes its own way. Still
  propose nothing.
- **truncated** — nothing matched, and deepening the shallow clone did not
  reach far enough to settle it. Say plainly that the base cannot be
  determined, show the difference, recommend nothing.
- **no-history** — there is no clone to read; the same answer as truncated.

**Do not ask the user which side moved.** They will not remember, and they do
not need to: every change is shown before it is written, so what is in front of
them is what they want now, not what happened.

## Report

Per difference: what it is, where it came from, and **what it means for this
office**. A section missing from the shared conventions means none of these
agents has been told the thing it says — name the thing, and quote enough of it
to make that concrete.

Then the whole audit in one pass: the version compared against, what drifted,
what is proposed, and what is undetermined and why.

## Apply

Finish in the same run. A report the user has to act on separately is how drift
survives a whole audit.

Show every change and get the user's consent for it before it is written. There
is no change small or safe enough to skip that: any of these files may have been
edited by hand for a reason no template can know.

Write the new content to a file, then:

```
${CLAUDE_PLUGIN_ROOT}/scripts/agency-audit.sh apply --file <live> --from <new>
```

It backs the file up before writing and reads it back afterwards. Apply only
what was shown — a patch to a profile is the current frame carrying that agent's
own job description, never the template's placeholder.

Say where each backup landed, and which findings were left alone.
