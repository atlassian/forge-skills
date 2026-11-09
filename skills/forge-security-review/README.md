# Forge App Security Review Skill

Performs white-box security reviews for Atlassian Forge apps using a structured ruleset, a pinned deterministic scanning layer, and evidence-first reporting.

## Skill Files

- `SKILL.md`: Triggering, workflow, and reporting instructions for agent hosts
- `assets/security-rules/`: Global and category Forge security rules used by the skill
- `assets/opengrep-rules/`: Deterministic OpenGrep rules run by the static-analysis script
- `scripts/`: `run_static_analysis.sh` / `.ps1`, which download pinned, checksum-verified FSRT and OpenGrep binaries and run them
- `evals/`: Fixture Forge apps and expected results for the rules
- `tests/`: Unit tests for the rule file, the scripts and the fixtures

## Rule Layout

- `assets/security-rules/_global-forge.mdc`
  - Global baseline for every Forge white-box review.
- `assets/security-rules/forge-*/_index-*.mdc`
  - Category index files that point to deeper subrules.
- `assets/security-rules/forge-*/*.mdc`
  - Category-specific deep checks.
- `assets/opengrep-rules/forge-security-rules.yaml`
  - 44 OpenGrep rules (31 ERROR, 13 WARNING) covering tainted `asApp()` routes, fetch, `invokeRemote` and `assumeTrustedRoute` paths; JQL/CQL (in URLs and POST bodies) and Forge SQL taint; web trigger authentication and literal shared secrets; module-scope request state and `process.env` mutation; storage keys built from user input; context identifiers with payload fallbacks and payload identity used for authorization; prototype pollution through payload merges; request headers from the payload; sandbox escapes; secrets returned to the client, kept in plain storage or used in Basic auth; the private cross-tenant API; Custom UI HTML sinks fed by `invoke()` or product data; installation-wide writes without a permission check; model output driving privileged actions; and manifest settings (anonymous access, wildcard, shared-hosting and tunnel egress, unsafe script CSP directives).

The rules use Semgrep rule syntax and run on OpenGrep, an open-source Semgrep-compatible engine; no Semgrep registry rules or account are involved.

Every OpenGrep rule carries `metadata.skill_rule`, the `.mdc` file the agent applies to its hits, and `metadata.cwe`, `confidence` and `security-severity`. ERROR means the matched code is the defect; WARNING means the message says what the reviewer must still confirm.

Current categories:

- `forge-authn-authz/`
- `forge-injection/`
- `forge-tenant-isolation/`
- `forge-secrets-storage/`
- `forge-egress-remotes/`
- `forge-manifest-config/`
- `forge-webtrigger-entrypoints/`
- `forge-auditing/`
- `forge-rovo-agents/`
- `forge-misc/`

## Deterministic Layer

```bash
# from skills/forge-security-review
scripts/run_static_analysis.sh <forge-project-root>       # macOS / Linux
scripts/run_static_analysis.ps1 <forge-project-root>      # Windows (PowerShell 7)
```

The script runs two tools and writes everything under `<forge-project-root>/security-audit-artifacts/`:

| Tool | Pin | Output |
| --- | --- | --- |
| FSRT (Forge Security Requirements Tester, atlassian-labs/FSRT) | GitHub release tag + per-platform SHA-256 | `fsrt/report.json`, `fsrt/fsrt.log` |
| OpenGrep running the Forge rules | OpenGrep release version + per-platform SHA-256 | `opengrep/results.json`, `opengrep/results.sarif`, `opengrep/opengrep.log` |

`static-analysis-summary.json` records each tool's status (`completed`, `completed_with_errors`, `completed_with_warnings`, `skipped`, `not_run`) and counts. The script exits 0 when every tool completed and 1 when a tool did not run, so a failed or missing scan is never mistaken for a clean one. First use downloads each binary once and verifies its checksum before executing it; FSRT also fetches Atlassian API specifications into `~/.cache/fsrt` on its first run. Scans make no other network calls and upload nothing.

Environment switches: `FORGE_SA_SKIP_FSRT=1`, `FORGE_SA_SKIP_OPENGREP=1`, `FORGE_SA_OUTPUT_DIR=<dir>`, `FORGE_LOG=<level>` (FSRT log filter, default `warn`).

Supported platforms: macOS arm64 (both tools) and x86_64 (OpenGrep only until an FSRT release ships an Intel macOS asset), Linux x86_64 and arm64 (glibc and musl), Windows x86_64.

## Usage Flow

1. Run `scripts/run_static_analysis.sh <forge-project-root>` and read `security-audit-artifacts/static-analysis-summary.json`.
2. Read `manifest.yml`.
3. Apply `assets/security-rules/_global-forge.mdc`.
4. Load only relevant category index rules under `assets/security-rules/forge-*/_index-*.mdc` based on manifest/code signals.
5. Load deep subrules only when index detection heuristics match observed code patterns, or when a deterministic finding's `metadata.skill_rule` points at them.
6. Trace each finding from source to sink with evidence; deterministic hits are leads until that trace is done.
7. Report validated findings with exploitability, impact, CWE mapping, test leads, and a coverage section listing what ran, what did not, and why.

### Token-Efficient Rule Loading

This skill uses a two-tier loading model:

- Tier 1: global baseline + selected category indexes
- Tier 2: on-demand deep subrules only for triggered heuristics or deterministic findings

This avoids loading all rule files up front and reduces token usage during large reviews.

### Focused Review Mode

When the user asks for a narrow scope (for example only AuthN/AuthZ), load only:

- `assets/security-rules/_global-forge.mdc`
- the requested category index
- matching subrules in that category

Still call out obvious critical findings outside the requested category.

## Testing the Rules

```bash
# from skills/forge-security-review
python -m unittest discover -s tests -v
opengrep --validate --config assets/opengrep-rules   # schema check with a local OpenGrep
```

See `evals/README.md` for the fixtures and how to update `evals/expected-results.json` after a deliberate rule change.

## Example Prompts

### 1) Full Forge app security review

```text
Perform a white-box security review of this Forge app source code.
Apply:
1) scripts/run_static_analysis.sh <project root> and read security-audit-artifacts/static-analysis-summary.json
2) assets/security-rules/_global-forge.mdc
3) Relevant category index and subrules under assets/security-rules/forge-*/
```

### 2) Focused AuthN/AuthZ review

```text
Perform a focused AuthN/AuthZ review of this Forge app.
Apply:
- assets/security-rules/_global-forge.mdc
- assets/security-rules/forge-authn-authz/_index-authn-authz.mdc
- related forge-authn-authz subrules
```

### 3) Tenant isolation and leakage review

```text
Perform a tenant isolation and data leakage review for this Forge app.
Apply:
- assets/security-rules/_global-forge.mdc
- assets/security-rules/forge-tenant-isolation/_index-tenant-isolation.mdc
- assets/security-rules/forge-secrets-storage/_index-secrets-storage.mdc
```

### 4) Full static analysis scans

```text
Review this Forge app with FULL execution of assets/security-rules/forge-auditing/static-analysis-forge.mdc.
Requirements:
1) Apply assets/security-rules/_global-forge.mdc and all relevant forge-* index/subrules.
2) Execute the complete static-analysis workflow from the subrule, including:
   - scripts/run_static_analysis.sh (FSRT + OpenGrep with the Forge rules)
   - npm audit
   - Snyk test
   - gitleaks detect
3) If a tool is missing, install it and continue (tell me what was installed).
4) End the report with a coverage section listing what ran, what did not, and why.
```
