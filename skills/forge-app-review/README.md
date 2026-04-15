# Forge App Review Skill

Reviews Forge apps for security vulnerabilities, architecture issues, cost inefficiencies, performance problems, and trigger/scheduling waste before deployment. Use this skill when you want to review, audit, or pre-deploy check a Forge app — trigger on phrases like "review my Forge app", "check my app", "pre-deploy check", "audit my Forge app", "check for security issues", "optimize my Forge app costs", "reduce invocations", "why is my app expensive", "check my triggers", or any request to evaluate a Forge app's quality, safety, cost efficiency, or readiness.

## Installation

### Cursor

Clone this repository into your Cursor skills directory:

```bash
git clone https://bitbucket.org/atlassianlabs/forge-app-review-skill.git ~/.cursor/skills/forge-app-review
```

The skill will be automatically discovered by Cursor. Use it when reviewing Forge apps by mentioning app review, security checks, cost optimization, or similar topics.

**Alternative (project-scoped):** To make the skill available only for a specific project, clone into the project's `.cursor/skills/` directory:

```bash
mkdir -p .cursor/skills
git clone https://bitbucket.org/atlassianlabs/forge-app-review-skill.git .cursor/skills/forge-app-review
```

### Rovo Dev

Clone this repository into your Rovo Dev skills directory:

```bash
git clone https://bitbucket.org/atlassianlabs/forge-app-review-skill.git ~/.agents/skills/forge-app-review
```

The skill will be automatically discovered by Rovo Dev. Use it when reviewing Forge apps by mentioning app review, security audit, cost checks, performance, or similar topics.

**Alternative (project-scoped):** To make the skill available only for a specific project, clone into the project's `.agents/skills/` directory:

```bash
mkdir -p .agents/skills
git clone https://bitbucket.org/atlassianlabs/forge-app-review-skill.git .agents/skills/forge-app-review
```

### Claude Code

Clone this repository into your Claude Code skills directory:

```bash
git clone https://bitbucket.org/atlassianlabs/forge-app-review-skill.git ~/.claude/skills/forge-app-review
```

The skill will be automatically discovered by Claude Code. Use it when reviewing Forge apps by mentioning app review, security audit, cost checks, performance, or similar topics.

**Alternative (project-scoped):** To make the skill available only for a specific project, clone into the project's `.claude/skills/` directory:

```bash
mkdir -p .claude/skills
git clone https://bitbucket.org/atlassianlabs/forge-app-review-skill.git .claude/skills/forge-app-review
```

## What This Skill Provides

- **Deep pre-deploy review** — Comprehensive analysis across five categories: Security, Architecture, Cost, Performance, and Triggers & Scheduling
- **40+ checks with severity levels** — Each check has a unique ID, severity (Critical/Warning/Info), and actionable fix guidance
- **Security analysis** — Detects overly broad scopes, missing egress restrictions, hardcoded secrets, missing input sanitization, and unsafe CSP configurations
- **Cost optimization** — Identifies chatty resolvers, unnecessary storage writes, logic that could run client-side for free, N+1 API calls, missing field selection, verbose logging, and memory over-provisioning
- **Performance tuning** — Finds sequential API calls that should be parallel, cold start bottlenecks, large storage entities, missing caching, and unoptimized filtering
- **Trigger & scheduling review** — Catches excessive scheduled trigger frequency, polling that should be event-driven, missing event filters, and feedback loops from missing `ignoreSelf`
- **Autonomous execution** — The agent reads manifest, dependencies, resolvers, and UI code automatically without asking what to review
- **Severity-sorted output** — Produces a single flat issue list sorted Critical → Warning → Info with file locations and specific fix instructions

See [SKILL.md](SKILL.md) for the full skill content.
