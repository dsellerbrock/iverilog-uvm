# Session logs — historical evidence policy

Everything under `docs/conformance/session_logs/` is **Level 4 historical
evidence** (see `AGENTS.md` → Documentation authority). Each log is
revision-scoped: it records what was true, tested, and observed at the time
it was written, pinned to the commits/PRs it names.

**NEXT, OPEN, TODO, "the next increment," and similar language inside a
session log does not authorize current implementation work.** A log saying
a topic is "next" only reflects what that session's author intended or
guessed at the time. Current implementation authorization comes only from
`.ai/ACTIVE_WORK.yaml` naming a blocker from `docs/conformance/BLOCKERS.md`.

Do not treat a session log's pass/fail counts, census results, or
conformance claims as current unless independently re-verified against the
present HEAD — a later commit may have changed the behavior being described,
and several historical logs in this repository are already known to be
stale relative to later merges.

Do not rewrite historical logs wholesale to make them "current." If a log's
claim needs correcting for the historical record, append a clearly
revision-scoped note (with a date and the commit that changes the picture)
rather than editing the original entry's text.
