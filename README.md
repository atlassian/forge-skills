# Forge Skills Plugin

Atlassian Forge lets you build and deploy apps directly on the Atlassian platform -- issue panels, Confluence macros, dashboard gadgets, and more. The Forge Skills Plugin gives your coding agent deep Forge expertise and MCP-backed tooling so it can guide you through the full workflow: picking the right template, scaffolding with `forge create`, configuring scopes, deploying, and installing across products.

## What's included

### Forge App Builder skill

This plugin ships the **Forge App Builder** skill, which teaches an agent how Forge development gets done. It provides workflows, decision trees, and guardrails for scenarios such as:

- **Scaffold and create** apps with `forge create`, developer space selection, and template validation
- **Deploy and install** across environments and products with automated scripts
- **Choose the right module** for Jira issue panels, Confluence macros, dashboard gadgets, global pages, and more
- **Handle cross-product apps** that need scopes from both Jira and Confluence
- **Troubleshoot** common CLI errors, deployment failures, and permission issues

### Forge MCP Server

Gives your agent access to up-to-date Forge documentation, template registries, module configuration, manifest syntax, and UI Kit/backend API guides -- so its knowledge stays current rather than relying on training data.

### ADS MCP Server

Provides Atlassian Design System lookup for Custom UI apps: component discovery, token reference, and icon search via the `@atlaskit` library.

| Component | What it adds | Examples |
|-----------|-------------|----------|
| **Forge App Builder skill** | Forge expertise, workflows, and guardrails | Create, deploy, install, module selection, troubleshooting |
| **Forge MCP Server** | Live Forge documentation and tooling | Template lookup, manifest syntax, UI Kit guides, backend API reference |
| **ADS MCP Server** | Atlassian Design System lookup | Component discovery, token reference, icon lookup (Custom UI only) |

## Prerequisites

Before you install, make sure you have:

- An [Atlassian account](https://id.atlassian.com) with at least one [developer space](https://developer.atlassian.com/console/)
- **Node.js 22+** (`node -v`) — required for Forge CLI and app builds
- **Forge CLI** (recommended) — if it is not installed yet, the Forge App Builder skill will install it for you (`npm install -g @forge/cli`). You still need to authenticate when prompted:

```bash
forge login
```

- **Python 3** available on your PATH (used by helper scripts)

## Install

### Cursor

```
Install from source using this repository.
```

Then restart Cursor (or run "Developer: Reload Window").

### Claude Code

```
/plugin install from source using this repository
```

### Gemini CLI

```bash
gemini extensions install https://github.com/atlassian/forge-skills
```

### GitHub Copilot CLI

```bash
copilot plugin install .
```

Re-install after local changes (Copilot caches plugin components).

### OpenAI Codex

Install through a Codex marketplace entry (repo or personal) that points `source.path` at this plugin directory, then restart Codex.

## Verify the installation

After install, try three quick checks.

### 1. Verify the skill layer

Ask:

> Build me a Jira issue panel that shows customer support tickets.

You should get a structured Forge workflow: developer space discovery, template selection, `forge create`, code customization, and deployment -- not just generic code snippets.

### 2. Verify Forge MCP

Ask:

> What Forge templates are available for Confluence macros?

You should get a tool-backed response from the Forge documentation, not a hallucinated list.

### 3. Verify ADS MCP (Custom UI only)

Ask:

> What Atlaskit components should I use for a data table?

You should get a response backed by the Atlassian Design System, with specific component names and import paths.

## Prompts to try

Once the plugin is installed, try prompts like these:

- `Create a Jira issue panel that shows related support tickets from an external API.`
- `Build a Confluence macro that embeds an interactive chart with bar, line, and pie options.`
- `Add a Jira dashboard gadget that summarizes open issues grouped by priority.`
- `Create a Confluence macro that reads Jira issues assigned to me and displays them in a table.`
- `My forge create keeps failing with "Prompts can not be meaningfully rendered" -- help!`
- `Deploy my Forge app to my staging site.`
- `What scopes do I need for a Confluence app that also reads Jira data?`

## What you get

| Component | Default location | Purpose |
|-----------|-----------------|---------|
| **Skills** | `skills/forge-app-builder/` | Forge app builder skill with SKILL.md, helper scripts, and tests |
| **MCP config** | `.mcp.json` | Forge MCP Server and ADS MCP Server configuration |
| **Plugin manifests** | `.cursor-plugin/`, `.claude-plugin/`, `.codex-plugin/`, `plugin.json`, `gemini-extension.json` | Per-host plugin metadata and MCP wiring |

## Authentication

The Forge CLI handles authentication:

```bash
forge login
```

You will be prompted for your Atlassian email and an [API token](https://id.atlassian.com/manage/api-tokens). Enter credentials only in your terminal -- never paste tokens into chat.

Verify you are logged in:

```bash
forge whoami
```

## Troubleshooting

### The agent is not using Forge skills

- Make sure the plugin installed successfully in your host
- Confirm the `skills/forge-app-builder/` directory is present
- Reload or restart your host so it re-indexes plugins and MCP configuration

### MCP tools are not showing up

- Check that the Forge MCP entries were added for your host
- Restart MCP servers or reload the host after configuration changes
- Verify Node.js is installed (`node -v`)

### Forge commands fail with auth errors

- Re-run `forge login`
- Create a new API token at [id.atlassian.com/manage/api-tokens](https://id.atlassian.com/manage/api-tokens)
- Make sure the correct developer space is selected

### forge create fails

- **"Prompts can not be meaningfully rendered"**: Run `forge create` in an interactive terminal
- **"No developer spaces found"**: Create one at [developer.atlassian.com/console](https://developer.atlassian.com/console/)
- **"forge: command not found"**: `npm install -g @forge/cli`

## Learn more

- [Forge documentation](https://developer.atlassian.com/platform/forge/)
- [Forge CLI reference](https://developer.atlassian.com/platform/forge/cli-reference/)
- [Atlassian Design System](https://atlassian.design/)
- [Forge community](https://community.developer.atlassian.com/c/forge/)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[Apache 2.0](LICENSE)
