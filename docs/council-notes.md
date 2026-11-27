# Engineering Council notes

Agent Teams is an experimental Claude Code feature. The Lead Engineer logs rough edges here as they
happen, newest first: date, what went wrong, and the workaround. Keep each entry to a few lines.

<!-- Example:
## 2026-12-01: teammate couldn't see the task board
What happened: ...
Workaround: ...
-->

## 2026-11-27: council run from a cloud session (PR 11)
What happened: no Xcode or Swift compiler in the cloud container, and Agent Teams aren't available
there, so teammates couldn't build, run tests or message each other.
Workaround: ran the agent files as plain subagents from the Lead (security-officer + the-questioner
reviewed the plan first, junior-dev built the place page, qa-engineer wrote unit tests, bloat-engineer
reviewed the diff). GitHub CI was the only compiler and test runner; dark/light rendering still needs
a phone check by Varun.
