# AVA - Spec-Driven Development

![AVA](./ava-banner.svg)

![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)
![GitHub Release](https://img.shields.io/github/v/release/purecloudlabs/genesys-ava-skills?label=Release)

Bring the full Genesys Cloud Agentic Virtual Agent (AVA) lifecycle into your AI coding IDE. Design, build, test, evaluate, and critique AVAs from Cursor, Kiro, or Claude Code without hand-writing a single API call.

## Quick Start

1. **Install [`uv`](https://docs.astral.sh/uv/getting-started/installation/)** if you don't have it already. (Ensure `uv` is not installed in a virtual environment because the wizard needs access to global Python.)
2. **Run the installer (Linux/Mac)**:

    ```bash
    curl -sSL https://raw.githubusercontent.com/purecloudlabs/genesys-ava-skills/main/install.sh | sh
    ```
   **Run the installer (Windows)**:

    ```bash
   irm https://raw.githubusercontent.com/purecloudlabs/genesys-ava-skills/main/install.ps1 | iex
    ```

NOTE: If you run into an error around TLS on the install you may need to run the below commands before running the install script.
Windows: `$env:UV_SYSTEM_CERTS = "true"` 
Linux/MAC: `export UV_SYSTEM_CERTS="true"`

3. **Run the setup wizard** from your project directory:

    ```bash
    ava-mcp setup
    ```

   Follow the prompts — pick your IDE (Cursor, Kiro, or Claude Code) and confirm the install plan. For Claude Code and Kiro the wizard can register the MCP server for you. The wizard does not sign in.
4. **Restart your IDE** (or reload MCP). On first start the AVA Harness opens your browser so you can pick your Genesys Cloud region and sign in (approve the app on your first login). See [Signing in](#signing-in).
5. **Start a new agent session** and say something like:
   > Help me design a new AVA

   The `ava-dispatch` skill takes it from there.

## Usage Examples

Once installed, start a new agent session in your IDE and use natural language. Here are common workflows:

| What you want to do | What to say |
| ------------------- | ----------- |
| Create a new AVA from scratch | "Help me design a new AVA for appointment scheduling" |
| Iterate on an existing AVA | "Update my Travel Booking AVA to add a cancellation flow" |
| Add knowledge to an AVA | "Add FAQ knowledge cards to my Support AVA" |
| Build and publish | "Build and publish my AVA" |
| Write evaluation scenarios | "Create test scenarios for my AVA" |
| Run evaluations | "Evaluate my AVA against the test set" |
| Get a quality review | "Critique my AVA" |
| Start a conversation with a published AVA | "Start a session with my AVA and test it" |

You don't need to remember skill names — `ava-dispatch` reads your local session state and routes to the right skill automatically.

## Prerequisites

To use these skills with a Genesys Cloud org, you need a role with these permissions:

| Domain         | Entity                                           | Actions                           |
| -------------- | ------------------------------------------------ | --------------------------------- |
| `integrations` | `action`                                         | `view` (or `bridge:actions:view`) |
| `agentic`      | `virtualAgent`                                   | `add`, `edit`, `view`             |
| `agentic`      | `virtualAgentVersion`                            | `add`, `edit`, `view`             |
| `agentic`      | `virtualAgentVersionJob`                         | `add`, `view`                     |
| `agentic`      | `virtualAgentSession`, `virtualAgentSessionTurn` | `add`                             |
| `knowledge`    | `knowledgebase`                                  | `view`                            |
| `knowledge`    | `knowledgeSetting`                               | `view`                            |
| `knowledge`    | `source`                                         | `view`                            |

These core grants are always required. These are role permissions on the signed-in user, and `ava-mcp login` saves nothing if any are missing.

Some tool groups need extra, optional permissions. If they are missing, sign-in hides the matching tools automatically (restart your IDE or reload MCP for this to take effect):

| Tool group                | Used by                                                                              | Flag set when a grant is missing      |
| ------------------------- | ------------------------------------------------------------------------------------ | ------------------------------------- |
| Mock DataAction authoring | `create_mock_data_action`, `replace_mock_responses`                                  | `AVA_MOCK_DATA_ACTIONS_DISABLED=true` |
| Knowledge FileUpload      | `ava-knowledge` upload tools                                                         | `AVA_KNOWLEDGE_UPLOAD_DISABLED=true`  |
| Navigator authoring       | `preview_navigator`, `build_navigator`                                               | `AVA_NAVIGATOR_TOOLS_DISABLED=true`   |

Discovery tools (e.g., `list_resources`, `get_data_action_schema`, `validate_knowledge`) stay available either way.

See [docs/permissions.md](./docs/permissions.md) for the full permission tables for each group and the OAuth scopes you need if you bring your own OAuth client.

## Installation

The install script installs the `ava-mcp` CLI as a `uv` tool. Then run `ava-mcp setup` from your project directory. During the configuration, the wizard asks you for the following:

| Decision      | Values                                                                                                                                         |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| Install scope | `project` (this repo, recommended) or `user` (all projects; not recommended)                                                                   |
| IDE(s)        | Cursor, Kiro, and Claude Code                                                                                                                  |
| Actions       | Install MCP and/or Install/refresh skills and subagents                                                                                        |
| MCP config    | Claude Code and Kiro: auto-register the server through the IDE's CLI, or copy the `mcp.json` snippet yourself. Other IDEs: copy the snippet. |

The wizard does not ask for a region or credentials — see [Signing in](#signing-in).

### MCP configuration

The MCP entry is deliberately small — it holds no credentials:

```json
{
  "mcpServers": {
    "ava-harness": {
      "command": "ava-mcp",
      "args": ["serve"],
      "env": {
        "FASTMCP_LOG_LEVEL": "ERROR"
      },
      "disabled": false,
      "timeout": 60000
    }
  }
}
```

For Claude Code this lives in `./.mcp.json`; for Kiro, `./.kiro/settings/mcp.json`. With auto-install, the wizard runs `claude mcp add ava-harness ...` or `kiro-cli mcp add ava-harness ...` for you.

### Signing in

Credentials are stored in `./.ava_mcp/config.toml` (relative to the directory you run the command in), never in `mcp.json`. Add `.ava_mcp/` to your `.gitignore` so a token or client secret is never committed.

- **Browser sign-in (default).** On first start, `ava-mcp serve` opens your browser to pick a Genesys Cloud region and sign in; approve the app on your first login. The session lasts about 12 hours, and in production an expired session reopens the browser automatically. You can also sign in ahead of time with `ava-mcp login`.
- **Your own OAuth client.** Run `ava-mcp login --auth client-credentials`, or set `AVA_HABITAT` together with `GENESYS_CLIENT_ID` / `GENESYS_CLIENT_SECRET` (or `GENESYS_ACCESS_TOKEN`) in the environment.
- **A stored session takes precedence over environment variables.** If you used environment credentials before and then run `ava-mcp login`, the environment credentials are ignored until you run `ava-mcp logout`.
- **Permissions are checked at sign-in.** `ava-mcp login` only saves a session if the core permissions are granted. Environment-variable credentials are not checked.

See [docs/cli.md](./docs/cli.md#credentials-and-precedence) for the full precedence rules and a sample `mcp.json` with your client id, secret, and habitat in the `env` block.

### `ava-mcp` commands

| Command               | Does                                                         |
| --------------------- | ------------------------------------------------------------ |
| `ava-mcp setup`       | Interactive install wizard (alias: `init`). Does not sign in. |
| `ava-mcp serve`       | Start the MCP stdio server — what `mcp.json` launches.        |
| `ava-mcp login`       | Sign in to Genesys Cloud (browser, or `--auth client-credentials`). |
| `ava-mcp logout`      | Clear the stored sign-in.                                     |
| `ava-mcp skills sync` | Install or refresh AVA skills and subagents after an update.  |
| `ava-mcp upgrade`     | Upgrade `ava-mcp` itself.                                     |

See [docs/cli.md](./docs/cli.md) for every command, flag, and example, including `status`.

## AI Skills

After the installation is complete, the following AI Skills are installed that will be invoked as needed:

| Skill          | What it does                                                                                                                                                                                          |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ava-dispatch` | Entry point. Routes incoming requests to the right skill based on local session state — detects new vs existing AVA, checks for remote changes, and dispatches accordingly. Every session starts here. |
| `ava-design`   | Collects or edits AVA config — name, role, instructions, guardrails, tools, events, context variables, test cases — into a design artifact the build skill consumes.                                  |
| `ava-knowledge` | Authors, validates, and uploads Knowledge Fabric FileUpload content, and ensures a FileUpload Knowledge Source and Knowledge Setting for the AVA.                                                    |
| `ava-build`    | Builds and publishes the AVA from the design artifact, validating the definition before it reaches the Sage API. Handles both new AVAs and version updates.                                           |
| `ava-test`     | Authors turn-based evaluation scenarios (persona, goal, ordered turns, reference trajectory, dimension-tagged rubric) and assembles them into a test set.                                             |
| `ava-evaluate` | Runs the scenarios as multi-turn conversations and reports a success-rate scorecard. Projects cost first, then delegates scenarios to the scenario-runner subagent.                                    |
| `ava-critique` | Reviews an AVA design or published version for quality — best-practice compliance, payload correctness, test coverage, deployment readiness.                                                          |
| `ava-analysis` | Deep AVA-definition analysis (role, tools, knowledge, configuration, guardrails) that produces an in-memory report. Used by the `ava-critique` subagent.                                              |
| `ava-navigator` | Designs and creates a Navigator: one bot flow that classifies a caller's intent and routes each intent to an existing AVA, Guide, or botflow, plus one inbound call flow that calls it. Shows a draft preview before anything is created in Genesys Cloud. |

`ava-analysis` is an auxiliary skill invoked by critique — it is not a lifecycle step of its own. `ava-navigator` is a standalone skill you invoke directly (see [Navigator flow](#navigator-flow)); `ava-dispatch` does not route to it.

## Sub-agents

After the installation is complete, the following sub-agents are installed that will be invoked as needed:

| Subagent              | What it does                                                                                                                                                                                                                                                                                                                                                                        |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ava-scenario-runner` | Runs one turn-based evaluation scenario end-to-end in an isolated context — acts as the simulated user, drives the conversation via the `cicero_*` tools, runs Layer 1 (deterministic trajectory) and Layer 2 (rubric) checks, and persists per-attempt results. Scoring happens once, after every runner finishes, via `generate_scorecard`. Runs in parallel for fast evaluation. |
| `ava-critique`        | Drives the `ava-analysis` skill to produce an authoring-quality review, then calls `generate_critique_report` and returns a summary.                                                                                                                                                                                                                                                |
| `ava-design-assist`   | Runs comprehensive cookbook analysis on a design-in-progress to detect advanced patterns and suggest fixes before saving.                                                                                                                                                                                                                                                           |
| `ava-navigator-researcher` | Resolves and verifies the AVAs, botflows, and Guides named for a Navigator (by id or name) and writes a short real description of each from its definition. Reports resolved / not found / unpublished / ambiguous back to `ava-navigator`; never talks to the user.                                                                                                       |

## AVA Harness

The AVA Harness is a Model Context Protocol (MCP) server that gives your IDE agent direct, validated access to the Genesys Cloud AVA lifecycle.

The Harness exposes each AVA operation as a Pydantic-validated tool. Instead of hand-writing raw API calls and retrying after the backend rejects a malformed payload, the Harness validates each payload locally — bad payloads are caught **before any request reaches Genesys Cloud**. Every tool calls the public Genesys Cloud API; there is no private-backend fallback.

## Tools

### AVA management

| Tool                           | Description                                                                                                 |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------- |
| `list_resources`               | Find resources in the org. Use `resource_type="ava"` first to get `agentId` values. Optional `name` filter. |
| `get_ava`                      | Get full details of a specific AVA by ID.                                                                   |
| `create_ava`                   | Create a new AVA. Idempotent — returns the existing AVA if the name matches.                                |
| `get_latest_saved_version`     | Get the most recent version (any status) as an editable definition.                                         |
| `get_latest_published_version` | Get the latest ProductionReady version.                                                                     |
| `create_version`               | Create a new version from a validated `VersionDefinition`.                                                  |
| `publish_version`              | Publish a version and poll until complete (TestReady or ProductionReady).                                   |

### DataAction discovery

| Tool                     | Description                                                                                   |
| ------------------------ | --------------------------------------------------------------------------------------------- |
| `list_resources`         | Find DataActions with `resource_type="data_action"` (optional name filter) and get their IDs. |
| `get_data_action_schema` | Fetch a DataAction's input/output schema to auto-populate AVA tool config.                    |

### Knowledge discovery

| Tool                         | Description                                                                                                                         |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `list_resources`             | Find Knowledge Bases, Settings, or Sources with `resource_type` `"knowledge_base"`, `"knowledge_setting"`, or `"knowledge_source"`. |
| `validate_knowledge`         | Offline Markdown card validation — gates upload on structural FAIL.                                                                 |
| `ensure_knowledge_source`    | Reuse or create a FileUpload Knowledge Source.                                                                                      |
| `upload_knowledge_documents` | Sync, upload, complete, and wait until FileUpload documents are ready.                                                              |
| `ensure_knowledge_setting`   | Reuse or create a Knowledge Setting bound to one source.                                                                            |

FileUpload authoring tools (`ensure_knowledge_source`, `upload_knowledge_documents`, `ensure_knowledge_setting`) are on by default. Disable with `AVA_KNOWLEDGE_UPLOAD_DISABLED=true` if the OAuth client lacks the Knowledge Fabric grants. `list_resources` and `validate_knowledge` stay available either way.

### Conversation sessions

| Tool                   | Description                                                                       |
| ---------------------- | --------------------------------------------------------------------------------- |
| `cicero_start_session` | Start a session against a published AVA and return the greeting.                  |
| `cicero_send_message`  | Send a user message and return the agent's response, tool calls, and next action. |
| `cicero_end_session`   | Terminate an active session (best-effort cleanup).                                |

### Evaluation

| Tool                       | Description                                                                            |
| -------------------------- | -------------------------------------------------------------------------------------- |
| `validate_trajectory`      | Deterministic Layer 1 comparison of actual tool calls vs a reference trajectory.       |
| `generate_scorecard`       | Score every persisted attempt in an eval run and write JSON / Markdown / HTML reports. |
| `generate_critique_report` | Render an authoring-quality critique into JSON / Markdown / HTML reports.              |

### Navigator *(on by default)*

Disable by setting `AVA_NAVIGATOR_TOOLS_DISABLED=true` if the signed-in user lacks the Navigator authoring grants listed in [docs/permissions.md](./docs/permissions.md#navigator-authoring).

| Tool                | Description                                                                                                                                                  |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `preview_navigator` | Validate a Navigator draft against the org (assets exist and are published, intents and CCA schema resolve), save it, and render a visual preview.          |
| `build_navigator`   | Re-run every check on the confirmed draft and create the Navigator bot flow and inbound call flow.                                                          |

`list_resources` discovery for `botflow`, `guide`, `cca_schema`, and `customer_intent_category` stays available either way.

### Mock DataActions *(on by default)*

Disable by setting `AVA_MOCK_DATA_ACTIONS_DISABLED=true` if the signed-in user
lacks the Mock DataAction authoring grants listed in [docs/permissions.md](./docs/permissions.md#mock-dataaction-authoring).

| Tool                      | Description                                                       |
| ------------------------- | ----------------------------------------------------------------- |
| `create_mock_data_action` | Create a mock DataAction for testing reference trajectories.      |
| `replace_mock_responses`  | Replace the entire mock response table of an existing DataAction. |

`list_resources(resource_type="data_action")` and `get_data_action_schema` stay available regardless.

## The lifecycle

```text
ava-dispatch → ava-design ⇄ ava-knowledge → ava-build → ava-test → ava-evaluate
                        ↑                                          │
                        └──── ava-critique (any time) ─────────────┘
```

**Reading the diagram:**

| Arrow    | Meaning                                                                                                                                                                                                |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `→`      | Hands off to the next skill in sequence.                                                                                                                                                               |
| `⇄`      | Bidirectional — `ava-design` and `ava-knowledge` iterate together. Knowledge authoring may surface changes that feed back into the design artifact, and design changes may trigger new knowledge work.  |
| `↑ └──`  | `ava-critique` can be invoked at any point in the lifecycle and feeds findings back to `ava-design` for revision.                                                                                      |

**Flow summary:**

1. `ava-dispatch` — routes your request to the right skill based on local session state. Detects new vs existing AVA and checks for remote changes before dispatching.
2. `ava-design` ⇄ `ava-knowledge` — iteratively refine the AVA definition and its knowledge content until both are ready.
3. `ava-build` — validates and publishes the design artifact as a new AVA version.
4. `ava-test` — authors evaluation scenarios against the published version.
5. `ava-evaluate` — runs the scenarios and produces a scorecard.
6. `ava-critique` (any time) — reviews quality and feeds findings back to design. Not a sequential step; invoke it whenever you want a second opinion.

## Navigator flow

`ava-navigator` is separate from the lifecycle above. Use it when you want one intent-routed entry point in front of AVAs, Guides, or botflows that already exist — typically AVAs you built and published through the main lifecycle. Ask for it directly, for example: "Create a Navigator for my Billing and Support AVAs".

```text
collect assets → verify assets → confirm assets → propose intents → confirm / edit intents
                 (researcher)
→ configure CCA → preview_navigator ⇄ revise draft → confirm → build_navigator
```

1. **Collect and verify assets** — you name the AVAs, Guides, and botflows; the `ava-navigator-researcher` subagent confirms each exists, is published, and writes a real description from its definition.
2. **Propose and confirm intents** — intents (each optionally linked to one asset) and Conversation Custom Attributes (CCA) are proposed and edited with you; nothing is defaulted silently.
3. **Preview** — `preview_navigator` validates the draft against your org and renders it. Nothing is created in Genesys Cloud yet.
4. **Build** — once you confirm, `build_navigator` creates the Navigator bot flow and one inbound call flow that calls it. A caller asking for a person ends the bot flow and the call flow then disconnects; there is no transfer to a queue. Attaching a phone number is a manual step the skill reminds you about but never performs.

## Where sessions are stored

Each authoring session writes to `.ava-lifecycle/` in your project root (gitignored). Every AVA gets its own subdirectory, so multiple AVAs and sessions never overwrite each other:

```text
.ava-lifecycle/
├── index.json          # every local AVA session: slug → agent_id, gc_version, status
└── <ava-slug>/         # one folder per AVA
    ├── design-artifact.json
    ├── knowledge/      # Fabric Markdown cards + upload artifacts (ava-knowledge)
    ├── test-cases/
    ├── test-sets/
    └── eval-runs/
```

In a nutshell, `ava-dispatch` compares the last known Genesys Cloud AVA version against the live one and prompts you to pull, continue locally, or start fresh if the AVA was edited elsewhere.

## Troubleshooting authentication

For an authentication error (expired or rejected credentials, 401/403 responses, or the MCP server failing to connect), run `ava-mcp logout` and then `ava-mcp login`, then restart your IDE (or reload MCP). If that doesn't help, delete `.ava_mcp/config.toml` — Kiro Powers keeps it at `~/.kiro/powers/installed/ava-harness/.ava_mcp/config.toml`.

See [docs/troubleshooting.md](./docs/troubleshooting.md) for the `config.toml` locations by setup and fixes for missing permissions, 403s after first start, environment credentials being ignored, and missing tools.

## License

This code is provided under the MIT license with no maintenance or support. See [LICENSE](./LICENSE).
