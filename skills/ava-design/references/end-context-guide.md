# End Context (Output Data) Authoring Guide

Apply this when collecting Step 7a (End Context). End Context is optional output data the AVA returns to Cicero/Architect at conversation end — the inverse of Start Context (Step 7, which is input).

Each output variable is a property on a single `OutputData` type (`direction: "agentOutput"`, `type: "object"`), and comes from one of two sources.

## Passthrough (no `mapping`)

The value already exists as a named type elsewhere in the design: a Start Context (`InputData`) property, or a tool input/output alias type. Reference that type by name; no `mapping` needed.

```json
{"name": "customer_email", "type": "CustomerEmail"}
```

## Extracted from a tool's output (`mapping` present)

Pull a specific field out of a Data Action tool's output type, including nested objects and array elements. `type` here is the field's bare primitive (`string`, `integer`, `number`, or `boolean` — no other type is supported for mapped properties), and `mapping` is `[ToolOutputTypeName, ...pathSegments]`:

```json
// top-level field: TicketResponse.ticketId
{"name": "ticket_id", "type": "string", "mapping": ["TicketResponse", "ticketId"]}
// nested field: AuthResponse.data.token
{"name": "auth_token", "type": "string", "mapping": ["AuthResponse", "data", "token"]}
// array element field: OrderList[0].id
{"name": "first_order_id", "type": "string", "mapping": ["OrderList", 0, "id"]}
```

The mapping root (`mapping[0]`) must be an existing Data Action tool's `output` type name — not an arbitrary type.

## Real-Time End Context Checks

Apply these the moment an output variable is declared:

- **Check EC1 — property name format** (T9): If a property name contains whitespace or exceeds 200 characters → ❌ Block: "End Context property '[name]' is invalid: [reason]."
- **Check EC2 — mapped property type** (T9): If a mapped property's `type` is not one of `string`/`integer`/`number`/`boolean` → ❌ Block: "End Context mapped property '[name]' type '[type]' is not supported. Use string, integer, number, or boolean."
- **Check EC3 — passthrough property type** (T9): If a non-mapped property's `type` doesn't reference an existing alias, enum, or masked type in `types[]` → ❌ Block: "End Context property '[name]' type '[type]' must reference an existing type."
- **Check EC4 — mapping root is a tool output type** (T9): If a mapped property's `mapping[0]` isn't a Data Action tool's `output` type name → ❌ Block: "End Context property '[name]' mapping root '[root]' must reference a Data Action tool's output type."
- **Check EC5 — no duplicate property names** (T9): If two End Context properties share a name → ❌ Block: "End Context has duplicate property names: [names]. Rename at the source (tool input/output or start context)."
- **Check EC6 — property count** (T9): Warn as the list approaches 50 properties (the platform limit).

See constraint T9 in [design-constraints.md](design-constraints.md) for the full structure and validation rules, verified against the real Sage backend's `AVAOutputVariablesFT` (`AI-1417_output_variables-for_ava`) implementation.

End Context is optional — if not needed, omit the `OutputData` type entirely.
