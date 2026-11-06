# CCA Configuration

Step 6 of `ava-navigator`. It runs **after** intents are settled, not before,
and decides everything about Conversation Custom Attributes (CCA): whether to
capture any, which existing schema, which AVA properties link to which
fields, and what happens to the AVA when the Navigator is built. Its output
is three parts of the draft: `cca`, `ccaBinding`, and `postCreateAction`.

**This tool never creates a CCA schema.** A Conversation Custom Attributes
schema can never be deleted once created, not even by an admin, so creating
one from an agent-driven tool is too risky. The draft's `cca` entry always
references an **existing** schema by `id`; there is no "new schema" path at
all. If the user needs a schema that does not exist yet, tell them to create
it themselves in Genesys Cloud Admin / Resource Center (Admin > Conversation
Custom Attributes), then come back and re-run this step once it exists.

> **Known limitation (open question #26): single AVA only.**
> This file is written for a Navigator with **at most one AVA** whenever CCA
> is involved. The Navigator's bot flow carries one `conversationSchemaId`,
> and the draft has one `postCreateAction`, so with several AVAs it is
> undecided how existing links, bindings and publish targets should combine.
> `preview_navigator` and `build_navigator` reject more than one `kind: "ava"`
> asset when `cca` is non-empty or `ccaBinding` is non-empty.
> **Revisit this file once #26 is resolved**: the existing-schema discovery,
> the binding collection and the single `postCreateAction` below all assume
> one AVA.

## 1. Opt in

Ask whether the user wants CCA fields captured during the conversation. Never
default it.

- **No:** leave `cca` and `ccaBinding` empty, `postCreateAction = "skip"`.
  Step 6 is done.
- **Yes:** continue.

If more than one asset is `kind: "ava"`, say so now instead of waiting for
`preview_navigator` to reject it: "Multiple AVAs together with CCA isn't
supported yet." Offer to continue without CCA, or to go back to Step 1/2 and
keep one AVA.

## 2. Pick an existing schema

Find candidates with `list_resources(resource_type="cca_schema", fetch_all=true)`
and match client-side (there is no server-side name/id lookup). Each item
carries `attributes.fields` (`[{name, type}]`), `attributes.requiredFields`,
and `attributes.enabled`.

Ask the user which existing schema this Navigator should use; there is no
researcher-provided hint about an AVA's existing CCA links to react to here
(the researcher does not detect or report them -- see
[researcher-dispatch.md](researcher-dispatch.md)). If the user mentions the
AVA is already bound to a schema, that is useful context to factor into the
choice, but nothing in this flow discovers it automatically.

- If it cannot be found, or is not `enabled`, say so and ask the user to pick
  another.
- **Required fields:** if `requiredFields` is non-empty, no field of this
  schema can be bound to an AVA property at all (the whole schema is
  rejected, not just the required field). If binding is wanted, tell the user
  now and offer: skip binding, or pick a different schema.
- **No new fields.** This tool never creates a schema and never adds fields to
  one. Every CCA field the user wants must already be in `attributes.fields`.
  Do not propose field names that are not there.

Draft: `cca = [{"id": schema_id}]`. Leave `name`, `version` and `fields`
unset -- `preview_navigator` fills them from the live schema (and errors if
the id does not resolve or the title you expected does not match).

## 3. Warn: user input can fill any attribute

Do this for **every** schema the user picks, binding or not. `build_navigator`
attaches the schema to the Navigator's bot flow either way, and the risk
comes from that attachment, not from any AVA binding.

**What happens.** When the Navigator's Intent Classifier (IC) runs from Agentic
"Ask for Intent" and "Anything else", it writes to **any** CCA attribute it
believes matches what the customer said, judging only from the attribute's
name and description in the schema. This is useful: "I'm calling about my
flight booking, reference ABC123" fills `referenceNumber`, so the execution
surface does not ask again.

**The risk.** Nothing stops customer input from writing to an attribute the
author meant a tool or data action to set. "I'm a priority client" can set
`isPriority` to `true` and bypass the author's own determination logic. The
same applies to a flag like `isAuthenticated`. The schema is shared with the
execution surfaces, so a value the customer talked their way into is read
downstream as if the author's logic had produced it.

**What to do.**

1. List the chosen schema's fields (`attributes.fields` from
   `list_resources`). Flag every field whose name or type suggests the author,
   a tool or a data action should decide it rather than the customer: status,
   tier or priority flags, `is*`/`has*` booleans, authentication or
   verification results, eligibility, entitlement, risk or fraud scores,
   amounts or limits. Use judgement; this is a flag list, not proof.
   `list_resources` returns names and types only, so also tell the user to
   read each flagged field's **description** in Admin > Conversation Custom
   Attributes: the description is what the IC matches on.
