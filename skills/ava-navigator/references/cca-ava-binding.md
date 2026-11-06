# CCA ↔ AVA Property Binding

This is the validation and execution procedure for binding a Conversation
Custom Attribute (CCA) schema field to a specific AVA `InputData`/
`OutputData` property. It is an **optional** capability — most Navigators
never need it, since `build_navigator` already attaches the CCA schema to
the Architect bot flow (`botFlowSettings.conversationSchemaId`) on its
own. This procedure only applies when the author additionally wants a
*specific AVA property* to read from or write to a *specific CCA field*.

Referenced from [ava-navigator/SKILL.md](../SKILL.md) Steps 6 and 8 and
from [cca-configuration.md](cca-configuration.md) and
[draft-lifecycle.md](draft-lifecycle.md) — this procedure is wholly owned by
`ava-navigator`; it does not depend on or alter `ava-build`.

## Who runs this

- **During a Navigator build — the server runs it.** When the draft's
  `postCreateAction` is not `skip`, `build_navigator` performs exactly the
  validation and execution below itself, using the draft's `ccaBinding`.
  Do **not** repeat it by hand afterward. It is documented here so you (and
  the user) can see what is happening inside the tool, to choose compatible
  types in Step 6, and to explain a block. `preview_navigator` checks the
  parts it can from the draft and the live schema (`date`, field existence,
  and the field's live type -- it fills/overwrites `ccaFieldType` from the
  schema rather than trusting a cached value); `build_navigator` re-checks
  every binding against the AVA's live latest saved version, and a reused
  schema's required fields against the live schema, before creating
  anything.
- **After the Navigator is already published — you run it by hand.** If the
  author later decides to link a CCA field to the AVA, a rebuild would create a
  whole new set of flows, so there is no tool for a bind alone. Follow this
  procedure directly, from "Validation procedure" onward.

A binding request looks like: an AVA id, a CCA schema id, and a list of
mappings, each `{propertyName, direction, ccaId, ccaFieldName,
ccaFieldType}` where `direction` is `"input"` (CCA schema field → AVA
InputData property) or `"output"` (AVA OutputData property → CCA schema
field). `location` is not a field on the binding -- it is derivable from
`direction` (`"input"` → `InputData`, `"output"` → `OutputData`) and the
checks derive it internally rather than trusting a separately-stored value.

## Validation procedure

For every mapping, in order:

1. **Locate the property.** Find `propertyName` on the artifact's
   `InputData` type (for `direction: "input"`) or `OutputData` type (for
   `direction: "output"`). If it doesn't exist → ❌ **Block.** Report:
   "Property '[propertyName]' does not exist on [InputData/OutputData]. Add
   it via [design](../../ava-design/SKILL.md) in update mode before binding
   CCA." Do not create the property here — this procedure only binds
   existing properties.

2. **Reject `date`-typed CCA fields outright.** If `ccaFieldType` is
   `date` → ❌ **Block.** Report: "CCA field '[ccaFieldName]' is type
   'date', which Sage can never read or write. Choose a different field or
   change its type before binding." This is a hard rule, not a warning —
   unlike the non-blocking `date` warning a schema with a `date` field produces, a bind
   attempt against a `date` field must not proceed at all.

3. **Validate type compatibility.** Resolve the property's underlying
   primitive type (follow alias/enum types to their base
   `string`/`integer`/`number`/`boolean`, same resolution `ava-design`/
   pre-flight checks already use). Compare against `ccaFieldType`:
   - Both sides are confirmed-safe types (`string`, `boolean`, `integer`,
     `number`) — these are the only four types a CCA schema field can ever
     be, besides the already-rejected `date`.
   - Exact type match → OK.
   - The **only** allowed mismatch is directional integer/number widening,
     matching Sage's own `_is_safe_widening` rule:
     - `direction: "input"`: OK only if `ccaFieldType == "integer"` and
       the property resolves to `"number"`.
     - `direction: "output"`: OK only if the property resolves to
       `"integer"` and `ccaFieldType == "number"`.
   - Any other mismatch (e.g. `string`↔`integer`, `boolean`↔`string`, or
     `number`→`integer` narrowing in either direction) → ❌ **Block.**
     Report: "Property '[propertyName]' resolves to type '[resolved_type]'
     but CCA field '[ccaFieldName]' is type '[ccaFieldType]' — these are
     not compatible (only integer→number widening is allowed, and only in
     the matching direction)."

