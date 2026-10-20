# Build — scaffold, customize, deploy, install

Read when the `setup` bundled authorization has been granted. Run the four steps below
back-to-back with one-line status narration — no further "ready?" prompts between them.
On failure, go to [Recovery](recovery.md) and resume at the failed step.

Status line template per step:

```
→ Scaffolding Forge app from Rovo Agent template…      ✓
→ Customizing into Forge Guru…                          ✓
→ Deploying to development…                             ✓
→ Installing on <site>…                                 ✓
```

## 1. Scaffold

Resolve the parent directory and Developer Space from the session record. Verify the
destination does not already contain an app. Run the sibling helper from the
`forge-app-builder` skill directory:

```sh
python3 -m scripts.create_forge_app --template rovo-agent-rovo --name forge-guru --dev-space-id <space-id> --directory "<absolute-parent>"
```

This registers an external app and writes files; it does not deploy or install. The helper
appends `--accept-terms` — that consent was disclosed and granted at setup. Record the
registered `app.id`, runtime, agent key, and handler name from the generated manifest.

After scaffold, inspect `manifest.yml`, `package.json`, and `src/`. Confirm `app.id`,
`rovo:agent`, action/function wiring, and the handler file exist. If anything is missing,
preserve the directory and jump to [Recovery](recovery.md).

## 2. Customize into Forge Guru

Apply the Guru assets to the scaffolded app verbatim — no per-user edits.

- Replace `src/index.js` with [`assets/forge-guru/index.js`](../assets/forge-guru/index.js).
- Merge [`assets/forge-guru/manifest.yml.tmpl`](../assets/forge-guru/manifest.yml.tmpl)
  into the generated `manifest.yml`:
  - Substitute `{{AGENT_KEY}}` with the agent key recorded above.
  - Replace the stock `rovo:agent`, `action`, and `function` entries with the template's.
  - **Preserve** the entire `app` block, runtime, and unrelated settings.
- Install dependencies:

  ```sh
  npm install
  ```

- Validate:

  ```sh
  forge lint
  ```

Resolve lint errors before continuing. Do not bypass with `--no-verify`.

## 3. Deploy

From the app directory:

```sh
forge deploy --non-interactive -e development
```

Apply onboarding attribution. On CLI 13.3+, if the disclosed change triggers
`MAJOR_VERSION_RULE`, append `--approve MAJOR_VERSION_RULE`. Use that flag only for the
authorized change; never bypass lint.

## 4. Install

From the app directory:

```sh
forge install --non-interactive --site <site-host> --product <product> -e development
```

Use the site and product collected at setup. Default product is Jira unless the user
chose another supported product. Verify installation with:

```sh
forge install list --json
```

Record app context, site/product/environment, and version/status. Report deploy and
install separately; retain partial progress for retries.

On an installation timeout, inspect remote state before repeating the command. Do not
report install complete from site presence alone. Retry only when evidence establishes an
incomplete or transient operation and the same authorization applies.

## Advance

When all four steps succeed, continue to [`celebrate`](celebrate.md). Do not pause for
user confirmation between install and celebrate — the celebration *is* the completion report.
