# Forge Connector & Teamwork Graph Review Guide

## 1. Documentation & Dynamic Rules (Single Source of Truth)
When evaluating connector code, use the URL reading tool (`read_url_content`) to fetch the latest guidelines:
- **Connector Best Practices:** `https://developer.atlassian.com/platform/teamwork-graph/connector-requirements-and-best-practices/`
- **Manifest Reference:** `https://developer.atlassian.com/platform/forge/manifest-reference/modules/teamwork-graph-connector/`

---

## 2. Review Checklist

### A. Security, Privacy & Hygiene
- [ ] **Secret Storage:** Third-party API keys, client secrets, and OAuth refresh tokens are stored in Forge Secure Storage or Secret variables (never hardcoded).
- [ ] **Data Redaction in Logs:** Auth tokens, user secrets, and customer PII are redacted from `console.log` / error messages.
- [ ] **Egress Declarations:** Remote domains are declared under `permissions.external.fetch.backend`.

### B. Ingestion & Graph Contracts
- [ ] **Capabilities Declared:** `manifest.yml` defines the `capabilities` block (`replicatesPermissions`, `syncFidelity`, `supportsIncrementalSync`). Report with **Source=`connector`** (not `manifest`), even though the evidence is in the manifest.
- [ ] **No Fire-and-Forget:** Calls to `graph.setObjects`, `graph.setUsers`, and `graph.setGroups` are `await`ed, and `response.results.rejected` is explicitly handled and logged.
- [ ] **Principal ID Alignment:** The `externalId` used in `setUsers` and `setGroups` strictly matches the `id` values referenced in object permission ACLs.

### C. Lifecycle & Resilience
- [ ] **Lifecycle Handling:** `onConnectionChange` handles `DELETED` / `UNINSTALLED` to stop task runners and clean up webhooks (no redundant entity deletion calls on disconnect).
- [ ] **Deletion Sync:** If `syncFidelity: mirror`, implements source deletion tracking/tombstones (`graph.deleteObjects`) to avoid orphaned entities in search.
- [ ] **Rate Limiting & Backoff:** Upstream third-party API 429 responses trigger exponential backoff and are not mapped to unhandled generic 500 errors.
- [ ] **Task Chunking:** Ingestion jobs use Task Runners or Forge Async Events for granular batch execution instead of monolithic invocations.

---

## 3. Review Comment Output
Emit connector findings using the parent skill Output Format, with **Source** set to `connector` for **every** item in this guide — including capabilities, egress, and other checks whose Location is `manifest.yml`.

For each finding:
1. Follow parent Location rules (`path:line` / `path:start-end` plus contributing code excerpt). For missing `capabilities`, quote the enclosing `graph:connector` block.
2. Provide a concrete Fix (code snippet or manifest example when helpful).
3. Cite the exact DAC section anchor URL in the Doc column (or equivalent) to ground the recommendation.
4. Prefer checklist section labels in Description when useful (e.g. “No Fire-and-Forget”, “Principal ID Alignment”, “Capabilities Declared”).
