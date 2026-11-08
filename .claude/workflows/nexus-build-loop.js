export const meta = {
  name: 'nexus-build-loop',
  description: 'Autonomous build loop for Nexus: Architect → Plan → Build → Test → Review → Commit',
  phases: [
    { title: 'Architect', detail: 'Strategic CTO reviews codebase + SPEC, writes guidance brief' },
    { title: 'Plan', detail: 'Planner selects eligible tasks from BUILD_PLAN.md' },
    { title: 'Build', detail: 'SWE implements task in isolated git worktree' },
    { title: 'Test', detail: 'Test agent writes + runs tests for new code' },
    { title: 'Review', detail: 'Review agent checks quality, spec alignment, arch risks' },
    { title: 'Commit', detail: 'ALM merges, writes CHECKPOINT.md, sends Gmail report' },
  ],
}

const ROOT = process.cwd()  // run from the repo root

// ── Shared decision schema ─────────────────────────────────────────────────
// decisions[] appears on Architect, SWE, and Review outputs.
// minor = logged for PM awareness, no action needed
// major = PM should review before next cycle continues

const DECISION_ITEM = {
  type: 'object',
  required: ['choice', 'alternatives', 'rationale', 'impact'],
  properties: {
    choice: { type: 'string' },
    alternatives: { type: 'array', items: { type: 'string' } },
    rationale: { type: 'string' },
    impact: { type: 'string', enum: ['minor', 'major'] },
  }
}

// ── Schemas ────────────────────────────────────────────────────────────────

const ARCH_SCHEMA = {
  type: 'object',
  required: ['health', 'strategic_assessment', 'recommended_priority', 'risks', 'decisions', 'brief_markdown'],
  properties: {
    health: { type: 'string', enum: ['GREEN', 'YELLOW', 'RED'] },
    strategic_assessment: { type: 'string' },
    recommended_priority: { type: 'array', items: { type: 'string' } },
    risks: { type: 'array', items: {
      type: 'object',
      required: ['severity', 'description', 'file'],
      properties: {
        severity: { type: 'string', enum: ['blocking', 'warning', 'note'] },
        description: { type: 'string' },
        file: { type: 'string' },
      }
    }},
    decisions: { type: 'array', items: DECISION_ITEM },
    brief_markdown: { type: 'string' },
  }
}

const PLAN_SCHEMA = {
  type: 'object',
  required: ['eligible', 'gated'],
  properties: {
    eligible: { type: 'array', items: {
      type: 'object',
      required: ['id', 'phase', 'title', 'agent', 'estimated_h'],
      properties: {
        id: { type: 'string' },
        phase: { type: 'string' },
        title: { type: 'string' },
        agent: { type: 'string' },
        estimated_h: { type: 'number' },
        deps: { type: 'array', items: { type: 'string' } },
      }
    }},
    gated: { type: 'array', items: {
      type: 'object',
      required: ['id', 'title', 'gate_reason'],
      properties: {
        id: { type: 'string' },
        title: { type: 'string' },
        gate_reason: { type: 'string' },
      }
    }},
  }
}

const SWE_SCHEMA = {
  type: 'object',
  required: ['task_id', 'status', 'files_created', 'files_modified', 'summary', 'test_hints', 'blockers', 'decisions'],
  properties: {
    task_id: { type: 'string' },
    status: { type: 'string', enum: ['completed', 'failed', 'blocked'] },
    files_created: { type: 'array', items: { type: 'string' } },
    files_modified: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' },
    test_hints: { type: 'array', items: { type: 'string' } },
    blockers: { type: 'array', items: { type: 'string' } },
    decisions: { type: 'array', items: DECISION_ITEM },
    branch: { type: 'string' },
  }
}

const TEST_SCHEMA = {
  type: 'object',
  required: ['task_id', 'tests_written', 'tests_run', 'tests_passed', 'tests_failed', 'verdict', 'recommendation'],
  properties: {
    task_id: { type: 'string' },
    tests_written: { type: 'array', items: { type: 'string' } },
    tests_run: { type: 'number' },
    tests_passed: { type: 'number' },
    tests_failed: { type: 'number' },
    failure_details: { type: 'array', items: {
      type: 'object',
      properties: { test: { type: 'string' }, reason: { type: 'string' } }
    }},
    verdict: { type: 'string', enum: ['pass', 'fail', 'partial'] },
    recommendation: { type: 'string', enum: ['merge', 'fix_required', 'human_review'] },
  }
}

