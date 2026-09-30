# Set up your Atlassian environment and scaffold

Read before registering an app. Reuse choices and authorization from the conversation.
The parent directory and Developer Space are needed for creation; the site is needed for
installation and can be selected now or at the start of Loop 1.

## Choose and inspect targets

1. Resolve the absolute parent directory and proposed `forge-guru/` destination. Offer the
   current workspace when suitable. Include the target in the creation plan. Check whether
   it exists, including a symlink. If it exists, inspect for a resumable app or choose another
   destination with the user. Never remove it to make creation succeed.
2. Explain that a Developer Space owns the app. Narrate and run
   `forge developer-spaces list --json`. Let the user choose among multiple spaces; one space
   can be named in the creation plan. If none exist, link the
   [Developer Console](https://developer.atlassian.com/console/myapps) for them to create one.
3. For installation, use the exact site and product, defaulting to Jira only when the user
   has not selected another supported product. Rovo must be activated. Prefer a development
   site; if they select a work site, explain the real site impact once.

If the user has no site, explain and obtain authorization for `forge site provision`.
It can create an external site; it is not read-only. Read the provision row in
[Platform contract](platform-contract.md), run it, and record returned URL, status and expiry.
Do not infer Rovo activation from a user-supplied URL, promise a permanent site, or
provision/renew merely to inspect progress.

## Verify the sibling helper

Read the sibling [Forge App Builder](../../forge-app-builder/SKILL.md) and its
[creation reference](../../forge-app-builder/references/create-new-app.md) for the scaffold
responsibility delegated here. Onboarding owns tutorial phases, local edits and direct
deploy/install commands. Run this smoke test from the builder skill directory:

```sh
python3 -m scripts.create_forge_app --help
```

Use the verified `python` executable when appropriate. If help fails, inspect the path,
interpreter and error. Explain the concrete issue and stop automated creation until it is
invokable. The user may instead choose the verified interactive path below; its availability
does not depend on the helper. Never substitute agent-run raw `forge create`.

Read the creation section of [Platform contract](platform-contract.md). Use `rovo-agent-rovo`
as this bundle's candidate template; validate with `scripts.list_templates --validate` and
reconcile with official Rovo guidance if results disagree. Never substitute a blank/UI template.

## Make creation and terms consent explicit

Inspect the helper's command construction. At this revision it executes:

```sh
forge create --template rovo-agent-rovo forge-guru --developer-space-id <space-id> --accept-terms
```

The last flag accepts terms non-interactively. Approval to build an app does not authorize
terms or applicable billing consent. Explain the flag and link the
[create command](https://developer.atlassian.com/platform/forge/cli-reference/create/) and
[Forge terms](https://developer.atlassian.com/platform/forge/forge-terms/) for review.
Use the helper only with explicit authorization for that consent and the exact registration.
If current consent wording/effect is unclear, use the user-run path below.

Show the resolved command, directory and Developer Space before execution:

```sh
python3 -m scripts.create_forge_app --template rovo-agent-rovo --name forge-guru --dev-space-id <space-id> --directory "<absolute-parent>"
```

Run from the builder skill directory. This creates files and registers an external app;
it does not deploy or install. After partial failure, inspect the directory and registration
before retrying. The helper currently attributes its calls to `forge-app-builder`.

### User-run interactive alternative

If the user wants to review terms in their terminal, or chooses manual creation while the
helper is unavailable, provide the verified current command without `--accept-terms`, from
the selected parent:

```sh
forge create --template rovo-agent-rovo forge-guru --developer-space-id <space-id>
```

The user handles terms/billing prompts themselves. This is an intentional user-run handoff;
do not execute it through the agent's shell. Wait for completion, then verify the files.

## Verify and advance

Inspect the manifest, `package.json` and `src/`. Confirm a registered `app.id`, `rovo:agent`,
action/function wiring and handler file. Record the actual key/name and runtime.
The app name, folder, module key, display name and app ID are distinct; never teach that
`forge-guru` is the immutable app ID or assume creation renamed the template's agent.

For missing files, preserve the directory and use [Recovery](recovery.md). A partial scaffold
can already have an external registration. Never delete/recreate by default.
Once verified, continue to `hello-world`. Keep generated source and manifest unchanged.