4. **Reject schemas with required fields.** If the caller indicates (or
   `list_resources` with `resource_type="cca_schema"` surfaces) that the
   target CCA schema has any required field — not just the one being bound —
   → ❌ **Block.** Report: "Conversation Schema '[schema_name]' has required
   field(s): [list]. Schemas with any required field cannot be bound to an
   AVA property at all." This mirrors Sage's own whole-schema rejection; it
   is not specific to the field being bound.

5. **Enforce direction exclusivity.** `direction: "input"` mappings only
   ever write a `CustomConversationAttributes` target onto an `InputData`
   property, never a `Response` target; `direction: "output"` mappings only
   ever target an `OutputData` property, never a `Request` target. If a
   mapping's `direction` doesn't match where `propertyName` actually lives
   (e.g. `direction: "output"` naming an `InputData` property), → ❌
   **Block.** Report: "Property '[propertyName]' is declared on
   [InputData/OutputData], which doesn't match the requested direction
   '[direction]'."

6. **On pass:** set the property's `targets` field in the design artifact
   to:
   ```json
   [{"type": "Request"}, {"type": "CustomConversationAttributes", "target": {"id": "<schema_id>", "name": "<ccaFieldName>"}}]
   ```
   Keep the property's bot-flow target alongside it: `{"type": "Request"}` on
   `InputData`, `{"type": "Response"}` on `OutputData` (a property with no
   `targets` has it implicitly). Writing the CCA target alone removes it, and
   publish then fails with "has had its bot-flow target removed". Replace any
   earlier CCA target; a property can only be bound to one CCA field at a time.

## Outcome

**On any ❌ Block:** Stop and report all violations for this mapping; do not
proceed to execution until resolved. Blocks here are deterministic — don't
retry the same mapping unchanged.

**On full pass, execute the binding directly** (steps 1-5 are what
`build_navigator` does for you; run them yourself only on the late-bind path):

1. Call `get_latest_saved_version` with the AVA's id to load its current
   `VersionDefinition`. If there is no saved version yet, stop and report
   that the AVA needs a version from [ava-build](../../ava-build/SKILL.md)
   before a CCA field can be bound to it.
2. In that definition, set the matching property's `targets` field (on
   `InputData` or `OutputData`, per each mapping's `direction`) to:
   ```json
   [{"type": "Request"}, {"type": "CustomConversationAttributes", "target": {"id": "<schema_id>", "name": "<ccaFieldName>"}}]
   ```
   Keep the property's bot-flow target alongside it: `{"type": "Request"}` on
   `InputData`, `{"type": "Response"}` on `OutputData` (a property with no
   `targets` has it implicitly). Writing the CCA target alone removes it, and
   publish then fails with "has had its bot-flow target removed". Replace any
   earlier CCA target; a property can only be bound to one CCA field at a time. Apply this for every mapping
   that passed validation before moving on.
3. Call `create_version` with the AVA's id and the mutated `definition`. This
   mints a new version — Sage versions are immutable, so binding always
   produces a new version number.
4. Call `publish_version` with the AVA's id, the new version, and
   `test_only: true` by default — same TestReady-first policy
   [ava-build](../../ava-build/SKILL.md) uses. Only publish
   `test_only: false` (production) if the author explicitly asks to promote,
   and confirm with them first using the same production-publish warning
   `ava-build`'s Step 4 uses: this locks the version contract and routes
   live Botflow traffic to it.
5. Report the result: new version number, publish status, and which
   properties are now bound to which CCA fields. On a publish `Failed`,
   surface the `errors` array verbatim (field-level detail) rather than
   retrying blindly — same deterministic-vs-transient rule `ava-build` Step 4
   documents (4xx = fix and retry; `Timeout`/5xx = safe to retry as-is).
6. **Applies to both paths** (the server does not do this one). If this AVA
   also has an `.ava-lifecycle/<slug>/` local session (a prior
   `ava-design`/`ava-build` run for it), update
   `.ava-lifecycle/<slug>/design-artifact.json`'s matching property with the
   same `targets`, and update `sage-agent.json`'s `version` field, so the
   next `ava-build` run doesn't operate on stale local state. If no local
   session exists for this AVA (e.g. it was only ever verified via
   `list_resources`, never designed/built in this workspace), skip this —
   there's no local artifact to keep in sync.

