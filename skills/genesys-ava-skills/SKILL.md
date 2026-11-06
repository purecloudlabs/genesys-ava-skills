---
name: genesys-ava-skills
description: >
  Table of contents for the Genesys Cloud AVA (Agentic Virtual Agent) skills shipped with the AVA
  MCP server, how to load them with the list_skills / read_skill tools, and how to run any sub-agent
  a skill asks for through the installed genesys-ava-agent runner. Those skills let you create a new AVA or update an existing one end to end:
  gather requirements and design its role, instructions, guardrails, tools, events and context
  variables; author and upload Knowledge Fabric content; build and publish it to Genesys Cloud;
  write turn-based test scenarios and run them as a scored evaluation; critique a design or
  published AVA for quality and Polaris 28 compliance; and set up a Navigator that routes callers
  by intent to existing AVAs, Guides or bot flows. Use first for any Genesys Cloud AVA or Navigator
  task when the other ava-* skills aren't already loaded, to find which skill applies.
compatibility: ava-harness
metadata:
  version: 1.7.0
  author: Genesys Cloud Services, Inc.
license: MIT. See root LICENSE file.
---

# Genesys AVA Skills — Table of Contents

This skill is an index. It holds no workflow of its own: find the skill that
fits the task below, then load it with the MCP tools.

## What you can do

| Goal | Skills, in order |
|---|---|
| Create a new AVA from scratch or from requirement documents | `ava-dispatch` → `ava-design` → (`ava-knowledge`) → `ava-build` |
| Change an existing AVA (instructions, tools, guardrails, events, variables) | `ava-dispatch` → `ava-design` (update mode) → `ava-build` |
| Give an AVA a knowledge base (demo/POC content, documents turned into AI-ready cards, public research) | `ava-knowledge` |
| Test a published AVA with persona-driven, multi-turn scenarios | `ava-test` → `ava-evaluate` |
| Get a pass-rate scorecard with tool-call and rubric checks | `ava-evaluate` |
| Review an AVA for authoring quality, Polaris 28 compliance or deployment readiness | `ava-critique` |
| Put several AVAs, Guides or bot flows behind one intent-routed phone entry point | `ava-navigator` |
| Not sure where to start | `ava-dispatch` |

## Skills

| Skill | Use it to |
|---|---|
| `ava-dispatch` | **Start here** for any AVA authoring session. Detects org context, lists existing AVAs, chooses new vs. update, and routes to the right step of design → build → test → evaluate → critique. |
| `ava-design` | Collect and edit an AVA's name, role, instructions, guardrails, tools, events, context variables and test cases. Produces `design-artifact.json`. |
| `ava-knowledge` | Author, validate and upload Knowledge Fabric FileUpload content, and ensure the Knowledge Source and Knowledge Setting. |
| `ava-build` | Create or update and publish an AVA from `design-artifact.json` through the Sage API. |
| `ava-test` | Author turn-based evaluation scenarios for a published AVA and assemble them into a test set. |
| `ava-evaluate` | Run a test set as multi-turn conversations and produce the success-rate scorecard. |
| `ava-critique` | Review an AVA design or published version for Polaris 28 compliance, payload correctness, test coverage and deployment readiness. |
| `ava-navigator` | Design and create a Navigator: one intent-routed bot flow over existing AVAs, Guides or botflows, plus its inbound call flow. |

## Loading skills

1. `list_skills()` returns the `name` and `description` of every skill available
   to you. Use the description to confirm a skill applies.
2. `read_skill(name="ava-build")` returns the skill's `SKILL.md` file.
3. Follow the skill's instructions. When it links a supporting file (for example
   `references/sage-api-schema.md`), load it with
   `read_skill(name="ava-build", path="references/sage-api-schema.md")`. The
   `path` is relative to the skill folder; `list_skill_files(name="ava-build")`
   lists every valid one.
4. Relative links between skills (`../ava-design/SKILL.md`) mean
   `read_skill(name="ava-design")`.

Load a skill only when you reach the step that needs it, and load reference
files only when the skill tells you to. `ava-mcp skills sync` installs only
this index skill and the `genesys-ava-agent` runner; every other skill comes
from these tools, so it always matches the installed MCP server version.

## Using sub-agents

Some skills hand part of their work to a named sub-agent. Those sub-agents are
not installed in your IDE; they are served by the MCP server. The one
sub-agent that is installed, **`genesys-ava-agent`**, is a generic runner: you
give it a sub-agent name and inputs, it loads that sub-agent's definition with
`read_agent`, and follows it in its own isolated context.

### When to start it

Whenever a skill you have loaded says to launch, dispatch, or delegate to a
sub-agent. The skill names the sub-agent, says what to pass it, and says what
to do with the result. Take all three from the skill; don't decide them here.

### How to start it

Use your client's sub-agent tool (the Task/Agent tool in Claude Code, Cursor
and Kiro) with sub-agent type `genesys-ava-agent`. Put the sub-agent name the
skill gave you on the first line of the prompt, and the inputs the skill
describes below it:

```text
agent: <sub-agent name from the skill>

<inputs the skill says to pass>
```

- **Pass everything it needs.** The runner can't see your conversation or ask
  the user anything. If it reports a missing input, get it and start it again.
- **Don't load the definition yourself** with `read_agent` first. The runner
  does that, which keeps the definition and its intermediate work out of your
  context.
- **Follow the skill** for concurrency (for example one runner per item, a few
  in parallel) and for how to use what the runner returns.

### If `genesys-ava-agent` isn't available

If your client can't start sub-agents, or `genesys-ava-agent` isn't installed
(run `ava-mcp skills sync` to install it), call `read_agent` with the name the
skill gave you and follow the definition yourself in the main conversation.
The skills that dispatch sub-agents describe this sequential fallback.

The same content is also available as MCP resources (`skill://<name>/SKILL.md`,
`sub-agents://<name>.md`) for clients that support resources.
