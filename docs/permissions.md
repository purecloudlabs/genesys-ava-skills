# Permissions and OAuth scopes

This page lists everything beyond the core permissions in the [README](../README.md#prerequisites). Two different things are involved, and they are easy to confuse:

- **Role permissions** — granted to the signed-in user (or the OAuth client's role) in Genesys Cloud. Always required.
- **OAuth scopes** — granted to an OAuth client. Only matters if you bring your own client; the default browser sign-in uses a built-in client that already carries the scopes.

## Optional tool groups

Each group below is optional. At sign-in, `ava-mcp login` probes your grants and, if any permission in a group is missing, records the matching flag in `./.ava_mcp/config.toml` and hides that group's tools. Restart your IDE (or reload MCP) after signing in for the change to take effect.

| Tool group                | Flag set when a grant is missing      | Tools hidden                                                             |
| ------------------------- | ------------------------------------- | ------------------------------------------------------------------------ |
| Mock DataAction authoring | `AVA_MOCK_DATA_ACTIONS_DISABLED=true` | `create_mock_data_action`, `replace_mock_responses`                      |
| Knowledge FileUpload      | `AVA_KNOWLEDGE_UPLOAD_DISABLED=true`  | `ensure_knowledge_source`, `upload_knowledge_documents`, `ensure_knowledge_setting` |
| Navigator authoring       | `AVA_NAVIGATOR_TOOLS_DISABLED=true`   | `preview_navigator`, `build_navigator`                                   |

Discovery tools (`list_resources`, `get_data_action_schema`, `validate_knowledge`) stay available either way. `list_resources` discovery for `botflow`, `guide`, `cca_schema`, and `customer_intent_category` also stays available without the Navigator grants.

### Mock DataAction authoring

| Domain         | Entity        | Actions                            |
| -------------- | ------------- | ---------------------------------- |
| `integrations` | `integration` | `view`, `add`, `edit`              |
| `integrations` | `action`      | `add`, `edit`, `delete`, `execute` |

### Knowledge Fabric FileUpload

| Domain      | Entity             | Actions                         |
| ----------- | ------------------ | ------------------------------- |
| `knowledge` | `source`           | `view`, `add`                   |
| `knowledge` | `synchronization`  | `view`, `add`, `edit`, `upload` |
| `knowledge` | `knowledgeSetting` | `view`, `add`, `edit`           |

### Navigator authoring

| Domain             | Entity                   | Actions                                    |
| ------------------ | ------------------------ | ------------------------------------------ |
| `architect`        | `flow`                   | `add`, `edit`, `view`, `unlock`, `publish` |
| `aiStudio`         | `guide`                  | `view`                                     |
| `aiStudio`         | `guideVersion`           | `view`                                     |
| `externalContacts` | `customerIntentTaxonomy` | `view`, `add`                              |
| `conversation`     | `customAttributes`       | `schemaView`                               |
| `integrations`     | `integration`            | `view`                                     |

## OAuth scopes (bring-your-own client only)

Needed when you sign in with `ava-mcp login --auth client-credentials`, or supply `GENESYS_CLIENT_ID` / `GENESYS_CLIENT_SECRET` (or `GENESYS_ACCESS_TOKEN`) yourself. Role permissions alone are not enough.

| Used for                  | OAuth scope                                                    |
| ------------------------- | -------------------------------------------------------------- |
| Virtual agents (required) | `agentic-virtualagents` (or `agentic-virtualagents:readonly`)  |
| Reading your own grants (required) | `authorization` (or `authorization:readonly`)         |
| Navigator authoring       | `architect`, `ai-studio`, `external-contacts`, `conversations`, `integrations` |

- Without a Virtual agents scope, calls to the virtual agents API fail with `403`, even if every role permission is granted.
- Without the `authorization` scope, the permission check cannot read your grants. It gets a `403`, treats everything as missing, and lists the *entire* required permission set instead of the ones you are actually missing.

## Environment-variable credentials

The permission check runs only at `ava-mcp login` (and the automatic browser sign-in at server start). If you authenticate with environment variables instead, **nothing is checked and nothing is hidden for you**:

- Missing core permissions show up later as `403` errors from tools.
- Set `AVA_MOCK_DATA_ACTIONS_DISABLED`, `AVA_KNOWLEDGE_UPLOAD_DISABLED`, and `AVA_NAVIGATOR_TOOLS_DISABLED` to `true` yourself if your user lacks those grants.

See [Credentials and precedence](./cli.md#credentials-and-precedence).
