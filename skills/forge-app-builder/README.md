# Forge App Builder Skill

Guides creation, deployment, and installation of Atlassian Forge apps (Jira widgets, Confluence macros, issue panels, dashboard gadgets, etc.). Use when building any Forge app. Provides automated `forge create` workflow, module selection, CLI commands, and deployment scripts.

## Installation

This skill ships inside the **[Forge Skills](https://github.com/atlassian/forge-skills)** plugin bundle (`skills/forge-app-builder/`). Prefer installing that repo as a plugin in your editor or CLI so you get the skill plus Forge and ADS MCP configuration. See the [forge-skills README](https://github.com/atlassian/forge-skills/blob/main/README.md) for Cursor, Claude Code, Gemini, Codex, and Copilot CLI.

### Using only this skill folder (advanced)

If your host can load a skill from an arbitrary path, point it at `skills/forge-app-builder` inside a checkout of [forge-skills](https://github.com/atlassian/forge-skills). For example, clone the repo and symlink into a global skills directory:

```bash
git clone https://github.com/atlassian/forge-skills.git ~/dev/forge-skills
ln -s ~/dev/forge-skills/skills/forge-app-builder ~/.cursor/skills/forge-app-builder
```

Adjust the target path for your tool (`.claude/skills/`, `.agents/skills/`, etc.). You will not get `.mcp.json` from the symlink alone; install the full plugin or add MCP servers yourself if you want them.

---

## What This Skill Provides

- **Automated workflow** — Discovers dev spaces, creates apps with `forge create`, deploys and installs
- **Module selection** — Guidance for Jira panels, Confluence macros, dashboard gadgets, Rovo agents, and more
- **Helper scripts** — Python scripts for dev spaces, templates, and deployment
- **Reference docs** — CLI workflow, module selector, project setup

See [SKILL.md](SKILL.md) for the full skill content.
