# Forge onboarding

A guided first Forge project: deploy a stock Rovo Agent, then turn the same app into
**Forge Guru**, a companion that attempts to find official Forge documentation and labels
curated fallback links when live search is unavailable.

The inherited search route returned HTTP 404 during this refactor. See the
[search dependency note](references/platform-contract.md#guru-search-dependency) for the
observed limitation and the required live check before promising documentation search.

Try "onboard me to Forge", "build my first Rovo Agent", or "resume Forge onboarding".
You can skip explanations, reuse an existing setup, pause, or exit. Allow roughly 15–25
minutes, with additional time possible for setup and provisioning.

The tutorial covers the manifest, modules, backend functions, permissions, and the
edit → deploy → install → use workflow. Its two loops give you a working stock app first,
then a more useful app to keep on your developer site while that site remains active.

## Instructions and resources

[SKILL.md](SKILL.md) is the authoritative workflow entry point. It routes to phase references
only when needed. This README is an overview; command recipes and consent rules live in
the workflow.

- [References](references/) contain setup, teaching, scaffold, deployment, recovery, and handoff guidance.
- [Guru assets](assets/forge-guru/) contain the manifest fragment and backend source used during customization.

Install `forge-onboarding` together with `forge-app-builder` from the
[Forge Skills bundle](https://github.com/atlassian/forge-skills). The builder supplies the
creation helper. Onboarding invokes deployment and installation directly and discloses
the helper's terms behavior before it can be used.

See [Forge getting started](https://developer.atlassian.com/platform/forge/getting-started/)
for platform setup and [the Rovo tutorial](https://developer.atlassian.com/platform/forge/build-a-hello-world-rovo-agent/)
for the underlying app model. For later work, use the relevant specialist skill.
