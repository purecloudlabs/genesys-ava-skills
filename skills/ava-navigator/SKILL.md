---
name: ava-navigator
description: >
  Design and create a Genesys Cloud Navigator deployment: one bot flow that
  classifies a caller's intent and routes each intent directly to an existing
  AVA, Guide, or botflow (or speaks the intent itself when unlinked), plus one
  inbound call flow that calls it. Use when a user wants to stand up, wire
  together, or expose multiple existing assets (AVAs/Guides/botflows) behind a
  single intent-routed entry point. Walks the user through asset verification,
  intent/CCA proposal (including the optional per-intent asset link), a visual
  draft preview, and creation -- never requires the user to construct a draft
  or tool payload by hand.
compatibility: ava-harness
metadata:
  version: 1.7.0
  author: Genesys Cloud Services, Inc.
license: MIT. See root LICENSE file.
---

# AVA Navigator

A Navigator is one bot flow (greeting, Agentic Ask for Intent, per-intent
routing) plus one inbound call flow that calls it. Each intent either routes
directly to its linked asset's call action (an existing AVA, Guide, or
botflow) or, when it has no linked asset, speaks itself and exits. This skill
collects and verifies what the user wants, builds a **draft** the user can see
before anything in Genesys Cloud is touched, and then builds the Navigator bot
flow and inbound call flow from the confirmed draft. A caller asking for a
person simply ends the bot flow; the inbound call flow then disconnects --
there is no transfer-to-queue. Phone-number/DID attachment is a separate
manual step this skill will surface at the end but never performs itself.

Two server tools do the work, and neither is ever called with a payload the
user wrote:

- `preview_navigator(draft, draft_file_path)`: validate, save and render the
  draft. Live checks confirm every asset exists, is published, and (for a bot
  flow) is a voice (`BOT`) type; resolve the Customer Intent category/intents
  by name (and fill their ids); confirm the CCA schema and its field types;
  and read the org's text-to-speech catalogue to warn when the inbound call
  flow would be skipped (no usable voice). Validation also includes a local
  structure check of the generated flow documents; it does not prove
  Architect will accept them.
- `build_navigator(path)`: read the confirmed draft file back, re-run every
  one of those same checks, and build. Optionally also binds CCA fields to
  the AVA's properties.

## Quick Reference

| Need | Reference |
| --- | --- |
| Resolving the assets the user names (researcher sub-agent, disambiguation) | [researcher-dispatch.md](references/researcher-dispatch.md) |
| Proposing intents and CCA fields; intent-to-asset coverage | [intent-cca-proposal.md](references/intent-cca-proposal.md) |
| CCA schema choice, property bindings, `post_create_action` | [cca-configuration.md](references/cca-configuration.md) |
| Draft file, preview loop, confirm and build, failures | [draft-lifecycle.md](references/draft-lifecycle.md) |
| The rules a CCA-to-AVA binding must satisfy; late binding after publish | [cca-ava-binding.md](references/cca-ava-binding.md) |

Never silently default anything the user decides: the asset list, the CCA
opt-in, the category, the Navigator name, the intents, and the
`post_create_action` must each be explicitly collected or confirmed.

## Step 1: Collect Assets

Collect **raw hints only**: for each asset, its kind (AVA, botflow, Guide) and
either an id or a name (or part of one). Ask whether to include an AVA; if one
is already in session context (e.g. from `ava-design`/`ava-build`), confirm the
user wants *that* AVA rather than asking from scratch. Then ask for any Guides
or botflows. No descriptions: a free-text description cannot be researched.

Also collect:

- The Navigator base `name` (flow names are derived from it).
- The Customer Intent category `name` (max 80 characters) and `description`
  (80 to 500 characters; the intent classifier rejects a shorter one at publish).
  An id is optional; leave it unset unless you already know it.

Do **not** ask about CCA here; that comes in Step 6, after the intents.

## Step 2: Verify Assets

