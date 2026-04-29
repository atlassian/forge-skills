# Atlassian Forge Skills

Atlassian Forge lets you build and deploy apps directly on the Atlassian platform - issue panels, Confluence macros, dashboard gadgets, and more. The Forge Skills Plugin bundles several Forge-focused skills plus MCP-backed tooling so your agent can scaffold apps, review them before deploy, debug production issues, and stay current on Forge APIs and the Atlassian Design System.

## What's included

### Skills

The plugin ships multiple skills under `skills/`, each with a `SKILL.md` the host can load:

**Forge App Builder** (`skills/forge-app-builder/`) guides scaffolding through production: `forge create`, dev spaces and templates, deploy and install, module selection, cross-product scopes, and common CLI or permission issues.

**Forge App Review** (`skills/forge-app-review/`) supports pre-deploy review and audits: security, architecture, cost and invocation efficiency, performance, and trigger or scheduling waste.

**Forge Debugger** (`skills/forge-debugger/`) supports systematic troubleshooting when something breaks: `forge` / deploy errors, resolver failures, blank or missing UI, scopes and permissions, and apps that “stopped working” in Jira or Confluence.

### Forge MCP Server

Gives your agent access to up-to-date Forge documentation, template registries, module configuration, manifest syntax, and UI Kit/backend API guides -- so its knowledge stays current rather than relying on training data.

### ADS MCP Server

Provides Atlassian Design System lookup for Custom UI apps: component discovery, token reference, and icon search via the `@atlaskit` library.


| Component                   | What it adds                                              | Examples                                                               |
| --------------------------- | --------------------------------------------------------- | ---------------------------------------------------------------------- |
| **Forge App Builder skill** | Scaffold, deploy, install, module choice, CLI workflows   | `forge create`, environments, cross-product scopes                     |
| **Forge App Review skill**  | Pre-deploy review: security, cost, architecture, triggers | Audit before release, reduce invocations, find misconfigurations       |
| **Forge Debugger skill**    | Diagnose deploy, runtime, UI, and permission issues       | Logs, blank panels, resolver errors, missing app in UI                 |
| **Forge MCP Server**        | Live Forge documentation and tooling                      | Template lookup, manifest syntax, UI Kit guides, backend API reference |
| **ADS MCP Server**          | Atlassian Design System lookup                            | Component discovery, token reference, icon lookup (Custom UI only)     |


## Prerequisites

Before you install, make sure you have:

- An [Atlassian account](https://id.atlassian.com)
- **Node.js 22+** (`node -v`) — required for Forge CLI and app builds
- **Python 3** available on your PATH (used by helper scripts)

## Install

### Claude Code

```
/plugin install forge-skills@atlassian-forge-skills
```
### Cursor

The Cursor plugin needs to be installed locally. In your terminal run:

```
cd ~/.cursor/plugins/local
git clone https://github.com/atlassian/forge-skills.git
```

_[Cursor Marketplace](https://cursor.com/marketplace) support coming soon._

### Gemini CLI

```bash
gemini extensions install https://github.com/atlassian/forge-skills
```

### GitHub Copilot CLI

```bash
copilot plugin install atlassian/forge-skills
```

### OpenAI Codex

Coming soon

### Rovo Dev

Rovo Dev doesn't currently support plugin installations but you can install the skills and MCP servers separately.

Install the skills:
```bash
npx skills add atlassian/forge-skills
```

Then run `acli rovodev mcp` to edit your MCP configuration in your default editor. Add the details from `.mcp.json`.

Restart Rovo Dev for the skills and MCP to be available.

## Verify the installation

After install, try three quick checks.

### 1. Verify the skill layer

Ask:

> Build me a Jira issue panel that shows customer support tickets.

You should get a structured Forge workflow: developer space discovery, template selection, `forge create`, code customization, and deployment -- not just generic code snippets.

Optionally confirm the other skills are available:

- **Review:** e.g. “Review my Forge app for security and unnecessary trigger invocations before I deploy.”
- **Debug:** e.g. “My Forge issue panel is blank after deploy -- help me trace it.”

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
- `Review my Forge app for cost and security before production.`
- `forge deploy fails with [error] -- what should I check?`

## What you get


| Component             | Default location                                                                               | Purpose                                              |
| --------------------- | ---------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| **Forge App Builder** | `skills/forge-app-builder/`                                                                    | Create, deploy, install; helper scripts and tests    |
| **Forge App Review**  | `skills/forge-app-review/`                                                                     | Pre-deploy review and audits (`SKILL.md`, README)    |
| **Forge Debugger**    | `skills/forge-debugger/`                                                                       | Troubleshooting and diagnostics (`SKILL.md`, README) |
| **MCP config**        | `.mcp.json`                                                                                    | Forge MCP Server and ADS MCP Server configuration    |
| **Plugin manifests**  | `.cursor-plugin/`, `.claude-plugin/`, `.codex-plugin/`, `plugin.json`, `gemini-extension.json` | Per-host plugin metadata and MCP wiring              |


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
- Confirm the `skills/` directory includes `forge-app-builder`, `forge-app-review`, and `forge-debugger` (each with a `SKILL.md` where applicable)
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
