# Researcher Dispatch

How `ava-navigator` Steps 2-3 resolve the assets the user names, using the
`ava-navigator-researcher` sub-agent. The researcher reads a lot (an AVA's
full definition, a guide's instruction text) to write a few sentences; that
reading stays in its isolated context and is thrown away. You only keep the
short result.

The researcher is pure resolution and verification. It never proposes
intents or CCA fields and never talks to the user. You are the only thing
that talks to the user.

## Building the dispatch

Send **one batched dispatch** for all assets, not one per asset. Each entry is
a raw hint, exactly one of `id` or `name_contains`, never a free-text
description (that would need open-ended research the researcher is not scoped
for):

```json
{
  "assets": [
    {"kind": "ava", "name_contains": "Billing Assistant"},
    {"kind": "botflow", "name_contains": "Password Reset"},
    {"kind": "guide", "id": "a1b2c3d4-..."}
  ]
}
```

- `kind` is `"ava" | "botflow" | "guide"`.
- An explicit `id` is not a shortcut around verification; the researcher
  verifies it the same way as a name.
- Do not pass `include_details` or any other `list_resources` flag. Deciding
  when the extra enrichment calls are worth it is the researcher's job.
- If an AVA is already in session context (e.g. from an `ava-design` /
  `ava-build` run), confirm with the user that they want that AVA included,
  then dispatch it by `id`.

The researcher returns one JSON array inline, same order as the input, one
entry per asset.

## Reading the results

Each entry is exactly one of:

| Result | Shape | What you do |
| --- | --- | --- |
| Resolved | `{kind, id, name, description, properties?}` | Keep it (see below) |
| Not found | `{kind, hint, result: "not_found", error?}` | Stop on this asset; report to the user |
| Unpublished | `{kind, hint, result: "unpublished", id, name}` | Stop on this asset; report to the user |
| Ambiguous | `{kind, hint, result: "ambiguous", candidates: [{id, name}]}` | Stop on this asset; ask the user to pick |

**Hard rule: never continue past an asset that is not found, ambiguous, or
unpublished.** Do not drop it silently and do not guess between candidates.
Report it and ask. Unpublished assets cannot be routed to; the user either
publishes it first or removes it from the list. The researcher's publish
check is informational, so the user is not stuck debugging a stale draft --
`preview_navigator`'s live checks are the final authority and error the same
way on an unpublished asset regardless.

### Disambiguation loop

1. `not_found`: say what was searched and ask for a corrected name or an `id`.
   If the entry carries an `error`, report that error verbatim; it means the
   lookup itself failed, not that the asset is missing.
2. `unpublished`: tell the user the asset exists but is not published; ask
   them to publish it first or remove it from the list.
3. `ambiguous`: list the candidates by name and ask which one.
4. Re-dispatch **only the affected asset**, with the chosen `id` (or the
   corrected hint). Do not re-dispatch assets that already resolved.
5. Repeat until every asset is resolved and published.

If the user adds or removes an asset later (including at the draft preview in
Step 7), apply the same rule: dispatch just the changed asset, never the whole
list.

## What to keep

For each resolved asset:

- **Goes onto the owning intent's `asset` field, inline:** `kind`, `id`,
  `name`. There is no top-level `assets` list in the draft -- every intent
  carries its own `asset` (see [intent-cca-proposal.md](intent-cca-proposal.md)
  and [draft-lifecycle.md](draft-lifecycle.md)).
- `description` from the researcher is **not** a draft field; it only informs
  your intent proposal in this conversation (Step 4,
  [intent-cca-proposal.md](intent-cca-proposal.md)), then is discarded. The
  server derives its own `version` for ava/guide assets live during
  `preview_navigator` -- never invent or copy a version number into the
  draft yourself.
- **Stays in your session only:** an AVA's `properties`
  (`{name, location, resolved_type}`). Step 6 ([cca-configuration.md](cca-configuration.md))
  uses it to offer binding candidates and to choose exact CCA field types. It
  is not a field on the draft at all; leave it out entirely.
- Nothing else. Do not carry full definitions or instruction text forward.
  The researcher does not detect or report an AVA's existing CCA schema
  bindings at all -- the server is the sole authority on that; see
  [cca-configuration.md](cca-configuration.md).

## Step 3 confirmation

Present the resolved list before any proposal work: name, kind, and the
researcher's description. Wait for explicit confirmation. If the user wants
to add or remove an asset here, loop back to Step 1/2 for just that asset.
Do not ask the CCA schema question yet; that belongs to Step 6, after the
intents are settled.
