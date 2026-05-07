# Forge Cost Optimizer Skill

Optimizes Atlassian Forge apps to reduce platform consumption using Atlassian's official [Optimise Forge platform costs](https://developer.atlassian.com/platform/forge/optimise-forge-costs/) guidance.

Use this skill when you want an agent to audit or improve a Forge app's cost profile: reduce invocations, lower function duration / GB-seconds, tune memory, reduce KVS writes, trim logging, replace polling, add trigger filters, move safe work to the frontend, batch API calls, or evaluate Forge Remote trade-offs.

By default, the skill performs an audit first, presents prioritized recommendations, and offers to make the recommended changes. It should only modify files immediately when the user explicitly asks it to implement or apply optimizations.

## What This Skill Provides

- **Cost-focused workflow** — Inspect manifest, resolvers, frontend code, storage usage, triggers, logging, and memory settings.
- **Prioritized optimization advice** — Rank changes by likely impact and implementation risk.
- **Safe implementation guardrails** — Preserve authorization boundaries, avoid exposing secrets, and call out data freshness trade-offs.
- **Forge-specific patterns** — Covers `@forge/bridge`, `useProductContext()`, product event filters, `ignoreSelf`, web triggers, storage query indexes, bulk REST APIs, and `memoryMiB` tuning.
- **Audit-first behavior** — Produces an audit report by default, then asks whether to implement quick wins, selected high-impact changes, or gather measurements first.
- **Clear implementation summary** — When explicitly asked to make changes, summarizes changes made with validation results.

## Example Prompts

- `Optimize this Forge app for lower platform costs.`
- `Audit my Forge app for expensive invocation patterns.`
- `Reduce KVS writes and logging in this Forge app.`
- `Check whether these scheduled triggers can be made cheaper.`
- `Move any safe resolver work to the frontend using Forge bridge APIs.`
- `Help tune function memory for this Forge app without breaking performance.`

## Further Reading

- [Optimise Forge platform costs](https://developer.atlassian.com/platform/forge/optimise-forge-costs/)
- [Forge platform pricing](https://developer.atlassian.com/platform/forge/forge-platform-pricing/)
- [Forge manifest reference](https://developer.atlassian.com/platform/forge/manifest-reference/)
- [Forge bridge API](https://developer.atlassian.com/platform/forge/apis-reference/ui-api-bridge/bridge/)
