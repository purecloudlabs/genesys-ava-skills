# Draft Lifecycle

Steps 7-8 of `ava-navigator`: assemble the `NavigatorDraft`, preview it, loop
on edits, then confirm and build. The draft is one JSON file that holds every
decision made in Steps 1-6, so it can be re-edited, rebuilt and inspected
later without asking the user anything again.

Two tools, both on the AVA MCP server:

- `preview_navigator(draft, draft_file_path)`: validates, writes the file,
  renders an HTML preview. Validation is the draft's offline business and
  taxonomy rules, a **local structure check** of the two Architect flow
  documents the build would generate (built from the draft with placeholder
  ids -- this catches malformed documents, not Architect's verdict; only a
  real save and publish shows whether Architect accepts a document), and a
  set of **live Genesys Cloud checks** -- see "What the live checks do" below.
- `build_navigator(path)`: reads the file back, re-runs every one of those
  same checks (fail fast, before creating anything), and performs the real
  build: each flow is saved as an Architect v2.0 flow document inside a
  checkout, check-in and publish sequence.

## The draft file

**`draft_file_path` is required and you must provide it.** Always an absolute
path to your workspace:

```
<workspace>/.ava-lifecycle/<navigator-slug>/<version>.json
```

- `<navigator-slug>`: the Navigator `name` lowercased, runs of
  non-alphanumeric characters replaced by a single hyphen, trimmed
  ("Acme Order Assistant!" → `acme-order-assistant`). Same rule `ava-design`
  uses.
- `<version>`: the **last published version + 1**, starting at `1`. List the
  slug directory, read each `<n>.json`'s `_meta.status`, take the highest `n`
  that is `"published"`, add one. If that file already exists as a `draft` or
  `confirmed` file you are still iterating on, reuse it.
- Use the **same path for every preview** of the same round. The server
  overwrites the file in place while its status is `draft`. It never
  overwrites a `published` file (400); a published file is kept as a
  historical record, and further changes go to the next version number.

## Assembling the draft

Everything comes from Steps 1-6. Keys may be snake_case or camelCase (shown
below in camelCase, matching what the server writes back).

```json
{
  "name": "Acme Order Assistant",
  "postCreateAction": "bind_and_publish_test",
  "customerIntents": [
    {
      "name": "Customer Support Intents",
      "description": "Intents for order and billing support.",
      "id": null,
      "intents": [
        {
          "name": "Check Order Status",
          "description": "Caller wants the status of an order.",
          "examplePhrases": ["where is my order"],
          "id": null,
          "asset": {"kind": "ava", "id": "<ava-id>", "name": "Billing Assistant", "version": "3.0"}
        },
        {
          "name": "Store Hours",
          "description": "Caller asks when the store is open.",
          "examplePhrases": ["when are you open"],
          "asset": null
        }
      ]
    }
  ],
  "cca": [
    {"id": "<schema-id>", "name": "OrderContext", "version": "2",
     "fields": [{"name": "accountId", "type": "string"}]}
  ],
  "ccaBinding": {
    "<ava-id>": [
      {"propertyName": "account_id", "direction": "input", "ccaId": "<schema-id>",
       "ccaFieldName": "accountId", "ccaFieldType": "string"}
    ]
  },
  "_meta": {"status": "draft", "version": 1, "generatedAt": "...", "flowIds": null}
}
```

- `customerIntents` is a list but **only one category is supported today**; a
  draft with zero or more than one is a validation error.
- Each intent carries its **own** `asset` inline (`kind`, `id`, `name`; preview
  fills `version`). `asset: null` means the intent only speaks itself and the
  category, then exits.
- `cca` is a list of **zero or one** schema reference. **This tool never
  creates a CCA schema** -- see [cca-configuration.md](cca-configuration.md).
  A `cca` entry always references an existing schema by `id`.
- `ccaBinding` is a map of asset id -> list of bindings
  (`propertyName, direction, ccaId, ccaFieldName, ccaFieldType`). Every key
  must be the id of an `ava`-kind asset that appears on some intent; every
  `ccaId` must equal the single `cca` entry's `id`.
- Ids are **optional** on the category and on each intent. Supply one only
  when you already know it (e.g. re-editing a previously built Navigator);
  otherwise leave it `null` and let the checks fill it in (see next section).
