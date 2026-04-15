# Forge Debugger Skill

Diagnoses and fixes issues in Atlassian Forge apps. Use this skill whenever a Forge app has errors, crashes, shows blank UI, fails to deploy, doesn't appear after installation, has permission issues, or produces unexpected output. Trigger on any mention of forge logs, forge deploy errors, resolver errors, blank panels, missing scopes, Custom UI not rendering, or any Jira/Confluence app that "stopped working".

## Installation

### Cursor

Clone this repository into your Cursor skills directory:

```bash
git clone https://bitbucket.org/atlassianlabs/forge-debugger-skill.git ~/.cursor/skills/forge-debugger
```

The skill will be automatically discovered by Cursor. Use it when debugging Forge apps by mentioning errors, deploy failures, blank panels, or similar issues.

**Alternative (project-scoped):** To make the skill available only for a specific project, clone into the project's `.cursor/skills/` directory:

```bash
mkdir -p .cursor/skills
git clone https://bitbucket.org/atlassianlabs/forge-debugger-skill.git .cursor/skills/forge-debugger
```

### Rovo Dev

Clone this repository into your Rovo Dev skills directory:

```bash
git clone https://bitbucket.org/atlassianlabs/forge-debugger-skill.git ~/.agents/skills/forge-debugger
```

The skill will be automatically discovered by Rovo Dev. Use it when debugging Forge apps by mentioning forge logs, deploy errors, resolver issues, or similar.

**Alternative (project-scoped):** To make the skill available only for a specific project, clone into the project's `.agents/skills/` directory:

```bash
mkdir -p .agents/skills
git clone https://bitbucket.org/atlassianlabs/forge-debugger-skill.git .agents/skills/forge-debugger
```

### Claude Code

Clone this repository into your Claude Code skills directory:

```bash
git clone https://bitbucket.org/atlassianlabs/forge-debugger-skill.git ~/.claude/skills/forge-debugger
```

The skill will be automatically discovered by Claude Code. Use it when debugging Forge apps by mentioning forge logs, deploy errors, resolver issues, or similar.

**Alternative (project-scoped):** To make the skill available only for a specific project, clone into the project's `.claude/skills/` directory:

```bash
mkdir -p .claude/skills
git clone https://bitbucket.org/atlassianlabs/forge-debugger-skill.git .claude/skills/forge-debugger
```

## What This Skill Provides

- **Structured diagnostic workflow** — Step-by-step checklist to identify root causes quickly: version checks, lint, build verification, deploy status, and log analysis
- **Common error pattern matching** — Instant lookup table covering 15+ frequent Forge errors (blank UI, resolver not found, 403s, 410 Gone, handler path issues, and more)
- **Autonomous execution** — The agent runs diagnostic and fix commands directly, without asking permission or presenting copy-paste instructions
- **API migration guidance** — Handles v1 → v2 REST API migration for Confluence and Jira endpoints
- **Token-efficient debugging** — Prioritizes cheap checks first (lint, version) and stops at root cause to minimize context usage

See [SKILL.md](SKILL.md) for the full skill content.
