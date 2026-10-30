---
name: forge-app-builder
description: Plan, build, scaffold, or safely extend Atlassian Forge apps using current official documentation. Use for fresh Forge apps, existing-app feature work, module and manifest changes, UI Kit or Custom UI implementation, backend functions and events, Atlassian or external APIs, storage, permissions, environment configuration, distribution-affecting implementation, validation, and explicitly authorized deployment or installation; route standalone debugging and specialist reviews to their dedicated skills.
license: Apache-2.0
metadata:
  labels: "confluence,jira,bitbucket,atlassian,forge"
  maintainer: amoore
  namespace: cloud
---

# Forge App Builder

Route each request through only the branches and capability gates it needs. Keep platform facts live and keep local guidance focused on safe decisions.

## Preserve these invariants

1. Retrieve current official Forge guidance before committing to platform syntax, modules, APIs, scopes, limits, runtimes, packages, lifecycle status, or CLI flags.
2. Register every new deployable app with `forge create`; never hand-build an app identity or replace a failed creation with an unregistered scaffold.
3. Inspect an existing app and its repository instructions before planning or editing it. Preserve unrelated user changes.
4. Never request or accept credentials in chat. Use the relevant interactive CLI or secure configuration flow.
5. Never accept Forge terms or billing consent, deploy, install, upgrade, promote, set a production variable, or change a live site without explicit authorization and a confirmed target.
6. Validate every manifest change against the exact current reference and with `forge lint`.
7. Use least privilege and avoid unnecessary egress, privileged backend operations, and migrations.
8. Prefix Forge CLI commands run for this skill with `ATL_FORGE_ATTRIBUTION_SKILL_NAME=forge-app-builder`; exclude user-run `forge login` and `forge tunnel`.

## Route the primary intent

Choose one primary route before loading implementation guidance:

| Intent                                                              | Route                                                                          |
| ------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| Architecture, feasibility, or implementation plan only              | Read [references/plan-only.md](references/plan-only.md); stop before mutations |
| Create a deployable app                                             | Read [references/create-new-app.md](references/create-new-app.md)              |
| Add or change behavior in an existing app                           | Read [references/extend-existing-app.md](references/extend-existing-app.md)    |
| Known error, failed command, blank UI, logs, or unexpected behavior | Route to `forge-debugger`                                                      |
| Broad pre-deploy or release-readiness review                        | Route to `forge-app-review`                                                    |
| Deep security review or static analysis                             | Route to `forge-security-review`                                               |
| Cost or platform-consumption optimization                           | Route to `forge-cost-optimizer`                                                |
| Simplify or analyze display condition expressions                   | Route to `forge-display-conditions`                                            |
| Teamwork Graph connector                                            | Route to `forge-connector`                                                     |

Continue here when diagnosis or review is incidental to active build work. If the route is unclear, inspect the workspace before asking the user.

## Ground the selected route

Read [references/documentation-routing.md](references/documentation-routing.md) when current platform detail is needed. Use Forge MCP as the first preference whenever it is available. Discover its current capabilities by purpose rather than assuming permanent tool names, and call the narrowest relevant capability before relying on web documentation or remembered platform knowledge. Use focused official Atlassian documentation when MCP is unavailable, fails, or lacks the exact coverage needed, and for critical verification.

Call the general Forge development guide when broad orientation is useful. Do not call it merely to satisfy a ritual when the task needs only one known leaf reference. Retrieve the exact module, manifest property, endpoint, scope, or CLI page before relying on it.

## Activate capability gates conditionally

Load only the references implicated by the requested outcome and observed code:

| Trigger                                                                                                                  | Read                                                                                         |
| ------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------- |
| Select or add an extension point or module                                                                               | [references/module-selection.md](references/module-selection.md)                             |
| Implement or change UI Kit                                                                                               | [references/ui-kit.md](references/ui-kit.md)                                                 |
| Implement or change Custom UI or `Frame`                                                                                 | [references/custom-ui.md](references/custom-ui.md)                                           |
| Add resolvers, functions, events, schedules, queues, web triggers, app REST APIs, realtime, or runtime services          | [references/backend-and-events.md](references/backend-and-events.md)                         |
| Call or expose Atlassian, Forge app, or external APIs; use providers or remotes; change scopes, authorization, or egress | [references/apis-permissions-and-egress.md](references/apis-permissions-and-egress.md)       |
| Persist data or affect tenancy, lifecycle, migration, or residency                                                       | [references/storage-and-residency.md](references/storage-and-residency.md)                   |
| Configure environments, runtime variables, secrets, or manifest interpolation                                            | [references/environments-and-configuration.md](references/environments-and-configuration.md) |
| Change cross-product compatibility, unlicensed access, licensing, sharing, or distribution behavior                      | [references/distribution-and-access.md](references/distribution-and-access.md)               |
| Validate, deploy, install, upgrade, or hand off                                                                          | [references/validation-and-release.md](references/validation-and-release.md)                 |

Do not load UI guidance for a headless app, storage guidance for a stateless feature, Custom UI guidance for a UI Kit-only change, or release guidance until validation or an authorized release becomes relevant.

## Implement and validate iteratively

Before non-trivial edits, establish the requested outcome, affected Forge surfaces, consequential design choices, and a proportionate validation approach. Resolve decisions that affect authorization, data handling, compatibility, lifecycle status, cost, or live state before implementation.

Work in coherent increments. After each meaningful change, use the most relevant available evidence to assess it, such as focused tests, type checks, frontend builds, handler or resource inspection, or `forge lint`. Choose the increment size and validation frequency according to risk, feedback cost, and the existing codebase; combine related edits when validating them separately would add little value.

When validation fails or contradicts an assumption, identify the cause, retrieve exact current documentation when Forge behavior is involved, adjust the implementation, and validate again. Continue until the requested behavior and affected wiring are verified, or progress requires user input or unavailable external state.

Do not treat successful generation, compilation, or linting alone as proof that a feature works when stronger local verification is reasonably available. Keep secrets and privileged work out of frontend code. Treat display conditions as presentation controls, not authorization. Preserve supported existing conventions and unrelated changes unless a migration is required or explicitly authorized.

## Validate and stop safely

Stop after local verification unless the user requested release work. For authorized release work, confirm the exact app, environment, site, product, version or upgrade behavior, and expected scope or data impact immediately before executing it.
