# 4 Integrating knowledge bases

Give the model clear guidance on when to call the knowledge base (KB) tool and when not to. Minimize post-processing work — ideally the KB tool returns results shaped the way the agent should present them. Also tell the model how to present results to the user, whether that means walking through steps one at a time or branching behavior on empty vs. non-empty results.

**Content must exist before attach.** Native `KnowledgeBase` / `KnowledgeSetting` tools only reference existing org resources. To author and upload Fabric **FileUpload** Markdown cards (and ensure a Knowledge Setting), use [ava-knowledge](../../ava-knowledge/SKILL.md) first — then attach the setting UUID here. Do not upload mid-publish from `ava-build`.

A KB lookup can be expressed in a VersionDefinition in two complementary ways:

- A `KnowledgeBaseTool` (or `KnowledgeSettingTool`) when you want the platform's built-in question-answering shape: a fixed `query: KnowledgeBaseQuery` parameter and a generated string answer (`GeneratedKnowledgeAnswer`).
- A `DataActionTool` when you want a custom input (e.g. a typed `CustomerIssue` instead of a free-form question) or a structured return shape (e.g. an array of step records the agent can iterate over).

Either way, two fields drive when and how the model uses the tool:

- `description` — what the tool does. Always present.
- `inputInstructions[]` — extra guidance applied **before** the tool is called (scope boundaries, negative examples, disambiguation).
- `outputInstructions[]` — guidance applied **after** the tool returns. Each entry is a `{when, then}` object where `when` is a real condition. Native `KnowledgeBase` / `KnowledgeSetting` tools use two fixed slot conditions; `DataAction` KB lookups use a Python expression over `result`. Both are covered below, and in full in **10**.

### Choosing the integration path

| Path | Tool `type` | When to use | You author |
| --- | --- | --- | --- |
| **GC native** | `KnowledgeBase` or `KnowledgeSetting` | KB content lives in Genesys Cloud; a free-form generated answer is enough | `description`, `inputInstructions[]`, optional `outputInstructions[]`, `targetId`, `targetName` |
| **External provider** | `DataAction` | KB is served by an external integration (Hedwig DataAction); you need custom inputs or structured step records | Above plus `inputs[]`, `output`, and `types[]` for custom shapes like `KBSteps` |

The platform wires the native path automatically: `query: KnowledgeBaseQuery` input, `GeneratedKnowledgeAnswer` return, and a built-in "the query MUST be in the form of a question" precondition. You do not declare those in the VersionDefinition.

Discover resources with `list_resources(resource_type="knowledge_base")` / `list_resources(resource_type="knowledge_setting")` / `list_resources(resource_type="knowledge_source")` (plain UUID `targetId`, no `custom_-_` prefix). External KB DataActions use `list_resources(resource_type="data_action")` and the `custom_-_<uuid>` `targetId` format. For FileUpload authoring + ensure/upload, see [ava-knowledge](../../ava-knowledge/SKILL.md).

The sections below show both paths. Examples using `KBSteps` are **DataAction-only** — native `KnowledgeBase` / `KnowledgeSetting` tools return a generated string answer, not structured step records.

## Guiding function selection with KB scope (GC native)

When KB content is hosted in Genesys Cloud and a generated answer is sufficient, use a `KnowledgeBase` or `KnowledgeSetting` tool. Scope routing works the same way — `description` for coarse selection, `inputInstructions[]` for boundaries and negative examples.

```json
{
  "tools": [
    {
      "type": "KnowledgeBase",
      "name": "Search Reservations FAQ",
      "description": "Search the reservations FAQ knowledge base.",
      "targetId": "<kb-uuid>",
      "targetName": "reservations-faq",
      "inputInstructions": [
        "Use this tool when the customer has a problem with their reservation or stay. The knowledge base covers: check-in and check-out procedures, cancellation and refund policies, room amenities and facilities, parking and transportation, and loyalty program FAQs. Do NOT use this for looking up or modifying a specific reservation — use Lookup Reservation and Cancel Reservation for those."
      ]
    }
  ]
}
```

`KnowledgeSetting` tools are authored the same way — only `type`, `targetId`, and `targetName` differ. Use `KnowledgeSetting` when the org has a pre-configured knowledge resource (discovered via `list_resources(resource_type="knowledge_setting")`) rather than a document corpus (`list_resources(resource_type="knowledge_base")`):

```json
{
  "tools": [
    {
      "type": "KnowledgeSetting",
      "name": "Search Support Policies",
      "description": "Search the configured support-policy knowledge resource.",
      "targetId": "<knowledge-setting-uuid>",
      "targetName": "support-policies",
      "inputInstructions": [
        "Use for general policy and procedure questions. Do NOT use for account-specific lookups."
      ]
    }
  ]
}
```

### Disambiguating between competing tools (GC native)

When multiple native KB tools could handle the same query, give each its own `inputInstructions[]`:

```json
{
  "tools": [
    {
      "type": "KnowledgeBase",
      "name": "Search Product FAQ",
      "description": "Search the product FAQ knowledge base.",
      "targetId": "<product-kb-uuid>",
      "targetName": "product-faq",
      "inputInstructions": [
        "Use this for 'how do I' product-usage questions.",
        "Do NOT use this for billing or account questions."
      ]
    },
    {
      "type": "KnowledgeBase",
      "name": "Search Billing FAQ",
      "description": "Search the billing FAQ knowledge base.",
      "targetId": "<billing-kb-uuid>",
      "targetName": "billing-faq",
      "inputInstructions": [
        "Use this only for billing disputes or payment questions."
      ]
    }
  ]
}
```

## Guiding function selection with KB scope (external DataAction)

The tool's `name` and `description` tell the model *how* to call the tool, but not *when*. Without explicit guidance, the model guesses — and guesses wrong in predictable ways: calling the KB for questions it can't answer, or failing to call it for questions it can.

The `description` already influences selection. A description like "Search the knowledge base for help articles about reservations" is often enough for a simple agent with clear tool boundaries — the model reads it and uses it when deciding whether to call the tool.

When you need finer control — explicit scope boundaries, negative examples, or disambiguation between competing tools — add those as `inputInstructions[]` on the tool. Each string in `inputInstructions[]` is surfaced to the model before the tool is invoked.

```json
{
  "types": [
    {
      "name": "CustomerIssue",
      "type": "string",
      "direction": "input",
      "description": "Issue description captured from the user's message."
    },
    {
      "name": "KBStep",
      "type": "object",
      "direction": "output",
      "description": "A single step in a help article.",
      "properties": [
        { "name": "stepNumber",  "type": "integer", "required": true, "description": "1-based index of this step." },
        { "name": "totalSteps",  "type": "integer", "required": true, "description": "Total number of steps in this article." },
        { "name": "title",       "type": "string",  "required": true, "description": "Short title for this step." },
        { "name": "instruction", "type": "string",  "required": true, "description": "What the customer should do." }
      ]
    },
    {
      "name": "KBSteps",
      "type": "array",
      "items": "KBStep",
      "direction": "output",
      "description": "Ordered steps returned from the reservations knowledge base."
    }
  ],
  "tools": [
    {
      "type": "DataAction",
      "name": "Search Reservations KB",
      "description": "Search the knowledge base for a help article about a reservation issue.",
      "inputs": [
        { "targetName": "issue", "type": "CustomerIssue", "source": "User", "required": true }
      ],
      "output": "KBSteps",
      "inputInstructions": [
        "Use this tool when the customer has a problem with their reservation or stay. The knowledge base covers: check-in and check-out procedures, cancellation and refund policies, room amenities and facilities, parking and transportation, and loyalty program FAQs. Do NOT use this for looking up or modifying a specific reservation — use Lookup Reservation and Cancel Reservation for those."
      ],
      "targetId": "<hedwig-data-action-id>",
      "targetName": "search_reservations_kb"
    }
  ]
}
```

Notes:

- `inputInstructions[]` accepts any number of strings. Use one per cohesive idea (scope, negative examples, disambiguation) or combine into a single paragraph as above.
- Use this path when the KB integration returns structured records (e.g. step arrays) or needs a custom input type. For a free-form generated answer from GC-hosted content, prefer the native `KnowledgeBase` / `KnowledgeSetting` examples above.

### Disambiguating between competing tools (external DataAction)

When the agent has multiple tools that could plausibly handle a query, give each tool its own `inputInstructions[]` describing the slice of the problem space it owns. The model reads all of them when deciding which tool to call.

```json
{
  "tools": [
    {
      "type": "DataAction",
      "name": "Search Product KB",
      "description": "Search the product-usage knowledge base.",
      "inputs": [
        { "targetName": "query", "type": "CustomerIssue", "source": "User", "required": true }
      ],
      "output": "KBSteps",
      "inputInstructions": [
        "Use this for 'how do I' product-usage questions.",
        "Do NOT use this for billing or account questions."
      ],
      "targetId": "<product-kb-id>",
      "targetName": "search_product_kb"
    },
    {
      "type": "DataAction",
      "name": "Search Billing KB",
      "description": "Search the billing knowledge base.",
      "inputs": [
        { "targetName": "query", "type": "CustomerIssue", "source": "User", "required": true }
      ],
      "output": "KBSteps",
      "inputInstructions": [
        "Use this only for billing disputes or payment questions."
      ],
      "targetId": "<billing-kb-id>",
      "targetName": "search_billing_kb"
    }
  ]
}
```

Each tool's `inputInstructions[]` is independent — write them as if the other tools did not exist, then add explicit negative examples ("Do NOT use this for…") to push the model toward the correct boundary.

## Structured results via DataAction (external provider only)

For multi-step results, return structured records the agent can iterate over, not a raw string the agent has to paraphrase in one go. This pattern requires a `DataAction` tool — native `KnowledgeBase` / `KnowledgeSetting` tools return a single generated answer string.

Express this with a struct type for one record, an array-wrapper struct for the list, and a `DataActionTool` whose `output` references the wrapper:

