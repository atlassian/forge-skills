---
name: forge-onboarding
description: Guide a first-time Forge builder through building Forge Guru, a Rovo Agent that answers Forge questions. Use for Forge onboarding, a first Forge or Rovo app, or resuming this tutorial. Route unrelated existing-app changes, debugging, reviews, and connector work to the specialist skills.
license: Apache-2.0
metadata:
  labels: "confluence,jira,atlassian,forge,onboarding,rovo,agent"
  maintainer: amoore
  namespace: cloud
---

# Forge onboarding

Guide a first-time builder from zero to a deployed, installed Rovo Agent — **Forge Guru** —
in one continuous run. One intro, one setup gate, one build. Keep the agent concise;
self-service readers get a strong welcome up front, workshop attendees get a slide-friendly flow.

## Load guidance by phase

Read only the reference for the current phase. Do not preload the entire journey, README,
assets, or evaluation cases. Use these stable phase names in state and transitions.

| Phase | Read when | Reference | Evidence to advance |
| --- | --- | --- | --- |
| `welcome` | Starting a new guided session | Use the welcome script below | User says they are ready to begin |
| `setup` | Beginning a new run (or a tool/login failure) | [Setup](references/setup.md) | Tools and login verified; dev space, test site, and app directory collected; bundled authorization granted |
| `build` | Running the end-to-end build | [Build](references/build.md) | Scaffold, customize, deploy, and install all succeeded on the authorized target |
| `celebrate` | Reporting success | [Celebrate](references/celebrate.md) | User knows where to find Guru and has example prompts to try |
| `next-steps` | Closing the tutorial | [Next steps](references/next-steps.md) | Iteration loop and sibling-skill routes shared |
| Recovery | An observed failure needs investigation | [Recovery](references/recovery.md) | Failure resolved or concrete blocker reported |
| Platform check | A phase needs current CLI, schema, or endpoint facts | [Platform contract](references/platform-contract.md) | Relevant fact verified and evidence recorded |

Default transition: `welcome → setup → build → celebrate → next-steps`.
Recovery returns to the interrupted phase. An exit stops the workflow immediately.

## Keep a compact session record

Retain these values in conversation context, updating them after meaningful actions:

| State | Record |
| --- | --- |
| Position | Phase, last completed action, next action |
| Local environment | OS/shell, Node and CLI versions, authentication result, accepted warnings |
| Local target | Absolute parent directory and app path; whether destination existed before creation |
| Atlassian target | Account, Developer Space name/ID, exact site, product, environment |
| Identity | Registered `app.id`, runtime, actual agent key/name, handler and action names |
| Progress | Scaffold created; Guru assets applied; dependencies installed; lint result; deploy and install confirmed |
| Live evidence | Guru answered a real Forge question; link to the agent on the site |
| Authorization | The single bundled authorization: exact approved actions, targets, and impacts |

Do not store credentials. Do not create a progress file unless the user requests one.

### Skip, exit, and resume

- Honor "skip the intro", "less explanation", and "exit".
- The `welcome` and `setup` gates are the only user-visible pauses in the default flow.
  Do not add further "ready?" prompts between read-only checks or between `build` steps.
- When resuming, reuse known results. Run only missing checks needed for the next command.
  A version warning is not a failed executable: explain it once and honor the user's choice.
- Collect targets at `setup`. The test site is required because `build` installs Guru.
  If the user has no site, follow the provision path in [Setup](references/setup.md).
- Skipping teaching does not supply credentials, select ambiguous targets, accept terms,
  or authorize deployment or installation.
- On exit, stop tools and questions. Briefly state what changed and what remains, using
  recorded evidence. Do not keep offering the next tutorial step.
- On resume, reuse context and inspect the app. Check identity and installation as relevant.
  Never rerun scaffolding over an existing app or replay completed edits, installs, consent,
  or lessons without a reason.

## Preserve execution boundaries

1. Narrate each step briefly as it runs. One line per command during `build`; batch
   explanations for independent checks. Report observed results, not anticipated success.
2. Keep secrets out of chat and files. Login and unexpected credential prompts go to the
   user's interactive terminal; never ask them to paste an API token here.
