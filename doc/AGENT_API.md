# MacTwix Agent Debug API

Localhost-only live observability for Cursor while MacTwix is running.

## Endpoints

Base: `http://127.0.0.1:18765`

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Liveness |
| GET | `/status` | Full JSON snapshot (toggles, AWDL, TCP, triggers, tray) |
| GET | `/logs?limit=100` | Recent in-memory log lines |
| GET | `/paths` | Absolute paths to status/log files |

## Files (also updated live)

- `~/Library/Logs/MacTwix/agent-status.json` — last snapshot (~every 2s)
- `~/Library/Logs/MacTwix/agent.log` — append-only events

## Examples

```bash
curl -s http://127.0.0.1:18765/status | python3 -m json.tool
curl -s 'http://127.0.0.1:18765/logs?limit=50'
tail -f ~/Library/Logs/MacTwix/agent.log
```

Binds only to `127.0.0.1`. Starts automatically with the menubar app.
