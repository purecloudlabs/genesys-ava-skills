# Troubleshooting authentication

If you hit an authentication error (expired or rejected credentials, 401/403 responses, or the MCP server failing to connect), the quickest fix is to run `ava-mcp logout` and then `ava-mcp login`, or to delete the `.ava_mcp/config.toml` file and let the next start sign you in again. The location depends on how you installed:

| Setup                                              | Location of `config.toml`                                    |
| -------------------------------------------------- | ------------------------------------------------------------ |
| Claude Code                                        | `./.ava_mcp/config.toml` (project root)                      |
| Kiro (all setups except Kiro Powers)               | `./.ava_mcp/config.toml` (project root)                      |
| Kiro Powers                                        | `~/.kiro/powers/installed/ava-harness/.ava_mcp/config.toml`  |

Delete it, for example:

```bash
# Claude Code and Kiro (non-Powers)
rm ./.ava_mcp/config.toml

# Kiro Powers
rm ~/.kiro/powers/installed/ava-harness/.ava_mcp/config.toml
```

Then restart your IDE (or reload MCP). If the problem persists, run `ava-mcp login` to sign in again and re-pick your Genesys Cloud region (or `ava-mcp login --auth client-credentials` to use your own OAuth client).

## Common problems

**Sign-in says permissions are missing.** `ava-mcp login` only saves a session if the core permissions listed under [Prerequisites](../README.md#prerequisites) are granted, and it prints the ones to ask your org admin for. These are role permissions on your user, so running `login` again without a role change shows the same list. If you use your own OAuth client and the list is the *entire* required set, the client is probably missing the `authorization` scope (see [OAuth scopes](./permissions.md#oauth-scopes-bring-your-own-client-only)).

**Tools return 403 right after first start.** If the first browser sign-in never completed, a placeholder session is stored and the browser is not reopened on later restarts. Run `ava-mcp login` to replace it.

**My environment credentials stopped working.** A stored session in `./.ava_mcp/config.toml` takes precedence over environment variables. Run `ava-mcp logout` to fall back to them. See [Credentials and precedence](./cli.md#credentials-and-precedence).

**A tool is missing after sign-in.** Mock DataAction, knowledge upload, and Navigator tools are hidden when their optional permissions are missing. Grant them, run `ava-mcp login`, then restart your IDE (or reload MCP). See [Optional tool groups](./permissions.md#optional-tool-groups).
