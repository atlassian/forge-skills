# Set up your local machine

Read when prerequisites are unknown or a command fails because a tool or login is missing.
On "skip setup", reuse known results and run only checks required for the next operation.

## Inspect before changing anything

Explain and run these read-only checks, independently where practical:

```sh
node -v
forge --version
forge whoami
```

Apply the attribution environment below to agent-run Forge commands. Detect shell/OS from
the host; if unknown and Node works, `node -e "console.log(process.platform)"` can confirm OS.
Do not print token values or inspect credential stores.

Read the setup row in [Platform contract](platform-contract.md) to compare actual versions
with supported releases. "Node ≥22" is insufficient: a newer release may be unsupported.
Distinguish a warning with exit code 0 from a failed command.

If the user accepts a warning and asks to continue, record that choice and proceed. Do not
install another Node version or keep asking about it unless a relevant command fails.

## Repair an actual missing prerequisite

Explain the proposed change and use existing authorization for it, or ask before changing
global tools. Use the official OS-specific setup instructions in the platform contract.
Inspect an existing version manager before proposing an installation or changing defaults.
If the CLI is missing or cannot support the required command, the usual install is:

```sh
npm install -g @forge/cli@latest
```

Recheck only the repaired prerequisite. Python is required when scaffolding through the
sibling helper, not for teaching. Probe `python3 --version` or `python --version` when
creation becomes relevant; do not install both.

If authentication is missing, have the user run `forge login` in their own terminal.
Point them to [Atlassian API tokens](https://id.atlassian.com/manage-profile/security/api-tokens)
if needed. Never collect the email/token pair in chat or feed credentials through tools.
After they finish, rerun `forge whoami` and record the account.

## Attribution

This variable attributes direct agent-run CLI calls to onboarding. Set it once only if the
shell persists; otherwise supply it in each command's environment.

| Shell | Syntax |
| --- | --- |
| bash/zsh | `export ATL_FORGE_ATTRIBUTION_SKILL_NAME=forge-onboarding` |
| PowerShell | `$env:ATL_FORGE_ATTRIBUTION_SKILL_NAME = "forge-onboarding"` |
| CMD | `set ATL_FORGE_ATTRIBUTION_SKILL_NAME=forge-onboarding` |

For a fresh POSIX shell, an inline assignment such as
`ATL_FORGE_ATTRIBUTION_SKILL_NAME=forge-onboarding forge whoami` is valid.
Do not paste POSIX assignments into PowerShell or assume environment changes survive a tool call.
The sibling creation helper uses its own builder tag; see the main skill's dependency rule.

## Transition

Report versions and authenticated identity compactly. Continue to `orientation`, or directly
to `scaffold` if teaching was skipped. If a required executable or login still fails, explain
that concrete blocker; do not label the environment ready.
