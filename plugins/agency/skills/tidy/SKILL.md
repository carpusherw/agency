---
name: tidy
description: Trim an agent's own STATE.md back to what is still open — archive the whole file first, cut closed threads and the history of open ones, and rewrite the file around where each open thread stands. Use when a session start reports that STATE.md is over its budget, when an agent notices its STATE.md has turned into a history of what happened, or when the user asks a seat to trim, tidy or clean up its state, or says "/agency:tidy". Only ever for the running agent's own file. Not for comparing an agency against the plugin's templates, which is agency:audit.
---

# tidy

Brings a seat's `STATE.md` back to what is open.

Every session of a seat reads that file first, so its size is paid at every
start and again after every compaction, and whatever is still open has to be
found among everything that is not. It grows for an honest reason: writing down
what just happened is the safe thing to do in the middle of a task, and nothing
marks the moment a thread stops mattering. This is that moment, made deliberate.

Nothing is lost by it. The whole file is archived before a line changes, so the
question is never what deserves to exist. It is what the next session has to
read before it can act.

## Gate

**Your own file, and no one else's.** You are the agent the roster gives this
folder to. An intern, or an agent looking at a colleague's `STATE.md`, stops
here: what is open in a file is something only its owner knows, so tell that
seat what you saw and leave the file as it is.

**Between pieces of work, not in the middle of one.** If the notice arrived
while you were part-way through something, finish that step and write down
where it stands first. Half of a live thread is in the file and the other half
is in your head, and trimming now is how the second half gets dropped.

## Measure

```
${CLAUDE_PLUGIN_ROOT}/scripts/agency-state.sh measure
```

It prints the file's size against its budget, then every section with its size
in bytes, largest first. Keep this output: the check at the end goes back down
the same list.

Go by the byte counts, not by how long the file looks. A handful of sections
usually hold most of the weight, and one line can run to tens of thousands of
characters, so a section that looks like a paragraph may be the largest thing
in the file.

## Archive first

```
${CLAUDE_PLUGIN_ROOT}/scripts/agency-state.sh archive
```

It copies `STATE.md` byte for byte to `journal/state-archive-<date>.md`, never
over an earlier archive, and prints where the copy landed. Change nothing until
it has printed a path.

The archive is what makes every decision below cheap. A wrong call costs a
search of one file instead of a lost fact, so there is no reason to keep
something in `STATE.md` just in case. The archive itself is never edited and
never removed.

## Sort

Take the sections one at a time, largest first, and ask of each: **if this
session ended now, what would the next one need from this in order to act?**

- **Open** — someone still owes something: you, the person you work for, a
  colleague, a job running in the background. It stays, cut down to where it
  stands now, what comes next and who owes it, the decisions that still bind,
  and the pointers needed to pick it up: paths, links, ticket and session ids.
  It has to be enough to act on without opening anything else. The account of
  how it got here is cut and written nowhere new; the archive already holds it.
- **Closed** — nothing more is owed. It leaves `STATE.md`. Whatever a future
  session would waste time rediscovering becomes a journal entry: a decision
  and its reason, a trap, where something lives. The rest stays in the archive
  and nowhere else.
- **Cannot tell** — keep it, under a heading that says its status is not
  recorded and has to be verified before anyone acts on it. A thread wrongly
  closed disappears without a sound; a thread wrongly kept costs a few lines.
  Collect these for the report rather than guessing.

A heading that is a date is history. "11-12: PR merged" records something that
happened, not something that is open. If its thread is still open, what belongs
in `STATE.md` is where the thread stands today, under the thread's own name,
and the dated account is cut with the rest of its history.

Some things stay however old they are:

- an instruction from the person you work for that still binds, in their own
  words
- anything they parked, together with the fact that they parked it, so it is
  not raised again
- anything you started that is still running or scheduled — an intern's session
  id, a background job, a watch — until you have stopped it
- anything you promised and have not delivered

## Write

Journal first. The journal gets entries for closed threads only, and only what
is worth not rediscovering; an open thread's history is not copied there.
Append them to `journal/<YYYY-MM>.md` for the current month, dated today, each
saying it was moved out of `STATE.md` and keeping the dates of what it
describes. Add one line naming the archive file, so a later session knows there
is a full copy to search for everything that was cut.

Then rewrite `STATE.md` around the open threads.

## Check

Run `measure` again. Then go back down the first list of headings and place
every one: still in `STATE.md`, a journal entry, or the archive only. A heading
you cannot place is one you dropped by accident.

**The budget is a prompt to look, not a quota.** If everything left is open and
the file is still over, leave it over and say so. Cutting an open thread to fit
a number is the one way this does harm.

## Report

Tell the person you work for, in your reply rather than in tool output: the
size before and after, where the archive is, what moved to the journal, and
each thread you could not classify, as a question they can answer.
