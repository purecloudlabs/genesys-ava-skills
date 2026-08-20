# Changelog

## 1.4.0

- The `ava-orchestrate` skill has been renamed to `ava-dispatch` for a clearer, literal name consistent with the other skill names (`ava-design`, `ava-build`, `ava-test`, `ava-evaluate`, `ava-critique`). No behavior change — update any references to the old skill name.
- The evaluation report (`scorecard.html`) has been redesigned: the hero now shows Pass Rate / Total Simulations metric cards and a results donut chart, followed by "Needs Attention" and "Passing Tests" scenario lists. Each scenario opens a modal with Results and Scenario tabs; the Results tab breaks attempts down into Success criteria, Tool check, and Script match, alongside the full simulation transcript.
- The `ava-scenario-runner` subagent now persists richer per-attempt detail for the report to render: each rubric verdict includes the assertion text it's judging; the expected tool trajectory includes full per-step parameters and match mode (not just tool names); and each attempt records the scenario's outlined script turns and metadata (persona, goal, language, thresholds) alongside the simulated transcript.

## 1.3.0

- Mock DataAction authoring now runs through one shared draft → test → publish lifecycle for both backends, with the same pre-flight checks, verification, and publish path regardless of which backend is selected.
- Backend selection is automatic and invisible to the author: any error outcome routes to the templated echo backend (supports both response and error outcomes); success-only mocks use the function-based backend. The function-based backend rejects error outcomes, so a negative-path mock needs at least one error case handled by the echo backend.
- Output schemas may now have a root array (`"type": "array"`) in addition to an object, and may nest objects/arrays to any depth. Success response bodies must match the root type — a list for array, a dict for object — or the request is rejected at validation time.
- New interactive local install wizard, `ava-mcp-setup`: runs the whole local install from a downloaded wheel with no API Gateway required, asking for install scope, IDE(s) (Cursor / Kiro / Claude Code — Claude Code is project-scope only), and which actions to perform.
- Skill docs refreshed: `ava-design` and `ava-test` document the function-based mock backend and output schema shapes; a canonical error-code contradiction in `ava-build` was fixed; `ava-knowledge` references expanded (research mode, synthetic content, audience, use-case templates).

## 0.5.0

- New `ava-knowledge` skill: author and validate Knowledge Fabric Markdown cards, then upload documents and ensure Knowledge Settings are in place.
- New MCP tools: `validate_knowledge`, `ensure_knowledge_source`, `upload_knowledge_documents`, `ensure_knowledge_setting`; `list_resources` adds `knowledge_source`.
- Source and setting names are now configurable per engagement (no shared hardcoded default); Full vs. Incremental sync is confirmed before running; org capacity for knowledge sources (~10) is documented.
- An optional probe disables knowledge upload (`AVA_KNOWLEDGE_UPLOAD_DISABLED`) when the required write grants are missing.
- Lifecycle: `ava-orchestrate` / `ava-design` now hand off to `ava-knowledge` before attaching it to an AVA.
- The `AVA_ORG_ID` / org ID setup question has been removed entirely — org resolution is no longer required for public API setup. Removed from the setup guide's question groups, the `mcp.json` config examples, and the bundled skill docs.
- `ava-build` now publishes as TestReady by default — the new version is immediately available for testing and evaluation without routing production traffic to it. Promoting to ProductionReady is now a separate, explicitly confirmed step, gated on a passing evaluation scorecard and a clean critique.
- `ava-critique` now resolves the version to review automatically, falling back to the latest saved version when no ProductionReady version exists yet (covers TestReady/Draft). When the critique is clean and evaluation has passed, it now offers to promote the AVA to production.
- Removed a setup guide appendix describing internal mock DataAction test-harness infrastructure — it wasn't relevant to the install flow.

## 0.4.0

- New `generate_scorecard` workflow produces run-level scorecard outputs (`scorecard.json`, `scorecard.md`, `scorecard.html`) from scenario-runner attempt files.
- Scorecard HTML reports now include full attempt detail: transcripts, tool calls, rubric assertions, guardrail evidence, and trajectory views for interactive review.
- Bundled AVA skills and subagents updated, including the new `ava-scenario-runner` subagent.
- Sample reports now include a Scorecard Report example alongside the Critique Report sample.