const REVIEW_SCHEMA = {
  type: 'object',
  required: ['task_id', 'verdict', 'issues', 'spec_alignment', 'summary', 'decisions'],
  properties: {
    task_id: { type: 'string' },
    verdict: { type: 'string', enum: ['approve', 'approve_with_notes', 'request_changes', 'escalate_human'] },
    issues: { type: 'array', items: {
      type: 'object',
      required: ['severity', 'file', 'message'],
      properties: {
        severity: { type: 'string', enum: ['error', 'warning', 'note'] },
        file: { type: 'string' },
        line: { type: 'number' },
        message: { type: 'string' },
      }
    }},
    spec_alignment: { type: 'string', enum: ['aligned', 'diverges'] },
    divergence_notes: { type: 'string' },
    summary: { type: 'string' },
    decisions: { type: 'array', items: DECISION_ITEM },
    auto_fixable: { type: 'boolean' },
  }
}

const ALM_SCHEMA = {
  type: 'object',
  required: ['cycle_id', 'status', 'tasks_completed', 'tasks_blocked', 'tasks_skipped', 'checkpoint_written'],
  properties: {
    cycle_id: { type: 'string' },
    status: { type: 'string', enum: ['clean', 'review_recommended', 'action_required'] },
    tasks_completed: { type: 'array', items: { type: 'string' } },
    tasks_blocked: { type: 'array', items: { type: 'string' } },
    tasks_skipped: { type: 'array', items: { type: 'string' } },
    merge_sha: { type: 'string' },
    checkpoint_written: { type: 'boolean' },
  }
}

// ── Phase: Architect ───────────────────────────────────────────────────────

phase('Architect')
log('🏛  Architect reviewing codebase and writing direction brief...')

const arch = await agent(
  `Read the prompt at ${ROOT}/.nbl/prompts/architect.md — it defines your role and exactly which files to read.

IMPORTANT: Read ONLY the files listed in architect.md. Do NOT read api/ or Swift source files — they will overflow your context. Your role is strategic direction, not code review.

After your review, write brief_markdown to ${ROOT}/.nbl/ARCH_BRIEF.md.

Include a decisions[] for every judgment call: what you recommended, alternatives considered, why, and impact (minor/major). Plain English for a PM.`,
  { schema: ARCH_SCHEMA }
)

log(`🏛  Architect: ${arch.health} — ${arch.strategic_assessment.slice(0, 120)}`)

if (arch.decisions && arch.decisions.length > 0) {
  for (const d of arch.decisions) {
    if (d.impact === 'major') {
      log(`   🚨 MAJOR CALL: "${d.choice}"`)
      log(`      Why: ${d.rationale}`)
      log(`      Options considered: ${d.alternatives.join(' | ')}`)
    } else {
      log(`   💡 ${d.choice} — ${d.rationale}`)
    }
  }
}

if (arch.health === 'RED') {
  log('🏛  RED — stopping loop, notifying you.')
  await agent(
    `Read ${ROOT}/.nbl/prompts/alm.md for your role.
The Architect flagged RED. Write ${ROOT}/CHECKPOINT.md (status: action_required).
Blocking issue: ${arch.brief_markdown}
Append to ${ROOT}/AGENT_LOG.md.
Send Gmail draft to <owner-email>, subject: "🚨 ACTION NEEDED: [Nexus Build] Architect RED — decision required".`,
    { schema: ALM_SCHEMA }
  )
  return { health: 'RED', brief: arch.brief_markdown }
}

// ── Phase: Plan ────────────────────────────────────────────────────────────

phase('Plan')
log('📋 Planner selecting tasks from BUILD_PLAN.md...')

const plan = await agent(
  `Read the prompt at ${ROOT}/.nbl/prompts/planner.md first.

Then read:
- ${ROOT}/BUILD_PLAN.md
- ${ROOT}/.nbl/config.md
- ${ROOT}/.nbl/ARCH_BRIEF.md

Architect's recommended_priority: ${JSON.stringify(arch.recommended_priority)}

Select eligible tasks and return structured output.`,
  { schema: PLAN_SCHEMA }
)

