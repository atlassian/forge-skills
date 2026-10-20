# Forge onboarding

A guided first Forge project: scaffold, customize, deploy, and install **Forge Guru** —
a Rovo Agent that lives on your developer site and answers any Forge question you throw
at it — in about 10 minutes, with a single authorization gate up front.

Forge has many module types for extending Jira, Confluence, Bitbucket, and more. This
skill focuses on the **Rovo Agent** module. By the end you'll have a conversational
agent on your test site that you can keep using as your personal Forge guide while you
build your first real app.

Try "onboard me to Forge", "build my first Rovo Agent", or "resume Forge onboarding".
You can skip explanations, reuse an existing setup, pause, or exit.

## How the flow runs

1. **Welcome** — a short intro to Forge, Rovo Agents, and what you're about to build.
2. **Setup** — tool and login checks, pick your Developer Space and test site, approve
   the full build plan once. This is the only consent gate.
3. **Build** — scaffold, customize into Guru, deploy, install. One continuous run with
   status updates; no further prompts.
4. **Celebrate** — a direct link to find Guru on your site, plus example prompts to try.
5. **Next steps** — the Forge iteration loop and sibling-skill routes for whatever you
   want to build next.

## Instructions and resources

[SKILL.md](SKILL.md) is the authoritative workflow entry point. It routes to phase
references only when needed. This README is an overview; command recipes and consent
rules live in the workflow.

- [References](references/) contain setup, build, celebrate, next-steps, recovery, and
  platform-contract guidance.
- [Guru assets](assets/forge-guru/) contain the manifest fragment and backend source
  the skill applies to the scaffolded app. See the assets'
  [README](assets/forge-guru/README.md) for how they fit together.

Install `forge-onboarding` together with `forge-app-builder` from the
[Forge Skills bundle](https://github.com/atlassian/forge-skills). The builder supplies
the scaffolding helper that onboarding delegates to. Onboarding invokes deployment and
installation directly after the one bundled authorization.

See [Forge getting started](https://developer.atlassian.com/platform/forge/getting-started/)
for platform setup and the
[Rovo Agent module reference](https://developer.atlassian.com/platform/forge/manifest-reference/modules/rovo-agent/)
for the underlying app model. For later work, use the relevant specialist skill.