2. Show the user the risk in the words above and the flagged fields, **before**
   calling `preview_navigator`. If nothing is flagged, still show the
   short risk statement, once.
3. Ask how to handle each flagged field. Offer these; the fix always happens
   outside this tool, because it never edits a schema:
   - **Accept:** the customer stating the value is fine for this field.
   - **Reword the description** so it says the field is only to be set from
     what the customer explicitly states (and never from claims about status
     or entitlement).
   - **Use a different schema** that holds only customer-supplied
     attributes, and keep author-determined flags in another one.
   - **Make the author's own logic authoritative:** have the tool or data
     action that owns the field set it again after intent capture, so a
     value from the IC never survives unchecked.
4. Record the decision with the other CCA decisions, and repeat the
   one-line risk plus flagged fields when presenting the preview, so it is
   visible alongside the draft. Never silently proceed past a
   flagged field the user has not answered.

This risk is not caught by any check in `preview_navigator` or
`build_navigator`; they cannot see who is meant to set an attribute.

## 4. Binding intent (AVA only)

Skip when there is no AVA. Otherwise ask, once, up front: "Will any of these
CCA fields need to read from or write to a specific input or output variable on
'[AVA name]'?"

Use the AVA's `properties` from the researcher ([researcher-dispatch.md](researcher-dispatch.md))
as the candidate list: `InputData` properties are candidates for a CCA field
feeding **into** the AVA; `OutputData` properties are candidates for the AVA
writing **out to** a field. Never infer a pairing from names alone; it is a
business mapping the user must confirm.

For each confirmed pairing record (this becomes one entry under
`ccaBinding[<ava-id>]`):

| Binding field | Value |
| --- | --- |
| `propertyName` | the property's `name` |
| `direction` | `"input"` (CCA → InputData) or `"output"` (OutputData → CCA) |
| `ccaId` | the single `cca` entry's `id` |
| `ccaFieldName` | the field it links to (must already exist on the chosen schema) |
| `ccaFieldType` | optional to supply; `preview_navigator` fills/overwrites it from the live schema field's type regardless |

Rules to check **before** accepting a pairing, so the user hears about it now
and not as a 400 from `preview_navigator` (the full rule text and error
wording is in [cca-ava-binding.md](cca-ava-binding.md)):

- `date` CCA fields can never bind; ask for a different field.
- A property with `resolved_type: "other"` cannot bind.
- Types must match exactly, except directional widening: `input` allows a CCA
  `integer` into a property that resolves to `number`; `output` allows a
  property resolving to `integer` into a CCA `number`. Nothing else.
- A property binds to one CCA field at a time. The researcher does not
  report whether a property already carries a CCA target; if one does, a
  new binding at build time **overwrites** it silently -- say so if the
  user mentions an existing link.
- The field must already exist on the chosen schema with a compatible type;
  if none does, tell the user that binding needs a field added to that schema
  outside this tool (Admin / Resource Center), then re-run this step.

Show the resolved types back to the user before moving on ("'account_id'
resolves to `string`, input → CCA field `accountId`"), so they see them now
rather than at build time.

## 5. `postCreateAction`

Only asked when there is at least one binding; with none, it is `"skip"`.
This is decided now, before the draft exists, and is never re-asked at
preview or build time.

| Value | What `build_navigator` does to the AVA |
| --- | --- |
| `bind_and_publish_test` | Sets the targets, mints a new AVA version, publishes it **TestReady**. Recommended default. |
| `bind_only` | Sets the targets and mints a new version; does not publish it. |
| `bind_and_publish_production` | Same, but publishes to **production**: locks the version contract and routes live Botflow traffic to it. |
| `skip` | Touches nothing on the AVA. |

Recommend `bind_and_publish_test`. Choosing `bind_and_publish_production`
here is a real decision, but it is confirmed again at Step 8 (see
[draft-lifecycle.md](draft-lifecycle.md)).

Sage versions are immutable: any bind mints a **new** AVA version; the
existing one is never modified.

## 6. Result

You now hold `cca` (zero or one entry), `ccaBinding` (possibly empty), and
`postCreateAction`. Carry them into the draft
([draft-lifecycle.md](draft-lifecycle.md)).

`preview_navigator` re-checks all of this against the live schema and the
AVA's live definition (and does a local structure check of the generated flow
documents) and returns every violation in one 400; if it does, fix the draft
and call it again rather than working around it.