if (plan.eligible.length === 0) {
  log('📋 No eligible tasks — all remaining are gated or complete.')
  log(`📋 Waiting on: ${plan.gated.map(t => t.gate_reason).join(', ')}`)
  await agent(
    `Read ${ROOT}/.nbl/prompts/alm.md for your role.
Write ${ROOT}/CHECKPOINT.md and append to ${ROOT}/AGENT_LOG.md.
Gated tasks: ${JSON.stringify(plan.gated)}
Send Gmail draft to <owner-email>: "[Nexus Build] No tasks available — gates pending".`,
    { schema: ALM_SCHEMA }
  )
  return { plan, gated: plan.gated }
}

log(`📋 Selected ${plan.eligible.length} task(s): ${plan.eligible.map(t => `${t.id} "${t.title}"`).join(', ')}`)
if (plan.gated.length > 0) {
  log(`📋 Still waiting on you: ${plan.gated.map(t => `${t.id} (${t.gate_reason})`).join('; ')}`)
}

// ── Build → Test → Review loop ─────────────────────────────────────────────

const results = []
const n = plan.eligible.length

for (let i = 0; i < n; i++) {
  const task = plan.eligible[i]
  log(``)
  log(`━━━ Task ${i+1}/${n}: ${task.title}  [${task.id}] ━━━`)

  // ── SWE ──────────────────────────────────────────────────────────────────
  phase('Build')
  log(`🏗  SWE agent building "${task.title}"...`)

  const swe = await agent(
    `Read ${ROOT}/.nbl/prompts/swe.md for your role and conventions.

TASK ID: ${task.id}
TASK: ${task.title}

Architect risks to address: ${JSON.stringify(arch.risks)}

IMPORTANT: Include a decisions[] array. For every significant choice (library, approach,
error handling strategy, data model field), log it as a decision. Write rationale in plain
English for a product manager — no jargon. Mark anything affecting product scope or the
data model as "major"; everything else "minor".

Implement this task completely. Return structured output.`,
    { schema: SWE_SCHEMA, isolation: 'worktree' }
  )

  log(`🏗  SWE ${swe.status}: ${swe.files_created.length} file(s) created, ${swe.files_modified.length} modified`)
  log(`   ${swe.summary}`)

  if (swe.decisions && swe.decisions.length > 0) {
    for (const d of swe.decisions) {
      if (d.impact === 'major') {
        log(`   🚨 MAJOR DECISION: "${d.choice}"`)
        log(`      Why: ${d.rationale}`)
        log(`      Alternatives: ${d.alternatives.join(' | ')}`)
      } else {
        log(`   💡 ${d.choice} — ${d.rationale}`)
      }
    }
  }

  if (swe.status === 'blocked') {
    log(`   ⛔ Blocked: ${swe.blockers.join('; ')}`)
    results.push({ task, swe, test: null, review: null, outcome: 'blocked' })
    continue
  }

  // ── Test ──────────────────────────────────────────────────────────────────
  phase('Test')
  log(`🧪 Test agent running tests for ${task.id}...`)

  const test = await agent(
    `Read ${ROOT}/.nbl/prompts/tester.md for your role and conventions.

Task: ${task.id} — ${task.title}
Files created: ${JSON.stringify(swe.files_created)}
Files modified: ${JSON.stringify(swe.files_modified)}
Test hints: ${JSON.stringify(swe.test_hints)}

Working directory: ${ROOT}
Write and run tests. Return structured output.`,
    { schema: TEST_SCHEMA }
  )

  log(`🧪 Tests: ${test.tests_passed} passed, ${test.tests_failed} failed — ${test.verdict}`)
  if (test.tests_failed > 0 && test.failure_details) {
    for (const f of test.failure_details) {
      log(`   ✗ ${f.test}: ${f.reason}`)
    }
  }

  // ── Review ────────────────────────────────────────────────────────────────
  phase('Review')
  log(`👁  Review agent checking ${task.id}...`)

  let review = await agent(
    `Read ${ROOT}/.nbl/prompts/reviewer.md for your role and checklist.

Task: ${task.id} — ${task.title}
SWE branch: ${swe.branch || 'current worktree'}
SWE summary: ${swe.summary}
Test results: ${JSON.stringify(test)}
Architect risks: ${JSON.stringify(arch.risks)}

IMPORTANT: Include a decisions[] for judgment calls you made during review — e.g. why you
chose approve_with_notes instead of request_changes, or what you considered escalating.
Plain English for a PM.

Review the diff and return structured output.`,
    { schema: REVIEW_SCHEMA }
  )

  log(`👁  Review: ${review.verdict} — ${review.summary}`)
  if (review.decisions && review.decisions.length > 0) {
    for (const d of review.decisions) {
      if (d.impact === 'major') {
        log(`   🚨 MAJOR CALL: "${d.choice}" — ${d.rationale}`)
      } else {
        log(`   💡 ${d.choice} — ${d.rationale}`)
      }
    }
  }

  // ── Retry if needed ───────────────────────────────────────────────────────
  if (review.verdict === 'request_changes' && !task._retried) {
    log(`   🔁 Changes requested — one retry for ${task.id}`)
    task._retried = true
    const issueList = review.issues.map(i => `[${i.severity}] ${i.file}: ${i.message}`).join('\n')

    phase('Build')
    log(`🏗  SWE retry for ${task.id}...`)

    const swe2 = await agent(
      `Read ${ROOT}/.nbl/prompts/swe.md for conventions.
RETRY — task ${task.id}: ${task.title}
Fix these issues:
${issueList}
Original summary: ${swe.summary}
Architect risks: ${JSON.stringify(arch.risks)}
Include decisions[] for any new choices made.`,
      { schema: SWE_SCHEMA, isolation: 'worktree' }
    )

    log(`🏗  Retry ${swe2.status}: ${swe2.summary}`)
    if (swe2.decisions) {
      for (const d of swe2.decisions) {
        log(`   💡 ${d.choice} — ${d.rationale}`)
      }
    }

    phase('Review')
    log(`👁  Re-reviewing ${task.id}...`)

    const review2 = await agent(
      `Read ${ROOT}/.nbl/prompts/reviewer.md.
Re-review ${task.id} after retry. Verify all issues are fixed.
Original issues: ${JSON.stringify(review.issues)}
New implementation: ${swe2.summary}
Include decisions[] for any judgment calls.`,
      { schema: REVIEW_SCHEMA }
    )

    log(`👁  Review (retry): ${review2.verdict} — ${review2.summary}`)
    results.push({ task, swe: swe2, test, review: review2, outcome: review2.verdict })
  } else {
    results.push({ task, swe, test, review, outcome: review.verdict })
  }
}

