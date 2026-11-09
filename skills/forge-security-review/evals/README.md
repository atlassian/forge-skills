# Evals for the deterministic layer

Fixtures are small but complete Forge projects (a `manifest.yml` plus `src/` and `static/`) that
exercise the OpenGrep rules in `../assets/opengrep-rules/forge-security-rules.yaml`. Each vulnerable
fixture has a safe twin written the way the skill's own rule files recommend, so the rules are
checked for recall and for silence at the same time.

| Fixture | Purpose | Expectation |
| --- | --- | --- |
| `fixtures/core/vulnerable` | One app with resolvers, web triggers, a lifecycle hook, UI Kit, Custom UI and a manifest that plants the target of the SDK-level rules: tainted `asApp()`, fetch, `assumeTrustedRoute` and `invokeRemote` paths, raw SQL, JQL, storage keys, secrets, sandbox escapes, HTML sinks, web trigger authentication, module-scope state and anonymous access | The rules named in the comments fire |
| `fixtures/core/safe` | The same features written safely (`asUser()`, `route` templates, HMAC-verified web triggers, scoped storage keys, no module-scope request state, exact egress hosts, no script CSP relaxation) | No findings |
| `fixtures/extended/vulnerable` | Authorization and manifest classes: payload fallbacks for context identifiers, payload identity trusted for authorization, JQL in POST bodies, payload merges, headers from the payload, literal web trigger secrets, a private cross-tenant API, bridge data into HTML sinks, Bitbucket bot credentials, wildcard and tunnel egress, unsafe script CSP directives, unguarded installation-wide writes, model output driving a merge | The remaining rules fire |
| `fixtures/extended/safe` | Context-only identifiers that fail closed, a permission check before installation-wide writes, schema-validated and allowlisted settings, constant headers, HMAC-verified web trigger, React escaping instead of HTML sinks, exact egress hosts, only style `unsafe-inline` | No findings |

Between them the two vulnerable fixtures trigger every rule in the file; the test fails if a rule
stops firing on both.

`expected-results.json` records the per-rule finding counts for each fixture, as produced by
`scripts/run_static_analysis.sh` with `FORGE_SA_SKIP_FSRT=1`. The tests in `../tests/` run the
wrapper against every fixture and compare against this file, so a rule change that loses recall
or starts firing on safe code fails the suite.

Run everything from the skill directory:

```bash
python -m unittest discover -s tests -v
```

The fixture tests download the pinned OpenGrep binary into `scripts/` on first use (about 47 MB,
checksum verified). Set `FORGE_SA_TESTS_OFFLINE=1` to skip them when no binary is present. FSRT is
not exercised by the tests because its first run needs network access to developer.atlassian.com;
run the wrapper without `FORGE_SA_SKIP_FSRT` to see both tools on a fixture:

```bash
scripts/run_static_analysis.sh evals/fixtures/core/vulnerable
```

Updating expectations after a deliberate rule change: run the wrapper on each fixture, count
`results[].check_id` per rule in `security-audit-artifacts/opengrep/results.json`, and update
`expected-results.json`. Keep the safe twins at zero.
