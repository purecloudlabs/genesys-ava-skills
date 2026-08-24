# Changelog

## null

pipeline testing

## 1.5.0

Improve Setup 

### CLI

A single **`ava-mcp`** command, with a short alias for each subcommand:

| Command | Alias | Does |
| --------- | ------- | ------ |
| `ava-mcp serve` | `run` | Start the MCP stdio server — use this in `mcp.json` |
| `ava-mcp setup` | `init` | Interactive local install wizard |
| `ava-mcp update [DEST]` | `sync` | Install / refresh AVA skills and subagents |
| `ava-mcp docs [GUIDE]` | `doc` | Print a bundled offline setup guide |

- `ava-mcp --version` reports the installed version; `ava-mcp <command> --help` documents each subcommand.
- `ava-mcp update` is interactive on a terminal — run it with no arguments to pick scope and IDE(s). Passing `DEST`, `--yes`, or `--dry-run` runs headless instead.
- `ava-mcp docs` selects a guide positionally: `ava-mcp docs install`, `ava-mcp docs validate`, `ava-mcp docs verify`, or bare for the entry guide.
- `ava-mcp setup` and `ava-mcp update` check for a newer published wheel before doing anything else. On a terminal they show the version delta and offer to exit so you can update first; headless runs print a one-line stderr warning and continue. Offline or rate-limited lookups are silent.


## 1.4.0

First public release of **ava-mcp**: MCP tools plus bundled AVA lifecycle skills
and subagents for designing, publishing, evaluating, and critiquing Genesys Cloud AVAs.

### Skills

Lifecycle skills (install via `ava-mcp-setup` / `ava-mcp-update`):

- **ava-dispatch** — entry point; detects org context and routes the design → build → test → evaluate → critique flow
- **ava-design** — collect/edit AVA role, instructions, guardrails, tools, events, context, and test cases into a design artifact
- **ava-knowledge** — author, validate, and upload Knowledge Fabric FileUpload content
- **ava-build** — create/update and publish an AVA from the design artifact 
- **ava-test** — author turn-based evaluation scenarios and test sets under `.ava-lifecycle/`
- **ava-evaluate** — run scenarios against a published AVA and produce a success-rate scorecard
- **ava-critique** — review a design artifact or live version for quality / readiness issues
- **ava-analysis** — auxiliary analysis skill used by critique (quick-guide + cookbook checks)

### Subagents

- **ava-design-assist** — cookbook checks during design, before the artifact is saved
- **ava-scenario-runner** — runs one evaluation scenario end-to-end (actor + Layer 1/2 judging)
- **ava-critique** — full analysis via ava-analysis, then persists a critique report

### Tools

MCP tools over the public Genesys Cloud API (Pydantic-validated payloads):

- **Resource discovery** — `list_resources`
- **(AVA management)** — `get_ava`, `create_ava`, `get_latest_saved_version`, `get_latest_published_version`, `create_version`, `publish_version`
- **Hedwig** — `get_data_action_schema`
- **Knowledge Fabric FileUpload** — `validate_knowledge`, `ensure_knowledge_source`, `upload_knowledge_documents`, `ensure_knowledge_setting`
- **AVA Chat Session** — tools to start/end session, and add message to a session.
- **Evaluation** — `validate_trajectory`, `generate_scorecard`, `generate_critique_report`
- **Mock DataActions** — `create_mock_data_action`, `replace_mock_responses`
- **Authorization** — `permissions` (setup / diagnostic when `AVA_TEST_MODE=true`)