// ── Collect all decisions ──────────────────────────────────────────────────

const allDecisions = [
  ...(arch.decisions || []),
  ...results.flatMap(r => [
    ...(r.swe && r.swe.decisions ? r.swe.decisions : []),
    ...(r.review && r.review.decisions ? r.review.decisions : []),
  ])
]
const majorDecisions = allDecisions.filter(d => d.impact === 'major')

if (majorDecisions.length > 0) {
  log(``)
  log(`🚨 ${majorDecisions.length} major decision(s) this cycle — they'll be in CHECKPOINT.md`)
}

// ── Commit ─────────────────────────────────────────────────────────────────

phase('Commit')
log(``)
log('📬 ALM: merging, writing CHECKPOINT.md, sending email...')

const alm = await agent(
  `Read ${ROOT}/.nbl/prompts/alm.md — follow those steps in order.

Cycle results: ${JSON.stringify(results, null, 2)}
Gated tasks: ${JSON.stringify(plan.gated)}
Architect health: ${arch.health}
All decisions this cycle: ${JSON.stringify(allDecisions, null, 2)}
Project root: ${ROOT}
Report recipient: <owner-email>`,
  { schema: ALM_SCHEMA }
)

log(``)
const emoji = alm.status === 'clean' ? '✅' : alm.status === 'review_recommended' ? '⚠️' : '🚨'
log(`${emoji} Cycle complete — status: ${alm.status}`)
log(`   Completed: ${alm.tasks_completed.length > 0 ? alm.tasks_completed.join(', ') : 'none'}`)
if (alm.tasks_blocked.length > 0) log(`   Blocked: ${alm.tasks_blocked.join(', ')}`)
log(`   Open CHECKPOINT.md to verify what was built and see what's next.`)

return { arch, plan, results, alm }
