# 10 Conditional output instructions

`outputInstructions[]` controls what the agent does **after** a tool returns. Each entry is a `{ when, then }` pair:

- `when` — the condition under which the entry applies.
- `then` — the natural-language instruction the agent follows when the condition holds (max 4000 characters).

A tool may carry at most **5** output instructions.

`when` is a real condition, not a placeholder. Authoring it as a genuine condition — instead of writing `"True"` and describing the branches in prose — is the single highest-leverage improvement available on most tool definitions. See **Anti-pattern: branching in `then`** below.

Two condition shapes exist. They are discriminated by a `type` field on the instruction:

| Shape | `type` | Available on |
| --- | --- | --- |
| **Python** — a boolean expression | `"Python"` (default when `type` is omitted) | All tool types |
| **Structured** — a query-builder rule tree | `"Structured"` | `DataAction` **only** |

`type` may be omitted; it defaults to `"Python"`, so older definitions that predate the discriminator keep working unchanged.

---

## Python conditions on DataAction tools

`when` is a **bare Python boolean expression** evaluated against the tool's return value, which is bound to the variable `result`. Max 5000 characters.

```json
{
  "type": "DataAction",
  "name": "cancel_reservation",
  "output": "CancellationReceipt",
  "outputInstructions": [
    {
      "when": "result.refundedCents > 0",
      "then": "Confirm the cancellation, then state the refund amount and that it returns to the original payment method within 5 business days."
    },
    {
      "when": "result.refundedCents == 0",
      "then": "Confirm the cancellation and explain that this booking fell outside the refund window, so no refund applies."
    }
  ]
}
```

Two entries, two mutually exclusive conditions, each `then` saying only what is true in that branch. Compare this with a single always-on entry whose `then` says "if there was a refund… otherwise…" — the model then has to re-derive the branch it is already in, and will sometimes narrate the wrong one.

### What `when` can reference

Only `result`, plus this builtin whitelist:

`len` · `min` · `max` · `abs` · `int` · `float` · `str` · `bool` · `all` · `any` · `round` · `sum` · `Decimal` · `isinstance`

Any other identifier is rejected at publish with *"expression references unknown variable(s)"*.

Notably `when` **cannot** see:

| Not available in `when` | Where it belongs instead |
| --- | --- |
| The tool's own input parameters | `then` interpolates them by name (`{reservation_id}`); conditions on inputs belong in `inputValidation[]` |
| Session language | `then` prose — see **06** |
| Voice vs digital channel | Separate definitions per channel — see **05** |
| Earlier turns / conversation history | The type graph — see **03** |

### `"True"` means always-on

`when: "True"` is the always-on case and the one value that bypasses expression validation entirely. It is correct whenever the instruction genuinely applies to every successful call — a verbatim response template, a mandatory disclaimer, a fixed delivery style. Use it deliberately, not as a default.

### Publish-time validation

For a `DataAction` tool with a declared `output` type, a non-`"True"` expression is checked against a synthetic instance of that output type. Expressions that would fail at runtime are rejected at publish, so these are authoring errors to fix, not warnings to ignore:

| Rejected | Why | Fix |
| --- | --- | --- |
| `result.status` | Must evaluate to a boolean, not a truthy value | `result.status == "cancelled"` |
| `lambda result: result.total > 0` | Bare expression expected, not a lambda | `result.total > 0` |
| `result.items[int(0)].id` · `result.items[2 + 3]` | Subscripts must be integer literals | `result.items[0].id` · `result.items[5]` |
| `result.note.strip() != ""` where `note` is optional | Optional field may be `None` at runtime | `result.note is not None and result.note.strip() != ""` |
| `len(result.steps) > 0 and result.steps[3].title != ""` | Length guard must cover the index actually used, not just non-emptiness | `len(result.steps) > 3 and result.steps[3].title != ""` |
| `result.items[150]` | Index exceeds the maximum of 99 | Use a small index, or test the array as a whole |

The null-safety and array-bounds checks only replay paths the expression actually reads, so unrelated optional fields elsewhere on the output type cost nothing.

> **Note:** this deep validation needs a declared `output` type on the tool. A `DataAction` tool with no `output` still has its `when` syntax- and name-checked, but nothing can be verified about the shape of `result`.

---

## Python conditions on Knowledge tools

`KnowledgeBase` and `KnowledgeSetting` tools follow a **different and stricter convention**, and getting it wrong fails silently rather than at publish.

These tools return the generated answer as a string, and the platform recognises exactly two condition strings, matched **verbatim**:

| `when` (exact string) | Slot |
| --- | --- |
| `"lambda result: len(result) == 0"` | **No-result** — the lookup found nothing |
| `"lambda result: len(result) > 0"` | **With-result** — the lookup returned an answer |

```json
{
  "name": "Search Product FAQ",
  "type": "KnowledgeBase",
  "targetId": "<kb-uuid>",
  "targetName": "product-faq",
  "outputInstructions": [
    {
      "when": "lambda result: len(result) > 0",
      "then": "Answer using only the retrieved content. Keep the reply concise and ask whether it resolved the issue."
    },
    {
      "when": "lambda result: len(result) == 0",
      "then": "Apologize that you could not find an answer and offer to transfer to a specialist."
    }
  ]
}
```

Three things to know:

1. **These are lambda strings, not bare expressions.** Knowledge tools are the one place the `lambda result:` prefix is required — on `DataAction` tools the same string is rejected. Do not "fix" a Knowledge condition into a bare expression.
2. **The platform wraps `then` in a slot-specific template** when the condition matches one of the two strings exactly. Any other condition — including `"True"` — is passed through as a plain instruction with no wrapping, so the entry loses its no-result / with-result framing.
3. **Both slots have platform defaults.** Omit `outputInstructions[]` entirely and the platform supplies both. Author an entry only to override the default wording for that slot.

