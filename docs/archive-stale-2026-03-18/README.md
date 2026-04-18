# archive-stale-2026-03-18/

**STATUS: superseded. For reference only. Do not treat as truth.**

The two files here came from the project's original `start/` folder that
existed when this `dev/projects/openclaw/` directory was first created.
They describe an earlier OpenClaw architecture (agents: coding / mind /
ops_manager / trading; unit: `openclaw.service`). That architecture was
replaced on 2026-04-14 in favour of `main → soc`, `ha-agent → ha`, `trading
(parked)`, and the runtime was moved to `openclaw-gateway.service` — see
`../OPENCLAW_HANDOVER.md` for the canonical current description.

Kept here so the transition is visible and nothing is lost. Delete when
you're confident no downstream doc still points here.

## Files

- `finalarchitecture.md` — terse agent/service summary, 2026-03-18.
  Agents list is stale; systemd unit name is stale.
- `handover_information.txt` — richer operator handover, same date.
  Same staleness; the "ops_manager / trading / mind / coding" model it
  describes no longer matches the live bot.
