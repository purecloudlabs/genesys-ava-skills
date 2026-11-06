# Intent Proposal

Proposal guidance for `ava-navigator` Steps 4-5 (intents). You do this
yourself, in the main conversation: it is cheap in context (a few short
descriptions in, a few structured proposals out) and every proposal is
confirmed or edited with the user, so a sub-agent would only add a round trip.

Everything here is a **proposal**. Never say anything has been created, and
never proceed on implicit approval.

## Customer intents (Steps 4-5)

Work only from each verified asset's `name` and `description` (from the
researcher). Do not fetch fuller definitions.

1. For each asset, infer 1-3 plausible things a caller might say that this
   asset should handle.
2. Write each intent as:
   - `name`: at most 80 characters, unique across the draft (compared
     case-insensitively).
   - `description`: 80 to 500 characters (the intent classifier rejects a shorter
     one at publish). This becomes the draft's own
     description for the intent -- see "A note on descriptions" below.
   - `examplePhrases`: at least 1, aim for 2-4 phrases a real caller would say.
   - `asset`: the resolved asset `{kind, id, name}` this intent routes to,
     inline on the intent, or `null` for an intent that only speaks itself
     and exits (see "Intent to asset coverage" below).
3. **Merge overlaps across assets.** Do not propose two near-identical intents
   because two assets could both handle a similar request; keep one, give it to
   the better-fitting asset, and mention the overlap in its description when it
   is informative.

### A note on descriptions

The category and intent `description` you write here is the Navigator's own
-- it is what gets sent to Architect in both the flow-local description and,
on create, the library's description. When an intent or category you typed
turns out to **already exist** in the Customer Intent library (matched by
name, and by id if you supplied one), `preview_navigator` reuses it without
ever comparing or complaining about its existing library description -- the
two are independent, and the server leaves the live one alone. You do not
need to go look up or match the live wording; just propose the best
description for this Navigator.

### Intent to asset coverage

Each intent's `asset` field (one of the resolved assets, inline, or `null`)
is part of the draft and is sent to `build_navigator`: that field decides
whether the bot flow routes the intent to the asset's call action or speaks
the intent and category literally and exits. Unlike the asset itself, there
is no server-side check that every asset got an intent -- that remains the
skill's job.

At Step 5 show it as a table (intent → asset, or "none") alongside the intent
list, and hold these rules:

- **Every asset must have at least one intent.** An asset with none is
  unreachable. Do not accept approval while any asset has none; propose one or
  ask the user whether to drop the asset.
- **An intent may have no asset (`asset: null`).** The bot flow then speaks
  the intent and category literally instead of calling anything. Offer to
  leave it unassigned for the user to fill in later; this is allowed, but warn
  that an asset with no linked intent is never called (the draft surfaces the
  same warning).

When an edit adds or removes an asset, redo this check.

### Approval

Loop until the user gives **explicit approval** of the intent list. Edits
(add, remove, rename, change description or phrases) are patched directly; they
do not need the researcher. Do not move to Step 6 on an implicit or partial
approval.

## CCA fields

There is no field-proposal step here anymore. `ava-navigator` never creates a
CCA schema or adds fields to one ([cca-configuration.md](cca-configuration.md)):
every CCA field a binding uses must already exist on an existing schema the
user picks. Picking which of that schema's existing fields to bind to which
AVA property is covered in [cca-configuration.md](cca-configuration.md)
section 3, not here.
