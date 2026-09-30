# Loop 1 — ship and use the stock agent

Read after scaffold verification. Resume at the first incomplete action; never register
another app. Read files from disk so teaching matches the actual template.

## Understand the stock files

If teaching is wanted, describe `manifest.yml`: the actual name/prompt, action, function
handler, permissions, runtime and identity. Link the file. Then describe `src/index.js`:
handler, inputs, return value and observed logging/network behavior. Do not assume a
`hello` function, empty inputs, no imports, or a particular line count.

Offer detail when asked; "skip the walkthrough" moves directly to preparation.
Never annotate/rewrite stock code to make it match a teaching example.

## Prepare deployment

Collect the exact site if missing using
[Environment and scaffold](environment-and-scaffold.md). Record product/environment.
Inspect dependencies and install them from the app directory when needed:

```sh
npm install
forge lint
```

Explain npm's possible changes to dependencies and the package lock. Do not assume deploy
installs missing packages. Read the release rows in [Platform contract](platform-contract.md)
before relying on flags. Resolve lint errors before requesting release authorization.

Explain: deployment uploads a version to Forge; installation connects it to a product/site.
The development environment is separate from production but still accesses the selected site.

## Deploy and install

Show the real app, site, product, environment, commands and permission impact. Obtain
authorization if those actions/targets have not already been approved. One approval can
cover both commands; do not ask again between approved commands. From the app directory,
run each only after the previous succeeds:

```sh
forge deploy --non-interactive -e development
forge install --non-interactive --site <site-host> --product <product> -e development
```

Apply onboarding attribution and quote resolved arguments. Do not add upgrade/scope flags
to a first install by habit. If the generated app needs permissions, disclose them and use
only flags supported by the installed CLI and authorized by the user.

If the CLI needs an environment name or unexpected terms, stop that command and resolve
the prompt. Do not invent values or accept terms; use [Recovery](recovery.md).

Narrate and run read-only `forge install list --json` after success. Verify app context,
site/product/environment and version/status where available. "Already installed" needs
the same check; it does not prove the expected version is installed.
Record deployment and installation separately and report success only when evidence agrees.

## See Hello World live

Link the site. Guide the user to Rovo Chat, its agent selector and the actual display name.
Use its real starter or an input that invokes the declared action. If it logs a message,
verify it with `forge logs -e development`. A conversational reply alone does not prove the
handler ran.

If absent, inspect installation and Rovo activation, refresh and allow propagation.
Consult current UI guidance if navigation differs.

Ask whether the action worked. Once observed, explain:
message → agent chooses action → Forge executes handler → result returns to Rovo.
Mark the checkpoint observed, or unverified if explicitly skipped.
Continue to `guru` when the user wants to customize; questions do not restart the flow.
