# Forge Guru assets

These files are applied verbatim by the `forge-onboarding` skill during the `build` phase
to turn a freshly scaffolded Rovo Agent app into **Forge Guru**.

## Files

- **`manifest.yml.tmpl`** — a manifest **fragment** (not a complete manifest). The
  onboarding skill merges it into the scaffolded `manifest.yml`, substituting
  `{{AGENT_KEY}}` with the generated agent key and preserving the `app` block, runtime,
  and any unrelated settings.
- **`index.js`** — the backend for the `search-forge-docs` action. Given a user question,
  it returns three curated official Forge documentation links scored against the query.
  The Rovo Agent prompt instructs the LLM to use these links as the source of truth when
  answering, so Guru's answers stay grounded in real docs.

## Design notes

- **No external HTTP egress.** Guru does not call any search endpoint; the backend is a
  pure function over a curated link set. That means no `permissions.external.fetch`
  entries are needed, and there is no live-search dependency that can fail at runtime.
- **Three links, always.** Even if no topic matches, the top three generic entries win,
  so Guru never returns an empty result.
- **Easy to extend.** Add entries to the `all` array in `index.js` to teach Guru about
  more Forge topics. Each entry needs a `title`, `url`, and `topics` array of lowercase
  keywords.

## Changing Guru after the tutorial

The whole point of onboarding is leaving you with a working app you can keep iterating
on. To change what Guru knows about, edit `src/index.js` in your scaffolded app, run
`forge deploy -e development`, and refresh the agent in Rovo. No reinstall needed for
prompt or handler changes.