Dispatch the `ava-navigator-researcher` sub-agent once, batched, with the
hints. Follow [researcher-dispatch.md](references/researcher-dispatch.md): it
resolves each hint, writes a real description, reports whether the asset is
published, and for an AVA also reports its properties' resolved types.

**Hard rule: stop on any not-found, ambiguous or unpublished asset.** Report it
and loop with the user, re-dispatching only the affected asset. Never drop or
guess.

Also check the category name with
`list_resources(resource_type="customer_intent_category", name=<name>, include_details=true)`
and the exact name. `include_details` adds `attributes.intents`, the category's
existing intents as `{id, name, description}`. Informational only: an existing
category is reused by name (its live description is never compared), so tell
the user, and list any intents already in it so Step 4 can build on them
instead of proposing duplicates.

## Step 3: Confirm Verified Assets

Present the resolved list (name, kind, and description) before any proposal
work, and wait for explicit confirmation. If the user wants to add or remove
an asset, loop back to Step 1/2 for just that asset.

## Step 4: Propose Intents

Propose the intents yourself, from the verified descriptions, per
[intent-cca-proposal.md](references/intent-cca-proposal.md). No sub-agent. For
each intent, propose which asset (if any) it routes to, inline on the intent;
an intent with no asset only speaks itself and exits.

## Step 5: Confirm or Edit Intents

The user approves or edits the intents, including each intent's proposed
asset. Loop until **explicit approval**. Every asset must end up with at
least one intent; an intent may be left unassigned (`asset: null`). See
[intent-cca-proposal.md](references/intent-cca-proposal.md) for how to hold
that rule; the server cannot check it.

## Step 6: CCA Configuration

Only now ask whether CCA fields should be captured, and settle everything about
it, per [cca-configuration.md](references/cca-configuration.md): opt in,
which existing schema to use, the Intent Classifier risk warning, which AVA
properties link to which CCA fields, and the `postCreateAction` (bind, and
publish to TestReady or production).

**Warn before previewing.** The Intent Classifier fills any CCA attribute it
thinks the customer's words match, so a customer can set an attribute the
author meant a tool to set (for example "I'm a priority client" setting
`isPriority`). Show this risk and the schema's author-determined-looking
fields to the user during this step, and get an answer for each, per
[cca-configuration.md](references/cca-configuration.md) ("Warn: user input can fill any attribute").
All of it is decided now, before the draft exists. This tool never creates a
CCA schema.

Single AVA only when CCA is involved; the reference explains the limit.

## Step 7: Generate Draft and Preview

Assemble the `NavigatorDraft` from Steps 1-6 and call `preview_navigator`
with an **absolute `draft_file_path` you provide** (it is required), per
[draft-lifecycle.md](references/draft-lifecycle.md). Tell the user where the
HTML preview is, show any `warnings`, and loop on their edits: a changed asset
list goes back to the researcher for just that asset; any other edit is a
direct patch and a re-preview. Repeat until the user explicitly confirms.

## Step 8: Create

Per [draft-lifecycle.md](references/draft-lifecycle.md): get the user's
explicit approval, give the extra production warning if
`postCreateAction` is `bind_and_publish_production`, set the draft file's
`_meta.status` to `"confirmed"`, then call `build_navigator(path)`.

On success, present `botFlowId` and `inboundCallFlowId` (the latter is absent
when the org has no usable text-to-speech voice, in which case a warning says
so and the flow was not created), `categoryId` and `intentIds`, `schemaId`,
`warnings`, each binding's outcome, `boundVersion` and its publish target, and
`phoneNumberAttachmentNote` as the user's next manual step (Admin >
Telephony > DID Numbers / Call Routing). If an AVA was bound, finish by syncing
its local lifecycle files per [cca-ava-binding.md](references/cca-ava-binding.md).

On failure, report exactly what the server returned. If resources were created
before it failed, list every created id, say nothing is rolled back and there
is no resume, and do not retry automatically (a retry duplicates flows).

If the user wants to link a CCA field to the AVA **after** the Navigator is
already built, that is the manual procedure in
[cca-ava-binding.md](references/cca-ava-binding.md).