Entry order does not matter; the slot is selected by the condition string, not by position. Do not author more than the two slots — the UI and platform model expose no others.

`Structured` conditions are rejected outright on `KnowledgeBase`, `KnowledgeSetting`, and `ExternalA2AServer` tools. Those tool types are Python-only.

---

## Structured conditions

A `Structured` condition replaces the Python expression with a rule tree — useful when a condition should be author-editable in the query builder rather than hand-written. **`DataAction` tools only**, and the tool must declare an `output` type.

`when` is a group: a logical combinator plus rules, where each rule is `{ mapping, operator, value }`.

```json
{
  "type": "Structured",
  "when": {
    "group": "And",
    "rules": [
      { "mapping": ["CancellationReceipt", "refundedCents"], "operator": "GreaterThan", "value": 0 },
      { "mapping": ["CancellationReceipt", "confirmationNumber"], "operator": "IsNotNull" }
    ]
  },
  "then": "Confirm the cancellation, state the refund amount, and read back the confirmation number."
}
```

- `mapping[0]` **must** be the tool's declared output type name; later elements are field names or integer array indices — e.g. `["KBSteps", "steps", 0, "title"]`.
- `group` is `"And"` or `"Or"`. Groups nest up to **5** deep, with 1–20 rules each.
- Rules and nested groups may be mixed freely in one `rules` array.

### Operators by field type

| Field type | Allowed operators |
| --- | --- |
| `string` | `IsNull` `IsNotNull` `Equal` `NotEqual` `In` `NotIn` `Contains` `DoesntContain` `BeginsWith` `EndsWith` |
| `integer`, `number` | `IsNull` `IsNotNull` `Equal` `NotEqual` `LessThan` `LessThanOrEqual` `GreaterThan` `GreaterThanOrEqual` |
| `boolean` | `IsNull` `IsNotNull` `Equal` `NotEqual` |
| `array` | `IsNull` `IsNotNull` `IsEmpty` `IsNotEmpty` |
| `object` | `IsNull` `IsNotNull` |

`value` is required for every operator except `IsNull`, `IsNotNull`, `IsEmpty`, and `IsNotEmpty` — omitting it elsewhere fails publish with *"operator … requires a value"*. On those four, a supplied `value` is ignored rather than rejected, so a leftover value is not an error but is a sign the rule was edited from a different operator and is worth flagging on review. Using an operator outside its type's row fails publish with the valid list in the error.

### Structured edge cases

- **Arrays can only be tested for emptiness.** `IsEmpty` / `IsNotEmpty` are the only length operators, and `IsNotEmpty` guarantees only `len > 0`. A rule may therefore safely index element `0` but not element `1` or beyond — indexing deeper fails the array-bounds check with no operator available to guard it. Reach for a Python condition when you need `len(...) > 3`.
- **`value` is a single scalar, never a list.** `In` / `NotIn` against a string value compile to a substring test (`result.code in 'ABC'`), not set membership. For a genuine one-of-several check, use an `Or` group of `Equal` rules.
- **`Contains` reads value-in-field**, i.e. "does this string field contain this value".
- **Array-typed output:** when the output type is itself `"type": "array"`, the platform inserts the synthetic `items` hop automatically, so author `["KBSteps", 0, "title"]` and it resolves to `result.items[0].title`.

A `Structured` condition is compiled into the equivalent Python expression at publish and then run through the **same** semantic, null-safety, and array-bounds checks as a hand-written Python condition — so the rejection table in the DataAction section applies equally here.

---

## Anti-pattern: branching in `then`

The most common defect in existing definitions. An always-on `when` paired with a `then` that describes several branches:

```json
{
  "when": "True",
  "then": "If no results were found, apologize and offer to transfer to a specialist. If results were found, walk the customer through the steps one at a time."
}
```

This instruction fires on **every** call. The model receives both branches every time and has to decide which applies — which is exactly the reasoning the condition exists to remove. It also blocks the platform from suppressing an instruction that does not apply.

Split it into one entry per branch, each `then` stating only what is true in that branch — the same shape as the `cancel_reservation` example above.

Two exceptions where prose branching in `then` is still correct, because the discriminator is not present in `result` at all:

- **Session language** — no language variable exists in `when`. Keep `"When the session language is es-MX: …"` in the `then` text. See **06**.
- **Voice vs digital** — no modality signal exists at all. Publish a separate definition per channel rather than branching either way. See **05**.

---

## Review checklist

- Every `when` that is not `"True"` is a bare boolean expression over `result` — no lambda (except the two Knowledge slot strings), no bare truthy field, no identifier other than `result` and the builtin whitelist.
- `when: "True"` is a deliberate always-on choice, not a stand-in for a condition described in `then`.
- No `then` contains "if … otherwise …" branching over the tool result — that belongs in two conditions.
- Optional fields referenced in `when` carry an explicit `is not None` guard.
- Array indices in `when` carry a length guard covering the actual index used, not just `> 0`.
- `Structured` appears only on `DataAction` tools that declare an `output`; Knowledge and A2A tools use Python conditions only.
- Knowledge tools use the two exact slot strings (`lambda result: len(result) == 0` / `> 0`), at most two entries, or omit `outputInstructions[]` to accept the platform defaults.
- `Structured` rules index arrays at element `0` only; deeper indexing needs a Python condition.
- Pre-call guidance stays in `inputInstructions[]`; hard gates stay in `inputValidation[]`. See **09d**.
