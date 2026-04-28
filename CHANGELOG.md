# CHANGELOG — openclaw

## 2026-04-28

- Skeleton-compliance retrofit per skeleton-compliance.md (dev-meta `0f45071`, post-Q11). CLAUDE.md reshaped to post-Q11 head-shape with `Status: BROKEN` line (Q14 deviation per HYGIENE item 6 — Anthropic credits exhausted, fails rely-on-it-today). HANDOVER.md authored in spec six-section shape, UNVERIFIED marker pending operator review.
- Existing root HANDOVER.md content (operator-curated runbook with Health check, Safe restart, boundary table, Open questions) preserved at `docs/PICKUP.md` via `git mv` to retain history. `docs/OPENCLAW_HANDOVER.md` retained at current path per A1 disposition. CHANGELOG.md created. `.gitignore` unchanged (already spec-canonical 8/8).

## 2026-04-18

- CLAUDE.md reorganization: added Commit hygiene, Live issues, Incidents, Session end checklist sections (`fe48599`). Mailmap added for author identity canonicalization (`7a3a75d`).
- Initial onboarding session: open questions captured (uid 1001 mystery user, WhatsApp stale-socket cycle, `gateway.auth.token` sanitization). Initial commit (`e69dca4`) staged the repo: versioned config, agents, workspace context. Live runtime state and credentials remain host-only.

<!-- Newest entries on top. Operator-curated narrative; not auto-generated from git log. One paragraph per shipped change or notable event. -->
