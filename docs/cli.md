# `ava-mcp` CLI reference

`ava-mcp` is a single entry point, installed as a `uv` tool by the [install script](../README.md#quick-start). Run `ava-mcp <command> --help` for the options of any command, and `ava-mcp --version` for the installed version. Running `ava-mcp` with no command prints help and exits non-zero.

| Command                | Alias   | Does                                                          |
| ---------------------- | ------- | ------------------------------------------------------------- |
| `ava-mcp setup`        | `init`  | Interactive install wizard. Does not sign in.                 |
| `ava-mcp serve`        | `run`   | Start the MCP stdio server (what `mcp.json` launches).        |
| `ava-mcp login`        | —       | Sign in to Genesys Cloud and store the session.               |
| `ava-mcp logout`       | —       | Clear the stored session.                                     |
| `ava-mcp status`       | —       | Show the stored sign-in and whether a newer release exists.   |
| `ava-mcp skills sync`  | —       | Install or refresh AVA skills and subagents.                  |
| `ava-mcp upgrade`      | —       | Upgrade `ava-mcp` itself.                                     |
| `ava-mcp docs [GUIDE]` | `doc`   | **Deprecated** — see [below](#ava-mcp-docs-deprecated). |

There is no `ava-mcp update` or top-level `ava-mcp sync`. Use `ava-mcp skills sync` to refresh skills and `ava-mcp upgrade` to update the tool.

## `ava-mcp setup`

Interactive wizard, run from your project directory. It asks, in order:

1. Whether to upgrade first, if a newer release exists.
2. Which IDEs: Cursor, Kiro, Claude Code.
3. Which actions: install the MCP config, and/or install or refresh skills and subagents.
4. MCP scope: `project` (recommended) or `user`. Claude Code is always installed at project scope.
5. For Claude Code and Kiro, whether to auto-install the MCP entry (skipped if the IDE's CLI is not on your `PATH`).
6. Skills scope, then a dry-run preview before anything is written.

Auto-install runs, for Claude Code:

```bash
claude mcp remove ava-harness -s project
claude mcp add ava-harness -s project -e FASTMCP_LOG_LEVEL=ERROR -- ava-mcp serve
```

and for Kiro (`workspace` for project scope, `global` for user scope):

```bash
kiro-cli mcp add --name ava-harness --scope workspace --command ava-mcp --args serve --env FASTMCP_LOG_LEVEL=ERROR --force
```

Cursor is snippet-only: add the `mcp.json` entry from the [README](../README.md#mcp-configuration) to `./.cursor/mcp.json` (or `~/.cursor/mcp.json` for user scope).

The wizard does not ask for a region or credentials and does not sign in. That happens on the first `ava-mcp serve`, or when you run `ava-mcp login`.

## `ava-mcp login`

```bash
ava-mcp login                            # browser sign-in; pick the region in the browser
ava-mcp login --habitat prod-euw1        # browser sign-in with a region pre-selected
ava-mcp login --auth client-credentials  # use your own OAuth client id + secret
ava-mcp logout                           # clear the stored session
```

| Flag              | Meaning                                                                                                                                       |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `--auth`          | `browser` (default) or `client-credentials`.                                                                                                  |
| `--habitat`       | Genesys Cloud region (see [Regions](#regions)). Browser mode: pre-selects it in the picker. Client-credentials mode: required, prompted if omitted; an unknown value is rejected. |
| `--client-id`     | Client-credentials mode only. Prompted if omitted.                                                                                            |
| `--client-secret` | Client-credentials mode only. Prefer the prompt (no echo) — a flag value is visible to `ps` and saved in your shell history.                  |

- **Browser** (default) runs an OAuth Authorization Code + PKCE sign-in with a client built into the CLI. There is nothing to register, and you get no secret to manage. On your first login, approve the application for your org.
- **Client-credentials** stores your own client id and secret, for orgs that block the browser flow or users who already have a client. Your client needs OAuth scopes beyond the role permissions — see [Permissions and OAuth scopes](./permissions.md#oauth-scopes-bring-your-own-client-only).
- The session is written to `./.ava_mcp/config.toml` in the directory you run the command from. There is no global or per-user session, so sign in once per project.
- **Nothing is saved unless the core permissions are granted.** `login` probes your grants after authenticating. If any core permission is missing it prints the list to give your org admin, exits non-zero, and stores no session. Rejected credentials (a mistyped secret) are reported as a sign-in failure instead, with no permission list.
- On success `login` also records which optional tool groups to hide — see [Permissions](./permissions.md#optional-tool-groups). Restart your IDE (or reload MCP) afterward.

`login` exits non-zero on every outcome that saved nothing. `logout` always exits 0.

### Regions

Prod regions accepted by `--habitat`:

`prod`, `prod-apne1`, `prod-apne2`, `prod-apne3`, `prod-aps1`, `prod-apse1`, `prod-apse2`, `prod-cac1`, `prod-euc1`, `prod-euc2`, `prod-euw1`, `prod-euw2`, `prod-mec1`, `prod-mxc1`, `prod-sae1`, `prod-usw2`

## `ava-mcp serve`

Starts the MCP server on stdio — this is the command in your `mcp.json`. Before it accepts tool calls it checks for credentials:

- **Credentials already available** (an unexpired stored session, or `GENESYS_*` environment variables): nothing happens.
- **Nothing configured:** it writes an inert placeholder session, then opens the browser sign-in with the region picker. If sign-in fails or you close the browser, startup fails with an error telling you to run `ava-mcp login`.
- **Placeholder already stored:** the browser is **not** reopened on every restart. Tools return `403` until you run `ava-mcp login`, which overwrites the placeholder.
- **Browser session expired:** in production it signs in again for the same region and re-runs the permission check. The browser grant has no refresh token, so expiry always means a new browser sign-in.
- **Client-credentials session:** never expires — a new token is minted on demand from the stored id and secret.

If the browser never reaches the local sign-in page, startup gives up after a short window (about 15 seconds) rather than waiting out the full 5-minute callback timeout.

## `ava-mcp status`

Reads the stored session locally and makes one request to GitHub to check for a newer release. It does not call Genesys Cloud, and always exits 0.

## `ava-mcp skills sync`

```bash
ava-mcp skills sync                 # interactive wizard (on a terminal)
ava-mcp skills sync .               # headless: install into the current project
ava-mcp skills sync . --dry-run     # show what would change
ava-mcp skills sync . --yes         # apply without confirming
```

| Argument / flag | Meaning                                                                                           |
| --------------- | ------------------------------------------------------------------------------------------------- |
| `[DEST]`        | Destination directory. Giving it (or either flag below) switches to headless mode.               |
| `--dry-run`     | Show the changes without writing. Cannot be combined with `--yes`.                                |
| `--yes`, `-y`   | Apply without prompting. Cannot be combined with `--dry-run`.                                     |

A headless run without `[DEST]` is an error. Run this after `ava-mcp upgrade` to refresh skills and subagents; it does not update the `ava-mcp` tool itself.

## `ava-mcp upgrade`

Upgrades `ava-mcp` itself by re-running the project installer.

| Flag            | Meaning                                              |
| --------------- | ---------------------------------------------------- |
| `--check`       | Only report whether a newer release exists.          |
| `--yes`, `-y`   | Upgrade without prompting.                           |
| `--force`       | Skip the version check and always reinstall.         |

The three flags are mutually exclusive. Without a terminal, `upgrade` behaves like `--yes`.

## `ava-mcp docs` (deprecated)

`ava-mcp docs [GUIDE]` prints bundled offline setup guides (`base`, `install`, `validate`, `verify`). They were written for agent-driven installs from a local wheel and are no longer relevant: use `ava-mcp setup` and the documentation in this repository instead. The command is still present but is not needed for any current workflow.

## Credentials and precedence

Credentials resolve from the **first source that supplies them**. The whole source wins — the chain stops at the first match and is never merged field by field:

1. **The project `./.ava_mcp/config.toml`**, if it exists in a recognised shape.
2. **Environment variables** (including a `.env` file in the working directory): `GENESYS_CLIENT_ID` / `GENESYS_CLIENT_SECRET`, or `GENESYS_ACCESS_TOKEN`. The `AVA_CLIENT_ID`, `AVA_CLIENT_SECRET`, and `AVA_ACCESS_TOKEN` names are accepted as fallbacks. `AVA_HABITAT` selects the region and defaults to `prod-usw2`.

If neither supplies usable credentials, tool calls fail with an error naming what is missing.

Things worth knowing:

- **A stored session always beats environment variables** — including an expired browser session and a placeholder session. If you set credentials in your environment and later run `ava-mcp login`, the stored session silently takes over and your environment credentials are ignored. Run `ava-mcp logout` to go back to them.
- **An expired browser session also overrides env credentials at server start:** the server reopens the browser to sign in again rather than falling back to the environment variables. `ava-mcp logout` avoids this too.
- **An unparseable or unrecognised `config.toml` is treated as absent**, so environment variables take over.
- **Settings the session does not carry** (`AVA_PUBLIC_BASE_URL`, `AVA_PUBLIC_AUTH_URL`, `AVA_TEST_MODE`) are always read from the environment.
- **The optional-tool flags follow the same rule:** a stored session's flags win over `AVA_MOCK_DATA_ACTIONS_DISABLED`, `AVA_KNOWLEDGE_UPLOAD_DISABLED`, and `AVA_NAVIGATOR_TOOLS_DISABLED`.
- **An authorization failure clears the stored session**, and you are asked to restart the server so it signs in again.

### Migrating from environment-variable credentials

Existing setups keep working with no change: an `mcp.json` with an `env` block holding `GENESYS_CLIENT_ID` / `GENESYS_CLIENT_SECRET` or `GENESYS_ACCESS_TOKEN`, plus `AVA_HABITAT`, is still valid, and the server will not open a browser while those credentials are present.

An example `mcp.json` with your own OAuth client in the `env` block (replace the placeholders):

```json
{
  "mcpServers": {
    "ava-harness": {
      "command": "ava-mcp",
      "args": ["serve"],
      "env": {
        "FASTMCP_LOG_LEVEL": "ERROR",
        "AVA_HABITAT": "prod-usw2",
        "GENESYS_CLIENT_ID": "<your-client-id>",
        "GENESYS_CLIENT_SECRET": "<your-client-secret>"
      },
      "disabled": false,
      "timeout": 60000
    }
  }
}
```

For a pre-issued token, replace the client id and secret with `"GENESYS_ACCESS_TOKEN": "<your-access-token>"`. Your OAuth client needs the extra scopes listed in [Permissions and OAuth scopes](./permissions.md#oauth-scopes-bring-your-own-client-only).

Do not use this together with a stored session for the same project: while `./.ava_mcp/config.toml` exists, the `AVA_HABITAT` and credential variables above are ignored. The default `mcp.json` (no credentials) is the one `ava-mcp setup` writes.

Differences to be aware of when you stay on environment variables:

- No permission check and no optional-tool probe runs. Missing grants appear later as `403` errors, and you must set the `AVA_*_DISABLED` flags yourself ([details](./permissions.md#environment-variable-credentials)).
- Secrets live in `mcp.json` or `.env`, which are easy to commit by accident.

To move to a stored session, run `ava-mcp login` (browser) or `ava-mcp login --auth client-credentials`, then remove the credentials from `mcp.json` / `.env`. Existing environment variables stay valid as a fallback only for as long as no stored session exists.

## `config.toml`

Written in full on every save, with mode `0600`. The CLI does not add it to `.gitignore` — add `.ava_mcp/` yourself.

Browser session:

```toml
habitat = "prod-usw2"
access_token = "<token>"
expires_at = 1792652031.13
token_type = "bearer"
mock_data_actions_disabled = false
knowledge_upload_disabled = false
navigator_tools_disabled = false
```

Client-credentials session (no token; a fresh one is minted on demand):

```toml
habitat = "prod-usw2"
client_id = "<client id>"
client_secret = "<client secret>"
mock_data_actions_disabled = false
knowledge_upload_disabled = false
navigator_tools_disabled = false
```

Session lifetime is whatever the token response says — about 12 hours for browser sign-in.
