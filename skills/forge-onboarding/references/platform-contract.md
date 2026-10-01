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
| Rovo template | [Rovo tutorial](https://developer.atlassian.com/platform/forge/build-a-hello-world-rovo-agent/). It uses interactive label `rovo-agent`; the bundle's candidate slug is `rovo-agent-rovo`. Reconcile installed CLI/registry results instead of declaring either permanently correct. CLI 10.8.0 is the tutorial's template minimum, not a guarantee all recipes work there. |
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

## Guru search dependency

The inherited prototype uses `https://developer.atlassian.com/gateway/api/search/` with `q`
and `site=developer`. This is not established here as a supported public API. Verify its
shape before claiming live search; templates are not evidence. A web-reader error alone
also cannot diagnose the backend endpoint.

At the 2026-10-01 refactor check, an HTTP GET using the synthetic query `forge issue panel`
returned **404** with an HTML content type. The inherited integration therefore did not
pass its live-search check. Disclose this known limitation before offering Loop 2; a future
successful probe can update the session evidence, but do not assume the route has recovered.

Before customization, probe with a synthetic, non-sensitive Forge question using an HTTP
client. Check status, JSON, the results array and usable official documentation URLs.
Never send user work data as a probe. Record the result, then test the deployed action:
local HTTP success does not prove Forge egress/execution.

On HTTP error, invalid JSON or unexpected schema, retain visible fallback and disclose the
limitation before customization approval. Investigate supported sources through official
docs if useful; do not silently change integrations or claim live search succeeded.
The user may continue with curated links or stop after Loop 1. Fallback must stay
distinguishable in returned data and the completion report.

## Wider platform claims

Use [Forge](https://developer.atlassian.com/platform/forge/),
[Rovo modules](https://developer.atlassian.com/platform/forge/manifest-reference/modules/rovo-index/)
and [Teamwork Graph](https://developer.atlassian.com/platform/teamwork-graph/) for specific
questions. Verify lifecycle per feature; do not group all capabilities under one status.