3. **One bundled authorization.** At the end of `setup`, disclose the full scope — scaffold
   at the exact directory, apply the Guru assets, deploy to `development`, install on the
   exact site — and get approval once. After approval, run all four actions in `build`
   without re-prompting. Local walkthroughs and read-only checks need no extra gate.
4. Terms and billing consent are separate from "build my app". The sibling creation helper
   currently passes `--accept-terms`. Disclose this as part of the bundled authorization;
   do not treat scaffold consent as independent of terms consent.
5. Register apps through `forge create` (via the sibling helper). Never invent an app ID
   or an unregistered replacement.
6. Default to `development` and state it in environment-sensitive commands. A development
   environment does not make real site data harmless; prefer a test site and minimal
   permissions. A different environment/site requires a separately scoped decision.
7. Preserve user files and app identity. Inspect the destination before scaffolding. Never
   delete a failed scaffold, overwrite an existing directory, or recreate an app without
   confirming the exact target and consequences. Preserve partial output for diagnosis.
8. Validate against current official guidance and `forge lint` before deploy. Read the
   relevant platform-contract section when needed; do not invent universal limits, treat
   old pinned facts as permanent, or repeat unchanged lookups in one session.
9. Do not perform unrequested source-control operations. This tutorial requires no commit,
   push, or initialization; read-only inspection can support preservation.
10. Deploy and install do not prove Guru works. Record the live Guru answer in `celebrate`
    as separate evidence from a successful install.

## Dependencies and attribution

The sibling `forge-app-builder` supplies `scripts.create_forge_app`. Before scaffolding,
run its `--help` smoke test and follow its creation reference as directed by the setup phase.
Python is needed for this helper; use `python3` or the verified local `python` executable.
Do not install dependencies merely to greet the user.

Set `ATL_FORGE_ATTRIBUTION_SKILL_NAME=forge-onboarding` for direct agent-run Forge commands.
Use an environment mapping when supported; otherwise use the user's shell syntax from
[Setup](references/setup.md#attribution). A persistent shell can export it once; fresh shells
must receive it each time. Exclude user-run login commands.
The sibling helper currently tags its calls `forge-app-builder`; do not claim the caller's
tag survives that helper or modify another skill's behavior as part of a tutorial run.

## Welcome script

Open a new guided session with this intro (roughly 150 words — concise, but strong enough
for a self-service reader with no slides). Adapt wording naturally; keep the beats in order.

> **Welcome to Forge onboarding.** Forge is Atlassian's platform for building apps that
> extend Jira, Confluence, Bitbucket, and more — no servers for you to manage. Forge has
> many module types for different kinds of extensions; today we're focused on the
> **Rovo Agent** module, which lets you build conversational agents that live inside
> Atlassian products.
>
> You're going to build **Forge Guru** — a Rovo Agent that lives on your developer site
> and answers any Forge question you throw at it. Think of it as your personal Forge
> guide while you build your first real Forge app.
>
> Here's the whole flow: I'll check your environment, collect your developer space and
> test site, then scaffold, customize, deploy, and install Guru end-to-end — about
> 10 minutes. After you approve the plan at setup, I'll run through the build without
> stopping. Everything happens on a test site; nothing touches real data or billing.
>
> **Ready to begin?**

Ask the readiness question only once, here. Do not repeat it later.

## Teach concisely

After the welcome, keep narration tight. One line before each command. Short status lines
during `build` ("Scaffolding…", "Deploying…"). No mid-flow concept lessons; if the user
asks "what is X" or "what did it just do", answer briefly and return to the flow.
End questions with a clear reply hint; do not add a question to every update.

## Completion and handoff

Default success is Forge Guru deployed and installed on the user's test site, answering a
real Forge question with a usable official link. Be explicit if a live check was skipped.
Guru remains available subject to the site's lifetime and app installation, not "forever".

Use `forge-app-builder` for subsequent feature work, `forge-debugger` for sustained diagnosis,
`forge-app-review` for release review, and `forge-connector` for connector work. Read
[Next steps](references/next-steps.md) when closing or discussing those routes.
