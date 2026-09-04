---
name: audit
description: Audit a live agency against the installed agency plugin's templates — what has drifted since the agency was rendered, what each difference means, and the patches the user agrees to. Use when the user asks to audit or check an agency, to see what it is missing, or to bring one up to date with the plugin, or says "/agency:audit". Not for opening an agency, which is agency:open, or hiring into one, which is agency:hire.
---

# audit

An agency is rendered from the templates once — at `open`, and again at each
`hire` — and never tracks them afterwards. This finds what has drifted since,
says what each difference means for the agents living under it, and writes the
ones the user agrees to.

## Gate

There must be an agency: a `roster.yaml` at the root. `survey` walks up from the
working directory to find one and says so when there is none — *no roster.yaml
at or above `<dir>`. Name the agency with `--root`, or open one with the
`agency:open` skill.* Say both halves. A session whose working directory is
outside the agency still has an agency to audit; it only has to be named.

## The facts

Everything deterministic comes from one command:

```
${CLAUDE_PLUGIN_ROOT}/scripts/agency-audit.sh survey [--root <root>]
```

It reports the roster parsed into seats and folders, which of each seat's files
exist, when an audit last wrote a patch here, the plugin version every
comparison below is made against, and whether the marketplace carries a newer
plugin.

**Name that version in the report, every time.** If the marketplace carries a
newer one, install it and start again.

## What is compared

Read both sides and diff them.

| Live | Upstream |
| ---- | -------- |
| `<root>/CLAUDE.md` | `templates/agency/CLAUDE.md` — a copy, nothing substituted |
| the frame of `agents/<name>/CLAUDE.md`: everything but its job description | `templates/agent/CLAUDE.md` |
| the first seat's job description | `templates/jd/ea.md` |
| each seat's `.claude/settings.json` | `templates/agent/settings.json` |
| `roster.yaml` | `templates/agency/roster.yaml`, its keys only |

**A later seat's job description has no upstream.** It was written in that
seat's hire interview and nothing owns it, so the audit says nothing about it.

**The roster is compared on its keys, never its values.** The names, folders and
session ids in it are the office itself. A key the template carries and the
roster does not is a renamed or dropped field, and it is the one thing in the
roster worth reporting.

`STATE.md` and `journal/` are checked for existence and no further. Their
contents are the seat's own.

## Which side moved

A live file differing from the current template has two possible causes that
want opposite answers: the plugin moved forward, or the user edited their copy.
Telling them apart needs the base — what the template said when this agency was
rendered — which is in the plugin's own git history:

```
${CLAUDE_PLUGIN_ROOT}/scripts/agency-audit.sh collapse \
  --agent <name> --what frame|jd|settings [--root <root>]

${CLAUDE_PLUGIN_ROOT}/scripts/agency-audit.sh base \
  --file <the collapsed content> --template <path under the plugin>
```

`collapse` writes the live content with this seat's rendered values put back as
placeholders, which is the shape `base` has to be handed. `<root>/CLAUDE.md` is
not substituted into at all, so it goes to `base` as it stands. When `collapse`
exits non-zero it has said what it could not reverse — that is a base which
cannot be determined, so say so and recommend nothing rather than reading it as
a difference.

Each outcome is a different thing to say:

- **current** — no difference.
- **matched** — the live file is an earlier revision of the template, verbatim,
  so the difference is entirely the plugin's doing. It reports which revision,
  and the plugin version that revision carried. Propose the patch.
- **edited** — the whole history was searched and no revision holds this
  content, so this copy was edited by hand. Report the difference and say that
  is what it looks like.

  Where the edit is a local one sitting on an earlier revision — a seat someone
  widened with an `allow` list, say — the merge is exact and worth offering.
  Verify it in both directions first: strip the edit and `base` returns
  `matched`; strip the same edit from the merge and it returns `current`. Show
  the merge as a diff, and offer it beside leaving the file alone — never as the
  recommendation, which is persuasion where the point is consent. Otherwise, and
  for anything that does not verify both ways, leave the upstream text out of
  the proposal.

  Then show what the template itself did, separately. A file that was edited
  once differs for two reasons at once, and one diff cannot separate them —
  so every later improvement to that template arrives buried inside the
  user's own changes and reads as noise. `survey`'s `history` line names the
  clone and the plugin's path inside it; `git -C <clone> log -p -- <that
  path>` is the template's own record. Show it beside the difference: this is
  what the plugin changed, this is where your copy goes its own way.
- **truncated** — nothing matched, and deepening the shallow clone did not
  reach far enough to settle it. Say plainly that the base cannot be
  determined, show the difference, recommend nothing.
- **no-history** — there is no clone to read; the same answer as truncated.

**A removal that lands back on an earlier revision comes back `matched`.**
Delete the thing an audit added and the file is once again, exactly, what the
template said before it was added — so the next audit finds a revision holding
that content, reads the difference as the plugin's doing, and proposes the same
patch a second time. Nothing distinguishes it from a copy that was never
patched, because nothing here records what was applied. This is true of every
file compared, not only settings. Nothing is written without consent, so the
cost is being asked again rather than being overruled; when a patch only adds
something back, say that it may have been removed deliberately, instead of
presenting it as news.

**Do not ask the user which side moved.**

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

Show every change and get the user's consent for it before it is written. The
diffs go in the reply itself, not in tool output — a terminal collapses tool
output, and a diff the user never saw is not a diff they agreed to. There is no
change small or safe enough to skip this: any of these files may have been
edited by hand for a reason no template can know.

Write the new content to a file, then:

```
${CLAUDE_PLUGIN_ROOT}/scripts/agency-audit.sh apply --file <live> --from <new>
```

It backs the file up before writing and reads it back afterwards. Apply only
what was shown, with this seat's own values rendered back in — a patch to a
profile is the current frame carrying that agent's job description, a patch to a
settings file carries that seat's permission mode, and neither ever carries the
template's placeholder.

Say where each backup landed, and which findings were left alone.
