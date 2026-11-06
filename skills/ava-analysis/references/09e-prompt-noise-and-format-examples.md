# 9e Prompt noise and format examples

Cover the anti-patterns where the prompt surface carries content that costs tokens without changing agent behavior, or invites the model to copy example values into real replies:

- Superfluous information in `role` and other always-read prompt fields.
- Dummy concrete values in format templates.

## Superfluous information in prompts

Don't stuff `role` and type / property descriptions with context the model will never act on. Every extra token is noise competing with the ones that matter.

Wrong — brand history the model will never act on:

```json
{
  "role": "You are Avery, a reservations agent for Acme Hotels, founded 1967, a member of the Leading Hotels of the World, headquartered in Columbus OH. Acme operates forty properties across twelve countries and holds a 4.6-star guest rating. We believe in hospitality-first service and the values of integrity, craft, and care."
}
```

Right — only what the model needs:

```json
{
  "role": "You are Avery, a chat agent for Acme Hotels. You help guests look up existing reservations and cancel them when they are still within the refundable window."
}
```

> For the related anti-pattern of returning every backend field on an output struct, see [09a-narrow-tool-types.md](09a-narrow-tool-types.md) under "Superfluous output fields".

## Dummy values in format templates

Use a format template rather than a concrete example like `(123) 555-6789` to show a property's expected shape. A real-looking value invites the model to copy it into a reply or into a follow-up tool call; a visibly-templated value cannot be mistaken for a real one.

Wrong — concrete value the model can copy into a reply:

```json
{
  "types": [
    {
      "name": "GuestPhoneUpdate",
      "type": "object",
      "direction": "output",
      "description": "A request to update the guest's contact phone number.",
      "properties": [
        {
          "name": "phone",
          "type": "string",
          "required": true,
          "description": "The guest's new contact phone number, e.g. (123) 555-6789."
        }
      ]
    }
  ]
}
```

Right — template that visibly is a template:

```json
{
  "types": [
    {
      "name": "GuestPhoneUpdate",
      "type": "object",
      "direction": "output",
      "description": "A request to update the guest's contact phone number.",
      "properties": [
        {
          "name": "phone",
          "type": "string",
          "required": true,
          "description": "The guest's new contact phone number in the format (XXX) XXX-XXXX."
        }
      ]
    }
  ]
}
```


## Not prompt noise: AVA-generated Knowledge `outputInstructions`

Do **not** flag the `outputInstructions` on an AVA-generated Knowledge tool (`generationMode: "AgenticVirtualAgentGenerated"`) as prompt noise, superfluous content, or a platform-injected default that should be removed. In that mode the tool returns raw knowledge chunks and the AVA model writes the answer, so those instructions **are** the generation prompt — they change agent behavior directly, Sage supplies no default for them, and Sage rejects the tool outright if they are empty.

This is the opposite of the `role`-verbosity and dummy-value anti-patterns above: the three always-on (`when: "True"`) L17 defaults (word limit / level setting, no-answer handling, answer handling) are **required**, not noise. They are also **not** platform-injected — the "do not author fields the platform injects at publish time" rule (cookbook routing step 5) does not apply to them.

Wrong — recommending their removal:

```text
search_knowledge_base is AVA-generated, so the platform handles response
generation automatically. Remove the outputInstructions.   ← FALSE POSITIVE
```

Right — leave them in place, and only review them against L17:

```text
search_knowledge_base is AVA-generated, so its three always-on outputInstructions
are required (they are the generation prompt). Keep them; only check the word
limit matches the channel (50 digital / 40 voice) per design-constraints.md L17.
```

See [04-integrating-knowledge-bases.md](04-integrating-knowledge-bases.md) ("AVA-generated output instructions"), [10-conditional-output-instructions.md](10-conditional-output-instructions.md) (AVA-generated Knowledge tools), and design-constraints.md **L17**.
