# Loop 2 — turn the same app into Forge Guru

Read when customization begins. Load each asset when preparing its edit. Keep the existing
registration/runtime. Inspect changes made since Loop 1 before editing.

## Prepare the manifest change

Read [the manifest template](../assets/forge-guru/manifest.yml.tmpl) and manifest/search
sections of [Platform contract](platform-contract.md). The template is a **fragment**, not
a complete manifest: it contains no `app` block or replacement app ID.

Prepare an exact change that:

- Substitutes `{{AGENT_KEY}}` with the inspected stock agent key.
- Sets the display name to Forge Guru and updates description, prompt, starters and action.
- Replaces the stock tutorial action/function with `search-forge-docs` and `index.searchForgeDocs`.
- Adds only `https://developer.atlassian.com` to backend fetch egress.
- Preserves the complete `app` block and unrelated settings/permissions.

If multiple agents or unrelated modules exist, resolve which belongs to the tutorial before
removing anything. Never overwrite an evolved app with the fragment.
Explain that Guru sends its search query to Atlassian's developer-docs host. Briefly mention
[Rovo's usage policy](https://developer.atlassian.com/platform/forge/manifest-reference/modules/rovo-agent/);
do not promise infallible answers.

Show a compact change summary and offer the exact patch. Apply after approval or reuse
explicit approval for the disclosed change. Default to a separate manifest gate; honor a
request to approve both files and dependency installation together.
Parse the YAML, confirm identity/runtime unchanged, and inspect handler wiring.

## Prepare the backend and dependency change

Read [the backend asset](../assets/forge-guru/index.js). It attempts search using Forge fetch,
returns up to three links, and labels fallback responses. The prototype search route is not
an established public API contract; follow the platform-contract probe instructions before
promising live search. Never silently substitute another service or add an egress host.

Explain the replacement handler, validation, results, fallback and `@forge/api` dependency.
Prepare the backend edit and package change together. Show exact files on request. On approval:

1. Replace the tutorial backend with the asset, preserving unrelated code in an evolved app.
2. Read `package.json`. Retain an existing compatible `@forge/api` dependency. If missing,
   obtain its current version with `npm view @forge/api version` and add it under dependencies.
   Preserve unrelated fields/formatting; do not invent or silently upgrade versions.
3. Run `npm install` in the app directory and wait for success. A failed install leaves
   edits pending: report that state and recover, rather than claiming atomic completion.

Check package JSON, dependency resolution, YAML and the action/function/export chain.
Run `forge lint`. Field limits come from the schema, not a blanket 255-character rule.
Short asset strings are a local convention; retain the scaffold's runtime.

## Redeploy and upgrade

Prepare resolved commands and explain the new egress permission. After authorization for
that app/environment/site and permission change, run from the app directory:

```sh
forge deploy --non-interactive -e development
forge install --non-interactive --upgrade --confirm-scopes --site <site-host> --product <product> -e development
```

Read the platform contract's release section. On a CLI supporting rule approval, if the
reviewed change triggers `MAJOR_VERSION_RULE`, the deploy command becomes:

```sh
forge deploy --non-interactive -e development --approve MAJOR_VERSION_RULE
```

Use that flag only for the disclosed, authorized change; never bypass lint with `--no-verify`.
A matching authorization covers a retry. For unexpected rules/permissions, inspect and
resolve the additional impact first. `--confirm-scopes` is not terms or billing consent.

Verify the target with `forge install list --json` and record version/status where available.
Report deploy and upgrade separately; retain partial progress for retries.

On an installation timeout, inspect remote state before repeating the command. If the list
does not expose enough version/status evidence, inspect current CLI options or the app's
Developer Console installation details. Do not report the upgrade complete from site presence
alone. Retry only when evidence establishes an incomplete/transient operation and the same
approval applies. If status remains uncertain, report it and obtain the missing evidence;
do not replay deployment or silently broaden the action.

## See Forge Guru live

Link the site and help the user select Forge Guru. Ask a specific Forge question, then check
whether the answer is useful and its citation supports it. Inspect action output or relevant
logs when provenance is unclear; an answer alone does not prove a fetch.

The backend returns `source: search`, `fallback`, or `empty`. Curated links are navigation
aids, not search matches. If only fallback works, state that live search is unverified or
broken. Use [Recovery](recovery.md); the user may accept a degraded tutorial outcome,
but the completion report must keep that limitation.

For a requested prompt adjustment, prepare and validate before an authorized redeploy.
Use actual lint/deploy results for versioning; do not promise all prompt/module changes
behave identically. Move to `next-steps` after the live check or an explicit choice to stop
with known limitations.
