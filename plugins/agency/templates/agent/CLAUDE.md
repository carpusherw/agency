# {{AGENT_NAME}} — {{TITLE}}

{{JD}}

## Your files

- `STATE.md` — what you are currently holding. Read it at the start of every
  session, before anything else. Update it as you work, not at the end.
- `journal/<YYYY-MM>.md` — append-only notes for the current month. Date every
  entry. Put things here that a future session would waste time rediscovering.

## Your identity

- Folder: `{{AGENT_FOLDER}}`
- Session id: `{{SESSION_ID}}`

Resume this agent:

```
claude --resume {{SESSION_ID}}
```

Start it for the first time:

```
claude --session-id {{SESSION_ID}} --name {{DISPLAY_NAME}}
```