```json
{
  "types": [
    {
      "name": "KBStep",
      "type": "object",
      "direction": "output",
      "description": "A single step in a help article.",
      "properties": [
        { "name": "stepNumber",  "type": "integer", "required": true, "description": "1-based index of this step within the article." },
        { "name": "totalSteps",  "type": "integer", "required": true, "description": "Total number of steps in this article." },
        { "name": "title",       "type": "string",  "required": true, "description": "Short title for this step." },
        { "name": "instruction", "type": "string",  "required": true, "description": "What the customer should do for this step." }
      ]
    },
    {
      "name": "KBSteps",
      "type": "array",
      "items": "KBStep",
      "direction": "output",
      "description": "Ordered steps returned from the knowledge base."
    }
  ],
  "tools": [
    {
      "type": "DataAction",
      "name": "Search KB",
      "description": "Search the knowledge base for a help article.",
      "inputs": [
        { "targetName": "issue", "type": "CustomerIssue", "source": "User", "required": true }
      ],
      "output": "KBSteps",
      "targetId": "<kb-data-action-id>",
      "targetName": "search_kb"
    }
  ]
}
```

`KBStep` carries `stepNumber` and `totalSteps` as explicit fields. This redundancy is deliberate — it gives the model a concrete number to count against ("I've delivered step 2 of 3") instead of relying on prose like "deliver every step".

Two things happen automatically and do not need to appear in the VersionDefinition:

- The platform marks output types as `must_copy` so the model is required to reproduce field values verbatim instead of paraphrasing.
- Arrays are expressed by setting `"type": "array"` and `items` to the element type name; the platform handles the underlying list-of-records shape.

## Using output instructions to control delivery (DataAction)

`outputInstructions[]` tells the agent how to present a tool's results. The step-by-step delivery style below applies to every successful call, so `when: "True"` is the right choice (conditions over `result` are in **10**):

```json
{
  "tools": [
    {
      "type": "DataAction",
      "name": "Search KB",
      "description": "Search the knowledge base for a help article.",
      "inputs": [
        { "targetName": "issue", "type": "CustomerIssue", "source": "User", "required": true }
      ],
      "output": "KBSteps",
      "outputInstructions": [
        {
          "when": "True",
          "then": "Walk the customer through these steps one at a time. Deliver ONLY the first step now: state the step number out of the total, give the title and instruction, then wait for the customer to confirm before moving on. Do NOT list multiple steps in a single message."
        }
      ],
      "targetId": "<kb-data-action-id>",
      "targetName": "search_kb"
    }
  ]
}
```

## Native KnowledgeBase / KnowledgeSetting output instructions

For `KnowledgeBase` and `KnowledgeSetting` tools, the AVA UI exposes exactly **two** output-instruction slots. Each is selected by an exact `when` string — not by `"True"`, and not by position. Full rules in **10**.

| Slot | `when` (verbatim) |
| --- | --- |
| **No-result** | `"lambda result: len(result) == 0"` |
| **With-result** | `"lambda result: len(result) > 0"` |

The platform defaults both slots. Author `outputInstructions[]` only to override a default; at most two entries. Extra delivery guidance (pacing, voice phrasing, escalation) goes in that slot's `then`, not in extra entries.

```json
{
  "name": "Search Product FAQ",
  "type": "KnowledgeBase",
  "description": "Search the product FAQ knowledge base.",
  "targetId": "<kb-uuid>",
  "targetName": "product-faq",
  "inputInstructions": [
    "Use for product how-to questions. Do NOT use for billing or account issues."
  ],
  "outputInstructions": [
    {
      "when": "lambda result: len(result) == 0",
      "then": "Apologize that you could not find an answer and offer to transfer to a specialist."
    },
    {
      "when": "lambda result: len(result) > 0",
      "then": "Answer using only the retrieved content. Keep the reply concise and ask whether it resolved the issue."
    }
  ]
}
```

## Branching on result shape (DataAction KB lookups)

On a `DataAction` KB lookup, author **one entry per result shape**. Do not collapse empty vs non-empty into a single always-on `then` — see **10**.

```json
{
  "tools": [
    {
      "type": "DataAction",
      "name": "Search KB",
      "description": "Search the knowledge base for a help article.",
      "inputs": [
        { "targetName": "issue", "type": "CustomerIssue", "source": "User", "required": true }
      ],
      "output": "KBSteps",
      "outputInstructions": [
        {
          "when": "len(result.steps) == 0",
          "then": "Apologize that you could not find instructions for this issue and offer to transfer to a specialist."
        },
        {
          "when": "len(result.steps) > 0",
          "then": "Walk the customer through the steps one at a time: deliver ONLY the first step now and wait for confirmation."
        }
      ],
      "targetId": "<kb-data-action-id>",
      "targetName": "search_kb"
    }
  ]
}
```

Pre-call guidance (scope, negative examples, disambiguation) belongs in `inputInstructions[]`; post-call delivery guidance belongs in `outputInstructions[]`. Keep the two separate so the model gets each instruction at the moment it applies.
