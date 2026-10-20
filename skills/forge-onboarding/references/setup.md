# Setup — environment, targets, and the one authorization

Read at the start of a run, or when a tool/login failure interrupts a later phase. On
"skip setup" during resume, reuse known results and run only checks required for the
next operation.

## 1. Verify the local environment

Explain and run these read-only checks, independently where practical:

```sh
node -v
forge --version
forge whoami
```

Apply the attribution env var below to agent-run Forge commands. Detect shell/OS from
the host; if unknown and Node works, `node -e "console.log(process.platform)"` can confirm.
Do not print token values or inspect credential stores.

Compare versions with the setup row in [Platform contract](platform-contract.md).
Distinguish a warning (exit 0) from a failed command. If the user accepts a warning and
asks to continue, record it and move on.

If a required tool is missing or login failed, use [Recovery](recovery.md). The usual
CLI repair is `npm install -g @forge/cli@latest`. For login, have the user run
`forge login` in their own terminal and rerun `forge whoami` after.

Python is needed for the sibling creation helper. Probe `python3 --version` or
`python --version`; do not install both.

## 2. Collect the targets

Everything the build needs, gathered now so build can run uninterrupted:

- **Parent directory** for the app. Resolve an absolute path; propose `forge-guru/` as
  the destination. Check whether it exists (including symlinks). If it exists, inspect
  for a resumable app or choose another destination with the user. Never remove it to
  make scaffolding succeed.
- **Developer Space.** Run `forge developer-spaces list --json` and let the user choose
  if there are multiple. If none exist, link
  [Developer Console](https://developer.atlassian.com/console/myapps) and wait.
- **Test site** (required — install needs it). Use a site where Rovo is activated. Prefer
  a dedicated development site. If the user has no site, explain and obtain authorization
  for `forge site provision`; read the provision row in
  [Platform contract](platform-contract.md), run it, and record the returned URL, status,
  and expiry. Do not promise a permanent site.
- **Product.** Default to Jira unless the user picked another supported product.

## 3. Verify the sibling helper

The scaffold runs through `forge-app-builder`'s creation helper. Smoke-test it once from
the builder skill directory:

```sh
python3 -m scripts.create_forge_app --help
```

If help fails, inspect path/interpreter and either resolve or jump to [Recovery](recovery.md).
Never substitute agent-run raw `forge create`.

Use `rovo-agent-rovo` as the template slug. Validate with
`scripts.list_templates --validate` and reconcile with official Rovo guidance if results
disagree. Never substitute a blank or UI template.

## 4. Get the one bundled authorization

Disclose the full build scope once and get approval. Example wording:

> I'm about to do the following, in sequence, without pausing between steps:
>
> 1. **Scaffold** a new Forge app at `<absolute-parent>/forge-guru` under Developer
>    Space `<space-name>`. This registers an external app and accepts the Forge terms
>    non-interactively via `--accept-terms`.
> 2. **Customize** it into Forge Guru by replacing the generated manifest and backend
>    with the Guru assets.
> 3. **Deploy** to the `development` environment.
> 4. **Install** on `<site-host>` for `<product>`.
>
> After you approve, I'll run all four and report progress as I go. Approve?

Record the authorization against this exact scope. If any target changes later, re-ask.
Terms consent is disclosed here as part of step 1 — do not treat it as implicit.

## Attribution

| Shell | Syntax |
| --- | --- |
| bash/zsh | `export ATL_FORGE_ATTRIBUTION_SKILL_NAME=forge-onboarding` |
| PowerShell | `$env:ATL_FORGE_ATTRIBUTION_SKILL_NAME = "forge-onboarding"` |
| CMD | `set ATL_FORGE_ATTRIBUTION_SKILL_NAME=forge-onboarding` |

For a fresh POSIX shell, an inline assignment like
`ATL_FORGE_ATTRIBUTION_SKILL_NAME=forge-onboarding forge whoami` is valid. The sibling
creation helper uses its own builder tag; see the main skill's dependency rule.

## Advance

With tools verified, targets collected, and the bundled authorization recorded, move
directly to [`build`](build.md).
