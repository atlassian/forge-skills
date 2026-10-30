# Forge Display Conditions

Suggest simpler, equivalent composite arrays for Jira/JSM display conditions. Review first; edits require an explicit request. This is not a general manifest validator.

```bash
npx skills add atlassian/forge-skills --skill forge-display-conditions
```

Try: **“Review my Forge manifest for equivalent composite-array simplifications. Show before/after expressions without editing files.”**

## Example

Before:

```yaml
displayConditions:
  or:
    hasGlobalPermission: ADMINISTER
    or:
      hasGlobalPermission: CREATE_PROJECT
```

After:

```yaml
displayConditions:
  or:
    - hasGlobalPermission: ADMINISTER
    - hasGlobalPermission: CREATE_PROJECT
```

Both mean either permission. Already-readable conditions stay unchanged; object syntax is not deprecated.

## Setup

Requires Python 3.11+. Set `SKILL_DIR` to this installed skill's directory. Use an existing approved environment or create one outside the app repository:

```bash
ANALYZER_VENV="${XDG_CACHE_HOME:-$HOME/.cache}/forge-display-conditions/venv"
python3 -m venv "$ANALYZER_VENV"
"$ANALYZER_VENV/bin/python" -m pip install -r "$SKILL_DIR/requirements.txt"
"$ANALYZER_VENV/bin/python" "$SKILL_DIR/scripts/analyze_display_conditions.py" /path/to/app/manifest.yml
```

On Windows, use `$env:LOCALAPPDATA\forge-display-conditions\venv` and `Scripts\python.exe`. If an agent cannot access the cache, provide an allowed environment or run setup yourself; it should not create a venv in the app.

Setup installs `PyYAML>=6.0.2,<7` from the configured index (PyPI by default). This range is not hash-locked; installation may need network access. The helper itself is read-only, makes no network calls and does not execute manifest expressions.

## Scope and output

- One explicit file in, JSON out: `path`, file `status`, and `findings` with module/line/location. Suggestions include `after`, the verified `after_yaml`, and `equivalence`. The agent handles discovery and readable reporting.
- Examines module-level Jira/JSM conditions and nested page/section conditions. Other products are skipped. Unrelated manifest values are not decoded or validated; `forge lint` handles whole-app validation.
- YAML must be parseable. Duplicate keys or shared/tagged/merged YAML in a condition or its navigation path require correction/manual review. Non-Forge manifests are skipped. Unsupported conditions do not prevent reviewing independent conditions.
- Preserves predicates and parameters. Verification is bounded to 12 distinct predicates, 20 operator levels and 256 condition entries; files over 1 MiB are skipped.
- Quotes ambiguous strings defensively for YAML 1.1/1.2 readers. Input uses YAML 1.2-style scalar resolution; confirm ambiguous unquoted source values before editing. Proposed YAML is not a comment-preserving patch.
- Exit codes: `0` for completed analysis (including explicit skips), `1` for file/condition errors, `2` for CLI argument errors. Inspect findings, not just the exit code.
- Boolean equivalence is not Forge schema/runtime validation. Apply minimally, run `forge lint`, and check representative visible/hidden states. Display conditions are **not authorization**.

See [SKILL.md](SKILL.md#semantics-and-sources) for the operator semantics and exact official sources.

## Tests

From this skill directory, with dependencies installed:

```bash
python -m unittest discover -s tests -v
```

CI runs these unit tests. The four scenarios in `evals/evals.json` are separate agent evaluations, **not executed in CI**; passing unit tests do not establish that the agent handoff has been tested.
