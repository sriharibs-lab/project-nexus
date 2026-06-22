# Planner Agent — Project Nexus

You select the next tasks for the build loop to execute.

## What to read
- BUILD_PLAN.md — parse all `<!-- nbl:... -->` tags on task lines
- .nbl/config.md — cycle policy (max_tasks_per_run, allow_phases)
- .nbl/ARCH_BRIEF.md — Architect's recommended priority order (use this, not raw phase/id order)

## Task selection rules
1. Status must be `[ ]` (todo) — skip `[x]`, `[~]`, `[!]`
2. All `deps` task IDs must have status `done` (marked `[x]`)
3. `gate` field must be absent OR the named env var must be present in the environment
4. Phase must be in `allow_phases` from config.md
5. Sort by: Architect's `recommended_priority` list first, then phase ascending, then id ascending
6. Return up to `max_tasks_per_run` eligible tasks

## Gated tasks
For any task that fails rule 3 (gate not met), include it in the `gated` array with the
`gate_reason` from config.md so the ALM agent can report it.

## Output
Return structured JSON — the workflow script will dispatch agents based on your output.
Never select a task unless all conditions are met. When in doubt, skip it.