- Do not set `_meta`; the server sets `status`, `version`, `generatedAt` and
  clears `flowIds` on every preview.

## What the live checks do

Both tools run the same function
(`navigator_preview_checks.check_navigator_draft`) against the live org,
after the offline/document checks pass. It fills in derived fields and
collects every violation into one error, so you fix everything in one pass
rather than one 400 at a time.

**A category/intent description is the Navigator's own -- never an identity
claim.** The draft's single `description` for the category and for each
intent is what this Navigator uses; it is written into both the flow's
local `description` and the library `source.description` on create. When an
existing library category or intent is **reused**, matching happens by
**name (and id, when given) only** -- the live library object's own
description is never read for comparison, never reported as a mismatch, and
never overwritten. A reused category or intent keeping a different library
description than what you typed is expected, not a bug: tell the user if it
seems surprising, but it is not an error or a warning.

| Check | Rule | Result |
|---|---|---|
| Category by id | must exist; `name` must match (description is never checked) | error |
| Category without id | found by name -> id filled in; not found -> will be created on build | fill |
| Intent by id | its category must exist; the intent must exist in it; `name` must match (description is never checked) | error |
| Intent without id | found by name inside the matched category -> id filled in; not found -> will be created | fill |
| Upstream-only intent | exists in the live category but not in the draft | warning |
| AVA / guide asset | must exist (404 -> error); `name` must match; must have a `latestProductionReadyVersion` (a `TestReady`-only version is an error, no `latestSavedVersion` fallback); `version` is filled/overwritten | error / overwrite, warn only if a previously-set version changed |
| Bot flow asset | must exist; `name` must match; `type` must be `BOT` (`DIGITALBOT`/other is an error); must have a `publishedVersion` | error |
| Same asset id on several intents | all occurrences must agree on `kind`/`name`/`version` (checked offline); the asset is fetched once and the live result applied to every occurrence | error |
| `cca[0]` schema | must exist by id; `name` must match the schema's title; `version` and `fields` are filled/overwritten from the live schema; a schema with any required field plus a non-empty `ccaBinding` is an error | error / overwrite |
| `ccaBinding` entry | `ccaFieldName` must exist on the live schema; `ccaFieldType` is filled/overwritten from the live field's type (warn only if a previously-set type changed); the type must be bindable | error / overwrite |
| Binding vs AVA definition | validated against the AVA's latest saved version via the CCA-AVA binding pre-flight ([cca-ava-binding.md](cca-ava-binding.md)), only when `postCreateAction != "skip"` and no earlier error exists | error |

Every error from every check above is collected into one message; a
non-404 transport failure (5xx, timeout) is not a draft error and surfaces
as a server error instead. Separately, both tools read the org's live
text-to-speech catalogue (read-only) to warn when the inbound call flow
would have no usable voice and so would be skipped at build.

**Only `preview_navigator` writes `draftPath`/`htmlPath`/`version` back to a
file; `build_navigator` re-reads the confirmed file, re-runs every check
above, and -- once creation succeeds -- writes the created/reused ids back
into the same file** (see "Step 8" below). Fields the checks filled or
overwrote (ids, versions, schema fields, binding types) are exactly what
gets persisted; you never need to look them up again by hand.

## Preview and the edit loop

Call `preview_navigator` with `{draft, draft_file_path}`. On success it
returns `draftPath`, `htmlPath`, `version` and `warnings`. Tell the user where
the HTML preview is and show any `warnings`. **Do not read the files back
into context**; the user opens the HTML themselves.

You do not need to ask for confirmation before offering edits; the point of
the preview is that the user reviews it and tells you what to change. For each
change, route it like this:

| Change | What you do |
| --- | --- |
| Add or remove an asset | Research only that asset ([researcher-dispatch.md](researcher-dispatch.md)); update the owning intent's `asset`; **prune or flag any `ccaBinding` entries that referenced a removed AVA**; redo the intent coverage check; call `preview_navigator` again |
| Anything else (rename an intent, edit a field, change a binding or the post-create action) | Patch your in-memory draft directly; call `preview_navigator` again; no sub-agent |

