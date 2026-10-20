# Platform facts and verification

Read the relevant section when platform syntax or behavior matters. This file owns source
links and compatibility notes; phase references own command recipes. Do not duplicate
version/limit claims throughout the workflow or treat this as an immutable specification.

Prefer available Forge MCP capabilities, discovered by purpose. If unavailable/insufficient,
use focused official sources and the installed CLI's help/schema. Record version and evidence
in session context; reuse unchanged facts during the session. Resolve disagreements before
consequential commands. Never claim a successful MCP lookup when none occurred.

## Setup and creation

| Topic | Evidence and decision |
| --- | --- |
| Node/CLI | [Getting started](https://developer.atlassian.com/platform/forge/getting-started/). At the 2026-10-01 refactor check, docs support Node 22.x and 24.x. Compare exact releases, not just a minimum major. |
| Rovo template | [Rovo Agent module reference](https://developer.atlassian.com/platform/forge/manifest-reference/modules/rovo-agent/). The interactive CLI label is `rovo-agent`; the bundle's candidate slug is `rovo-agent-rovo`. Reconcile installed CLI/registry results instead of declaring either permanently correct. CLI 10.8.0 is the template minimum, not a guarantee all recipes work there. |
| Create and consent | [Create CLI](https://developer.atlassian.com/platform/forge/cli-reference/create/). Inspect the helper too: this revision appends `--accept-terms` and stamps builder attribution. Both are execution effects. |
| Developer Spaces | [Create a space](https://developer.atlassian.com/platform/forge/developer-space/create-developer-space/). Use the actual list; do not assume a personal space always exists. |
| Demo sites | [Site provision CLI](https://developer.atlassian.com/platform/forge/cli-reference/site-provision/) and [demo site guide](https://developer.atlassian.com/platform/forge/provision-a-demo-development-site/). Provisioning can create a site. Use returned status/expiry; do not promise indefinite availability or invent a site-list command. |

## Manifest and release

| Topic | Evidence and decision |
| --- | --- |
| Agent fields | [Rovo Agent](https://developer.atlassian.com/platform/forge/manifest-reference/modules/rovo-agent/). Validate each field; do not impose a universal 255-character maximum. Short template strings are a local convention. |
| Actions | [Action reference](https://developer.atlassian.com/platform/forge/manifest-reference/modules/rovo-action/). Check verb, inputs and action/function/handler mapping. Teach from the actual scaffold. |
| Egress/fetch | [Runtime egress](https://developer.atlassian.com/platform/forge/runtime-egress-permissions/) and [fetch API](https://developer.atlassian.com/platform/forge/runtime-reference/fetch-api/). Queries leave the function for the declared host. Never add hosts/scopes speculatively. |
| Lint/deploy | [Deploy CLI](https://developer.atlassian.com/platform/forge/cli-reference/deploy/). Validate locally; deploy also checks. Documented `--approve` support starts at CLI 13.3. Do not pass it blindly on older versions, invent rules or bypass validation. |
| Install/upgrade | [Install CLI](https://developer.atlassian.com/platform/forge/cli-reference/install/). Resolve site/product/environment. Upgrade updates an installation; confirm-scopes acknowledges permissions. Inspect state after success or duplicate-install errors. |

## Guru answer source

Forge Guru answers from a curated set of official Forge documentation links, picked by
topic match against the user's question (see
[`assets/forge-guru/index.js`](../assets/forge-guru/index.js)). There is no outbound HTTP
call at runtime, so there is no live-search endpoint to fail. Extending Guru to richer
sources is a legitimate future step; adding external fetch would require declared egress
permissions and a separately authorized change.

## Wider platform claims

Use [Forge](https://developer.atlassian.com/platform/forge/),
[Rovo modules](https://developer.atlassian.com/platform/forge/manifest-reference/modules/rovo-index/)
and [Teamwork Graph](https://developer.atlassian.com/platform/teamwork-graph/) for specific
questions. Verify lifecycle per feature; do not group all capabilities under one status.
