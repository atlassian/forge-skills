# Forge App Review Skill

Performs a lightweight pre-release readiness review for Atlassian Forge apps. Use it as the broad "is this app ready to ship?" pass before deployment or handoff.

This skill is the review front door. It checks whether a Forge app looks ready to lint, deploy, install, and maintain, then routes deeper concerns to specialist skills instead of duplicating their rulebooks.

## Use For

- General Forge app review
- Pre-deploy or release-readiness checks
- Manifest/module/function/resource wiring
- Architecture and maintainability review
- Dependency, runtime, script, and verification sanity checks
- Obvious security, cost, or debugging signals that need specialist follow-up

## Do Not Use For

- Full SAST, exploitability analysis, CVSS scoring, or secrets/authz/tenant-isolation audits
- Cost optimization plans, platform-consumption reductions, or memory/storage/log tuning
- Known failures such as blank UI, failed deploy/install, resolver errors, or specific stack traces

## Specialist Handoffs

- Use `forge-security-review` for deep security audit, SAST, authz, secrets, tenant isolation, exploitability, and CVSS reporting.
- Use `forge-cost-optimizer` for reducing invocations, GB-seconds, storage/log volume, trigger frequency, memory, and Forge platform consumption.
- Use `forge-debugger` for known failures, error messages, blank UI, deploy/install problems, resolver errors, tunnel/log diagnosis, and apps that stopped working.
- Use `forge-display-conditions` for array-based simplifications of legacy Jira/JSM manifest conditions. A broad review may suggest this as an optional readability improvement, but existing object syntax is not a blocker.

## What It Checks

- Manifest references: modules, resources, functions, handlers, permissions, remotes, triggers, and runtime.
- Package shape: scripts, direct dependencies, Forge package fit, and obvious unused or missing packages.
- Source wiring: frontend entry points, resolver names, handler exports, bridge calls, product API calls, storage usage, and logging.
- Readiness gaps: missing verification commands, stale docs, missing tests where behavior risk justifies them, and specialist follow-ups.

The output is a concise readiness report with prioritized findings, clean areas, and recommended next steps.

## Example Prompts

```text
Review my Forge app before I deploy it.
```

```text
Is this Forge app ready to ship?
```

```text
Do a general app-review pass on this manifest and source.
```

```text
Check whether this Forge app is ready for release, and route any deep security or cost concerns to the right skill.
```

See [SKILL.md](SKILL.md) for the full workflow.