Binding changes still follow the rules in
[cca-configuration.md](cca-configuration.md); a `postCreateAction` change to
production is a Step 8 matter.

### When preview fails

- **400:** the message lists *every* violation found by the offline rules,
  the document self-check, and the live checks above (duplicate names,
  dangling binding, type mismatch, required-field schema, more than one AVA
  with CCA, a live name mismatch, a missing asset/schema, and so on). Fix the
  draft, don't work around it, call again.
  A message starting "Navigator flow documents are invalid" means the local
  structure check of the generated flow documents failed (nothing was
  written). Fix the draft if the message points at it; otherwise it is a
  server-side defect, so report it to the user rather than retrying.
  "already published" means you pointed at a published file; use the next
  version number.
- **422:** the draft is missing a required field or has a wrong shape.

## Step 8: confirm and build

1. **Explicit approval.** Wait for the user to say, after seeing the preview,
   that it is right. The preview alone is never approval.
2. **Production gate.** If `postCreateAction` is
   `bind_and_publish_production`, stop and warn before anything else:
   "Building will publish a new version of '[AVA name]' to **production**.
   That locks the version contract and routes live Botflow traffic to it."
   Require a separate, explicit yes. The server does not ask again; this is
   the only gate. For the other three actions the draft approval is enough.
3. **Confirm the file.** Edit the single `status` field inside `_meta` in the
   draft file from `"draft"` to `"confirmed"` with your file-edit tool. Change
   nothing else, and never do this earlier than this step or as part of
   rendering a preview.
4. **Call `build_navigator(path)`** with the same absolute path. It rejects a
   file that is not `confirmed`.

`build_navigator` re-reads the file, re-runs the offline rules, the document
self-check, and every live check in "What the live checks do" above (fail
fast, before anything is created). It then creates the taxonomy (category and
any intents missing an id) and reuses the rest by the id the checks already
verified live, builds the two flows in order -- the Navigator bot flow, then
the inbound call flow that calls it (each saved as a v2.0 flow document, then
checked in and published) -- and runs the `postCreateAction` against the
existing `cca` schema referenced by id; the bind procedure it follows is
described in [cca-ava-binding.md](cca-ava-binding.md). On success it sets the
file's `_meta.status` to `"published"`, fills `_meta.flowIds`, and writes back
every id the taxonomy step created or reused (`category.id`, each
`intent.id`) plus every derived field the checks filled (asset `version`,
`cca[0].version`/`fields`, binding `ccaFieldType`).

### Reporting success

Present: the flow ids (`botFlowId`, `inboundCallFlowId`; the latter is absent
when the org has no text-to-speech voice an inbound call flow can use, in
which case a warning says so and the flow is not created), `categoryId` and
`intentIds`, `schemaId` if CCA was used, any `warnings`, and per binding its
`status` (`bound` or `skipped`). If the
AVA was bound, give `boundVersion` and whether it went to TestReady
(`publishedTestOnly: true`) or production (`false`); `null` means minted but
not published. Frame `phoneNumberAttachmentNote` as the user's next manual
step; this skill never attaches a phone number. If an AVA was bound and it has
a local `.ava-lifecycle/<ava-slug>/` session, sync it as the last step of
[cca-ava-binding.md](cca-ava-binding.md).

### Reporting failure

- **Nothing created** (the error is a plain message; it fails before anything
  is built): the file is still `confirmed`. Tell the user what to fix; after the
  fix, call `preview_navigator` again, which resets the file to `draft`, and go
  through Step 8 again.
- **Failed after creating things** (the error has `detail.created` listing ids
  such as `category_id`, `bot_flow_id`, `bound_versions`): report the
  failure and **every created id**, and say plainly that **nothing is rolled
  back and there is no resume**. Do not retry automatically. A retry reuses the
  taxonomy and schema by id and creates fresh flow shells for everything past
  the reused part, leaving the earlier flows as duplicates. Let the user decide
  (clean up, or retry knowing that). The file stays `confirmed`.

## After a publish

The published file stays as it is. Changes to an already-published Navigator
start a new version file (last published + 1): copy the published draft, make
the edits, and preview it. Be honest that `build_navigator` builds a **new set
of flows** every time; it does not update the earlier ones in place.
