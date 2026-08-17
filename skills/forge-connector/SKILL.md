---

name: forge-connector
description: >
  Guides building and deploying Atlassian Forge Teamwork Graph connector apps that ingest
  external data into Atlassian's Teamwork Graph, making it searchable in Rovo Search and
  surfaced in Rovo Chat. Use when the user wants to build a Forge connector, ingest external
  data into Atlassian, connect a third-party tool (e.g. Google Drive, ServiceNow, Salesforce)
  to Atlassian, make external content searchable in Rovo, build a graph:connector module,
  use the @forge/teamwork-graph SDK, or implement onConnectionChange / validateConnection
  functions.
license: Apache-2.0
labels:
  - forge
  - rovo
  - jira
  - atlassian
  - teamwork-graph
  - connector
maintainer: mbanjan94
namespace: cloud
---

# Forge Connector

Builds a `graph:connector` Forge app that ingests external data into Atlassian's Teamwork Graph so it appears in **Rovo Search** and **Rovo Chat**.

## Critical Rules

1. **Must install in Jira** — Apps using Teamwork Graph modules must be installed on a Jira site. Confluence-only installs will not work.
2. **Never ask for credentials in chat** — Direct users to run `forge login` in their own terminal.
3. **Always run the scaffold script yourself** — Do not only give manual instructions; run `scripts/scaffold_connector.py` to generate the boilerplate.
4. **Always ask the user for their Atlassian site URL** when install is needed — never discover or guess it.
5. **Atlassian deletes data on disconnect** — When `action = 'DELETED'`, the app only needs to clean up local state; Atlassian removes the Teamwork Graph data automatically.
6. **Handler arguments are passed directly** — Forge passes the request object as the first argument to handlers, NOT nested under `event.payload`. Config values are at `request.configProperties`, NOT `event.payload.config`. This is the most common source of `TypeError: Cannot destructure property of undefined` errors.
7. **Use `@forge/kvs` for storage** — Import `kvs` from `@forge/kvs`. Do NOT use `@forge/storage` — its `storage` export is `undefined` at runtime in connector functions.
8. **Use `graph` named export from `@forge/teamwork-graph`** — The correct import is `const { graph } = require('@forge/teamwork-graph')`. Call `graph.setObjects({ objects, connectionId })`. Do NOT import `setObjects` as a named export directly.
9. **`validateConnectionHandler` must return `{ success, message }`** — Do NOT throw an Error. Return `{ success: false, message: '...' }` to reject, `{ success: true }` to accept.
10. **`function` declarations belong under `modules`** — In `manifest.yml`, `function:` is a key under `modules:`, not a top-level key. Placing it at the top level causes a lint error.
11. **`formConfiguration` uses `form` array with `type: header`** — Do NOT use `fields:` or `beforeYouBegin:`. The correct format uses `form: [{ key, type: header, title, description, properties: [...] }]`.
12. **Scopes are `read/write/delete:object:jira`** — Use `read:object:jira`, `write:object:jira`, `delete:object:jira`. The scopes `read:graph:teamwork` and `write:graph:teamwork` are invalid and will fail `forge lint`.
13. **Set `ATL_FORGE_ATTRIBUTION_SKILL_NAME=forge-connector` on `forge` commands run for this skill** — prefix `forge` invocations with this env var: ones you run in the shell (e.g. `forge lint`, `forge logs`, `forge deploy`) **and the interactive `forge create` command you hand the user as a fallback**. The bundled scripts set it automatically; other commands shown in this skill omit it for brevity — add it when you run them. The only exclusions are `forge login` and `forge tunnel` (user-run auth / live-dev commands).
14. **Never ignore `setObjects` / `setUsers` / `setGroups` responses** — Do NOT treat ingestion calls as fire-and-forget. Always check both `response.success` **and** `response.results?.rejected`. A call can partially fail: some objects are rejected while others are accepted, and `response.success` can be `true` even when `rejected.length > 0`.
15. **Keep access control IDs consistent** — When using `USER` or `GROUP` principals in `permissions`, the `id` value must exactly match the `externalId` used in the corresponding `graph.setUsers()` / `graph.setGroups()` call. Mismatched IDs (e.g. `user-42` vs `accountId:user-42`) silently make objects invisible to users who should have access.
16. **Use orchestration for refresh scheduling** — When the user wants periodic re-ingestion, use `graph.scheduleOrUpdateTask` + a `taskRunner` handler (the platform-managed approach) instead of a `scheduledTrigger`. Orchestration handles cadence, retry, and fan-out natively. Only fall back to `scheduledTrigger` if the user explicitly needs a lightweight cron-style trigger without platform task tracking.
17. **`taskId` must be a valid UUID** — Both `scheduleOrUpdateTask` and `scheduleChildTask` require `task.taskId` to be a UUID string. Use `uuid()` (v4) for root tasks and `uuidv5('<scanId>:<parentTaskId>:<itemId>', APP_NAMESPACE)` for child tasks. Persist root task IDs in KVS so re-running `onConnectionChange` reuses the same ID (making it an update, not a competing schedule).
18. **Write `TaskInfo` to KVS before scheduling; never delete it on completion** — Always write the `TaskInfo` record to KVS keyed by `taskId` before calling `scheduleOrUpdateTask` or `scheduleChildTask`. On success, set `completed: true` on the record — do NOT delete it. Deleting causes duplicate deliveries to report `ENTITY_NOT_FOUND` and overwrite the earlier success.
19. **Branch on `response.error` for orchestration responses** — `scheduleOrUpdateTask` and `scheduleChildTask` return `{ status: 'ACCEPTED' }` on success, not `{ success: true }`. Check `if (response.error)` to detect failures — do NOT check `if (!response.success)`.

## MCP Prerequisites


| MCP Server    | Purpose                                           |
| ------------- | ------------------------------------------------- |
| **Forge MCP** | Manifest syntax, module config, deployment guides |
| **ADS MCP**   | Atlaskit components (only if adding Custom UI)    |


---

## Agent Workflow — Complete Steps 0–7 in Order

### Step 0: Prerequisites

Check Node.js (`node -v`, requires 22+), Forge CLI (`forge --version`), and login (`forge whoami`). Install missing tools:

```bash
npm install -g @forge/cli
```

Tell the user to run `forge login` in their terminal if not authenticated.

### Step 1: Discover Developer Spaces

> **Note:** `forge developer-spaces list` does NOT exist in Forge CLI 12.x. You cannot list developer spaces non-interactively.

`forge create` requires an interactive TTY to select a developer space. Ask the user to run it themselves:

```
Tell the user:
  cd <parent-directory>
  ATL_FORGE_ATTRIBUTION_SKILL_NAME=forge-connector forge create --template blank <app-name>

  When prompted, select a Developer Space and let it complete.
  Come back when done.
```

The `--dev-space-id` flag in the scaffold script is optional and can be omitted — the script has been updated to skip it when not provided.

### Step 1.5: Discover Data & Map to Object Types

**Do this before scaffolding.** Ask the user the following questions to determine the correct Teamwork Graph object type(s). Do not assume or default to `atlassian:document`.

#### Questions to ask the user

1. **What external system or tool are you connecting?**
   e.g. Google Drive, ServiceNow, Salesforce, GitHub, Confluence, Slack, Figma, Zendesk

2. **What kind of content do you want to make searchable in Rovo?**
   Prompt with examples to help them identify it:
   - Files, pages, wiki articles, reports, PDFs → likely `atlassian:document`
   - Tasks, tickets, issues, bugs, stories → likely `atlassian:work-item`
   - Chat messages, emails, comments → likely `atlassian:message` or `atlassian:comment`
   - Projects, workspaces, boards → likely `atlassian:project`
   - Code repositories → likely `atlassian:repository`
   - Pull requests / merge requests → likely `atlassian:pull-request`
   - Git commits → likely `atlassian:commit`
   - Design files (Figma, Sketch) → likely `atlassian:design`
   - Video recordings → likely `atlassian:video`
   - Calendar events, meetings → likely `atlassian:calendar-event`
   - Threads, channels → likely `atlassian:conversation`
   - Customer accounts or organisations → likely `atlassian:customer-organization`
   - Team spaces or org units → likely `atlassian:space`

3. **Is the content a single type or a mix?**
   If mixed (e.g. a project management tool with tasks *and* documents), plan to ingest each as its own object type. The scaffold supports one primary type — you can add more `objectTypes` entries in `manifest.yml` later.

4. **Does the admin need to supply credentials (API key, URL, OAuth token) to connect?**
   Yes → use `--has-form-config` in the scaffold command.
   No (data comes entirely from within Atlassian) → omit the flag.

5. **How often does the source data change?**
   This determines the sync cadence. Use **orchestration** (`scheduleOrUpdateTask` + `taskRunner`) for all platform-managed refresh — it handles cadence, retry, and fan-out natively. Only use the legacy `scheduledTrigger` approach if you explicitly need a lightweight cron with no task tracking.

   | Frequency | Orchestration interval |
   |---|---|
   | Hourly | `scheduleInterval: { value: 1, timeUnit: 'hour' }` |
   | Daily | `scheduleInterval: { value: 1, timeUnit: 'day' }` |
   | Every N minutes (1–60) | `scheduleInterval: { value: N, timeUnit: 'minute' }` |
   | Static / one-off | No scheduled refresh needed — ingest once in `onConnectionChange` |

   Record the chosen interval before proceeding to Step 2.

6. **Who should be able to see the ingested content in Rovo Search?**
   This determines the `permissions.accessControls` on each object. Ask:
   - "Is all this content publicly accessible, or does the source system restrict who can see what?"
   - "Do you want Rovo Search results to respect those source-system permissions?"

   Map the answer to the correct principal model:

   | Source system access model | `accessControls` to use |
   |---|---|
   | Publicly accessible, no restrictions | `principals: [{ type: 'EVERYONE' }]` |
   | Specific named users have access | `principals: [{ type: 'user', id: '<atlassian-account-id>' }]` — one entry per user |
   | Team or group based (e.g. Confluence space, Google Workspace group) | `principals: [{ type: 'group', id: '<group-id>' }]` — one entry per group |
   | Private / owner only | single `user` principal with the owner's Atlassian account ID |
   | Mixed (per-object ACLs from the source) | fetch ACLs per item during ingestion and map each to a `user` or `group` principal |

   **Do NOT default to `EVERYONE`** unless the user explicitly confirms content is publicly accessible. Using `EVERYONE` on restricted content leaks data to users who shouldn't see it in Rovo Search.

   Record the chosen permission model before proceeding to Step 2. Reference it when writing the `setObjects` call in Step 3.

#### Mapping decision

Based on the answers, select the best-fit type from the Object Types table below. Only fall back to `atlassian:document` if the content genuinely has no better match (e.g. arbitrary file attachments). For types marked ❌ in the "Indexed in Rovo" column (`atlassian:build`, `atlassian:deployment`, `atlassian:test`), warn the user that those objects will not appear in Rovo Search or Rovo Chat.

Record the chosen object type(s) and permission model before proceeding to Step 2.

### Step 2: Scaffold the Connector App

Run from the **skill directory** (the directory containing this SKILL.md). Replace `<object-type>` with the type determined in Step 1.5. `--dev-space-id` is optional:

```bash
python3 -m scripts.scaffold_connector \
  --name <app-name> \
  --connector-name "<Human Readable Name>" \
  --object-type <object-type> \
  --directory <parent-directory>
```

Add `--dev-space-id <id>` only if you have the ID from a previous step.

**Object type** — use the type chosen in Step 1.5. Do NOT default to `atlassian:document` without first completing the discovery questions above.

**Form config flag** — add `--has-form-config` if the admin must provide API credentials or connection details (determined in Step 1.5 question 4). Omit it for apps that operate entirely within Atlassian (no external credentials needed).

> **If scaffold fails because `forge create` needs a TTY:** The scaffold script will print a manual fallback command. Have the user run `forge create` interactively, then continue from Step 3 — the scaffold script only needs to write `manifest.yml` and `src/index.js` after the directory exists.

### Step 3: Customize the Generated Code

After scaffolding (or after the user runs `forge create` interactively):

```bash
cd <app-name>
npm install
```

The blank template generates `src/index.js` (JavaScript, not TypeScript). Edit it to add your API calls. The scaffold generates working handler skeletons; fill in your business logic.

#### Key files to edit

| File           | What to change                                                          |
| -------------- | ----------------------------------------------------------------------- |
| `src/index.js` | `fetchExternalData()` — replace with your API calls                     |
| `manifest.yml` | Add `permissions.external.fetch.backend` URLs for any external APIs     |
| `package.json` | Add `@forge/api`, `@forge/kvs`, `@forge/teamwork-graph` as dependencies |


#### setObjects — ingest data into Teamwork Graph

Use the `graph` named export — do NOT destructure `setObjects` directly:

```javascript
const { graph } = require('@forge/teamwork-graph');

const result = await graph.setObjects({
  connectionId,          // required — the connectionId from the handler request
  objects: [
    {
      schemaVersion: '1.0',
      id: 'unique-id-from-source',      // unique per connectionId
      updateSequenceNumber: 1,
      displayName: 'My Document Title',
      url: 'https://source-system.example.com/doc/123',
      createdAt: '2024-01-15T10:00:00Z',        // ISO 8601
      lastUpdatedAt: '2024-01-20T14:30:00Z',
      // Use the permission model chosen in Step 1.5 question 6.
      // EVERYONE only if content is confirmed publicly accessible.
      // For user-restricted content: { type: 'USER', id: '<externalId from setUsers>' }
      // For group-restricted content: { type: 'GROUP', id: '<externalId from setGroups>' }
      permissions: [{
        accessControls: [{
          principals: [{ type: 'EVERYONE' }],
        }],
      }],
      'atlassian:document': {
        type: {
          category: 'DOCUMENT',   // see Document Categories table below
          mimeType: 'application/vnd.google-apps.document',
        },
        content: {
          mimeType: 'application/vnd.google-apps.document',
          text: 'document title or snippet for search indexing',
        },
      },
    },
  ],
});

// Always check both success AND rejected — a call can partially fail.
const rejected = result.results?.rejected ?? [];
if (!result.success || rejected.length > 0) {
  console.error('setObjects ingestion failed', {
    connectionId,
    acceptedCount: result.results?.accepted?.length ?? 0,
    rejectedCount: rejected.length,
    rejected,
    error: result.error,
  });
}
```

- Max **100 objects per call** — batch large datasets with a loop
- `id` must be unique per `connectionId`
- `connectionId` is required in every `graph.setObjects()` call

#### Document Categories (for `atlassian:document.type.category`)

| MIME type | Category |
|---|---|
| `application/vnd.google-apps.document` | `DOCUMENT` |
| `application/vnd.google-apps.spreadsheet` | `SPREADSHEET` |
| `application/vnd.google-apps.presentation` | `PRESENTATION` |
| `application/vnd.google-apps.folder` | `FOLDER` |
| `application/pdf` | `PDF` |
| `image/*` | `IMAGE` |
| `video/*` | `VIDEO` |
| `audio/*` | `AUDIO` |
| Other | `OTHER` |

#### getObjectByExternalId — look up a single object

```javascript
const { graph } = require('@forge/teamwork-graph');

const data = await graph.getObjectByExternalId({
  externalId: 'unique-id-from-source',
  objectType: 'atlassian:document',
  connectionId,
});
if (data.success) console.log(data.object);
```

### Step 4: Deploy and Install

**You MUST run the deploy script** — do not only give the user manual `forge deploy` commands.

The deploy script lives in the **forge-app-builder** skill, not in this skill. Derive its directory from the path of this SKILL.md: go up two levels (`skills/forge-connector/` → `skills/`) then into `forge-app-builder/`. Run all commands below from that directory.

```bash
# Derive forge-app-builder skill dir from this SKILL.md's path:
# e.g. if this file is at /path/to/skills/forge-connector/SKILL.md
# then the deploy script dir is: /path/to/skills/forge-app-builder/

# If you have the site URL:
python3 -m scripts.deploy_forge_app \
  --app-dir <app-directory> \
  --site <site-url> \
  --product jira

# If you don't have the site URL yet, deploy first then ask:
python3 -m scripts.deploy_forge_app \
  --app-dir <app-directory> \
  --product jira \
  --deploy-only
# Ask: "What is your Atlassian site URL (e.g. yourcompany.atlassian.net)?"
python3 -m scripts.deploy_forge_app \
  --app-dir <app-directory> \
  --site <site-url> \
  --product jira \
  --skip-deps
```

### Step 5: Connect via Atlassian Administration

After deployment, tell the user to:

1. Go to **Atlassian Administration** → **Apps** → **[site]** → **Connected apps**
2. Find the app → **View app details** → **Connections** tab
3. Click **Connect** under the connector
4. Fill in any configuration fields (if `formConfiguration` was defined)
5. Click **Connect** — this triggers `onConnectionChange` with `action: CREATED` and starts data ingestion

### Step 6: Monitor with forge tunnel

Use `forge tunnel` during development to stream live logs directly to your terminal as the connector functions execute. This is the fastest way to catch errors in `onConnectionChangeHandler`, `validateConnectionHandler`, and `setObjects` calls without waiting for `forge logs`.

Tell the user to run this in their own terminal (it requires an interactive session):

```bash
cd <app-directory>
forge tunnel
```

With the tunnel active, any invocation of the connector functions (e.g. clicking "Connect" in Atlassian Admin, or triggering a scheduled re-ingestion) will stream output immediately. Look for:

- `[connector] Fetched N items` — confirms `fetchExternalData()` ran
- `[connector] Batch 1: N accepted, 0 rejected` — confirms `setObjects` succeeded
- Any uncaught errors or thrown exceptions from `validateConnectionHandler`

If the tunnel is not running, use `forge logs` instead to inspect past invocations:

```bash
# Most recent 50 log lines from development environment
forge logs -e development --limit 50

# Production logs for a specific site
forge logs -e production --site <your-site> --limit 50
```

**Tunnel vs logs — when to use which:**

| Situation | Use |
|---|---|
| Actively developing / testing the connection flow | `forge tunnel` — live streaming |
| Debugging a past invocation or production issue | `forge logs` |
| Connector function timed out before tunnel caught it | `forge logs` with `--limit 100` |

> **Note:** `forge tunnel` must be run by the user in an interactive terminal — do not attempt to run it via the agent.

### Step 7: End-to-End Verification (optional)

Before running any checks, ask the user:

> "Would you like to run end-to-end verification checks before deploying to production? This confirms the connection, ingestion, Rovo Search visibility, and permission boundaries are all working correctly."

If the user says **no** or wants to skip, move on — do not run or describe the checks.
If the user says **yes**, work through every check below in order.

#### Check 1 — Connection established

In **Atlassian Administration → Apps → Connected apps**, the connector should show status **Connected**. If it shows an error or pending state, go back to Step 6 and inspect `forge tunnel` or `forge logs` output.

#### Check 2 — `validateConnection` passed (if configured)

If the app has a `validateConnection` function, confirm the admin saw a success message when clicking **Connect**. If not, check logs for the return value — it must be `{ success: true }`, not a thrown error.

#### Check 3 — `onConnectionChange` fired and ingestion ran

In `forge logs` or the tunnel output, confirm:

```bash
forge logs -e development --limit 50
```

Look for all three signals:
- Handler was invoked: log line from `onConnectionChangeHandler` with `action: CREATED`
- Data was fetched: e.g. `[connector] Fetched N items`
- `setObjects` succeeded: e.g. `[connector] Batch 1: N accepted, 0 rejected`

If `setObjects` returned `{ success: false }`, the error detail is in `result.error` — surface it to the user and fix before continuing.

#### Check 4 — Objects visible in Rovo Search

1. Open Rovo Search on the Jira site (allow up to **5 minutes** for indexing after ingestion)
2. Search for a word that appears in at least one ingested object's `displayName` or content text
3. Filter by the connector's nickname (set by admin at connection time)

At least one result from the connector should appear. If nothing shows up after 5 minutes:
- Confirm `setObjects` logged `N accepted` with N > 0 (Check 3)
- Confirm the object's `permissions` match the logged-in user (an `EVERYONE` principal or a `user`/`group` principal that includes the test user)
- Re-check that `write:object:jira` scope is present in `manifest.yml` and the app was redeployed after any scope change

#### Check 5 — Permission boundary (skip only if `EVERYONE` was used)

If the connector uses `user` or `group` principals:
1. Log in as a user who **should** have access → confirm the object appears in Rovo Search
2. Log in as a user who **should not** have access → confirm the object does **not** appear

If a restricted object is visible to an unauthorised user, re-check the `accessControls` principals in `setObjects` and redeploy.

#### Check 6 — Rovo Chat references connector data

Ask Rovo Chat a question whose answer exists only in the ingested content, e.g.:

> "What is the status of [title of an ingested item]?"

Rovo Chat should cite the connector as a source. If it cannot find the content, Checks 3 and 4 likely have an unresolved issue.

#### Check 7 — Scheduled re-ingestion fires (if configured)

If a `scheduledTrigger` was added:
1. Temporarily set `interval: fiveMinutes` in `manifest.yml`, redeploy, and wait one cycle
2. Confirm `forge logs` shows a fresh ingestion run from `refreshIngestionHandler`
3. Restore the original interval and redeploy before going to production

#### Production readiness gate

If the user chose to run verification, only proceed to a production deploy (`forge deploy -e production`) when **all applicable checks above pass**:

| Check | Required for production |
|---|---|
| 1 — Connection established | Always |
| 2 — validateConnection passed | Only if `validateConnection` is configured |
| 3 — Ingestion ran without errors | Always |
| 4 — Objects visible in Rovo Search | Always |
| 5 — Permission boundary | Only if using `user`/`group` principals |
| 6 — Rovo Chat cites connector | Always |
| 7 — Scheduled re-ingestion fires | Only if `scheduledTrigger` is configured |

---

## Manifest Reference

> **Key rules:**
> - Scopes are `read:object:jira`, `write:object:jira`, `delete:object:jira` — NOT `read:graph:teamwork` / `write:graph:teamwork` (those fail `forge lint`)
> - `function:` is declared **under `modules:`**, not at the top level
> - Egress uses `address:` not a bare string (run `forge lint --fix` to auto-correct)
> - `formConfiguration` uses `form: [{ type: header, properties: [...] }]` — NOT `fields:` or `beforeYouBegin:`

### Minimal connector (no admin config, no OAuth)

Use when the app operates entirely within Atlassian — no external credentials needed.

```yaml
app:
  id: <generated-by-forge-create>
  runtime:
    name: nodejs24.x
    memoryMB: 256
    architecture: arm64

permissions:
  scopes:
    - read:object:jira
    - write:object:jira
    - delete:object:jira
    - storage:app

modules:
  graph:connector:
    - key: my-connector
      name: My Service
      capabilities:
        replicatesPermissions: false  # true if mirroring source-system ACLs into Teamwork Graph
        syncFidelity: mirror          # append | upsert | mirror (mirror is recommended)
        supportsIncrementalSync: false
      icons:
        light: https://cdn.example.com/logo.png
        dark: https://cdn.example.com/logo.png
      objectTypes:
        - atlassian:document
      datasource:
        onConnectionChange:
          function: on-connection-change

  function:
    - key: on-connection-change
      handler: index.onConnectionChangeHandler
```

### Connector with orchestration (platform-managed refresh)

Add an `orchestration.taskRunner` block to any connector variant to enable platform-managed periodic re-ingestion. Wire it alongside your existing `onConnectionChange` handler.

```yaml
modules:
  graph:connector:
    - key: my-connector
      name: My Service
      capabilities:
        replicatesPermissions: false
        syncFidelity: mirror
        supportsIncrementalSync: false
      icons:
        light: https://cdn.example.com/logo.png
        dark: https://cdn.example.com/logo.png
      objectTypes:
        - atlassian:document
      orchestration:
        taskRunner:
          function: task-runner-fn     # references the function key below
      datasource:
        onConnectionChange:
          function: on-connection-change

  function:
    - key: on-connection-change
      handler: index.onConnectionChangeHandler
    - key: task-runner-fn
      handler: index.taskRunner
      timeoutSeconds: 900             # optional: extend to 15 min for large datasets
```

> `timeoutSeconds` is only valid on a function referenced by a consumer module (like `orchestration.taskRunner`). Setting it on an unreferenced function fails manifest validation.

### Connector with admin form config (API key / URL)

Use when the admin must provide credentials to connect to an external system.
```yaml
app:
  id: <generated-by-forge-create>
  runtime:
    name: nodejs24.x
    memoryMB: 256
    architecture: arm64

permissions:
  scopes:
    - read:object:jira
    - write:object:jira
    - delete:object:jira
    - storage:app
  external:
    fetch:
      backend:
        - address: 'https://api.your-service.com'   # note: address: not a bare string

modules:
  graph:connector:
    - key: my-connector
      name: My Service
      capabilities:
        replicatesPermissions: false  # true if mirroring source-system ACLs into Teamwork Graph
        syncFidelity: mirror          # append | upsert | mirror (mirror is recommended)
        supportsIncrementalSync: false
      icons:
        light: https://cdn.example.com/logo.png
        dark: https://cdn.example.com/logo.png
      objectTypes:
        - atlassian:document
      datasource:
        formConfiguration:
          form:                          # use form:, NOT fields: or beforeYouBegin:
            - key: connectionDetails
              type: header
              title: Connection Details
              description: >
                Provide your My Service API credentials.
                Find them in My Service → Settings → API.
              properties:
                - key: apiKey           # camelCase keys — accessed as request.configProperties.apiKey
                  label: API Key
                  type: string
                  isRequired: true
                - key: apiUrl
                  label: API URL
                  type: string
                  isRequired: true
          validateConnection:
            function: validate-connection
        onConnectionChange:
          function: on-connection-change

  function:                              # function: is under modules:, NOT top-level
    - key: on-connection-change
      handler: index.onConnectionChangeHandler
    - key: validate-connection
      handler: index.validateConnectionHandler
```

---

## Handler Signatures

> **Critical:** Forge passes the request **directly as the first argument** — it is NOT wrapped under `event.payload`. Config form values are at `request.configProperties`, not `event.payload.config`. Getting this wrong causes `TypeError: Cannot destructure property of undefined`.

### onConnectionChange

```javascript
const { kvs } = require('@forge/kvs');
const { graph } = require('@forge/teamwork-graph');

exports.onConnectionChangeHandler = async (request) => {
  // request.action, request.connectionId, request.configProperties
  const { action, connectionId, configProperties } = request;

  if (action === 'DELETED') {
    // Atlassian removes Teamwork Graph data automatically on disconnect.
    // Only clean up locally stored credentials.
    await kvs.deleteSecret(connectionId);
    return { success: true };
  }

  // CREATED or UPDATED — persist credentials and ingest data
  await kvs.setSecret(connectionId, configProperties);
  await ingestAllData(connectionId, configProperties);
  return { success: true };
};
```

### validateConnection

```javascript
const { fetch } = require('@forge/api');

exports.validateConnectionHandler = async (request) => {
  // request.configProperties — NOT event.payload.config
  const { configProperties } = request;

  // Return { success: false, message } to reject — do NOT throw an Error.
  // Return { success: true } to accept.
  const response = await fetch(`${configProperties['apiUrl']}/health`);
  if (!response.ok) {
    return { success: false, message: 'Invalid API credentials. Please check your settings.' };
  }
  return { success: true, message: 'Connection validated successfully.' };
};
```

### refreshIngestion (scheduled trigger)

```javascript
exports.refreshIngestionHandler = async () => {
  const activeConnections = await kvs.get('active-connections') ?? [];
  for (const connectionId of activeConnections) {
    const config = await kvs.getSecret(connectionId);
    if (config) await ingestAllData(connectionId, config);
  }
};
```

---

## Object Types

Objects in **bold** are indexed in Rovo Search and Rovo Chat.


| Object Type                       | Indexed in Rovo | Best for                             |
| --------------------------------- | --------------- | ------------------------------------ |
| `atlassian:document`              | ✅               | Files, pages, wiki articles, reports |
| `atlassian:message`               | ✅               | Chat messages, emails, comments      |
| `atlassian:work-item`             | ✅               | Tasks, tickets, issues               |
| `atlassian:project`               | ✅               | Projects, workspaces                 |
| `atlassian:space`                 | ✅               | Team spaces, org units               |
| `atlassian:design`                | ✅               | Design files (Figma, etc.)           |
| `atlassian:repository`            | ✅               | Code repositories                    |
| `atlassian:pull-request`          | ✅               | PRs, merge requests                  |
| `atlassian:commit`                | ✅               | Git commits                          |
| `atlassian:branch`                | ✅               | Git branches                         |
| `atlassian:conversation`          | ✅               | Threads, channels                    |
| `atlassian:video`                 | ✅               | Video recordings                     |
| `atlassian:calendar-event`        | ✅               | Meetings, events                     |
| `atlassian:comment`               | ✅               | Review comments                      |
| `atlassian:customer-organization` | ✅               | Customer accounts, orgs              |
| `atlassian:build`                 | ❌               | CI/CD builds                         |
| `atlassian:deployment`            | ❌               | Deployments                          |
| `atlassian:test`                  | ❌               | Test cases                           |


---

## Rovo Search / Rovo Chat Surfacing

Once ingested:

- Objects appear in **Rovo Search** under a subfilter named after the connector's nickname (set by admin at connection time)
- **Rovo Chat** can reference and cite connector objects in responses when queried about topics related to the ingested content
- Data is not available immediately — allow a few minutes for indexing after `onConnectionChange` fires

To verify ingestion is working:

1. Open Rovo Search on the Jira site
2. Search for text that appears in an ingested object's `name` or `properties`
3. Filter by the connector nickname to narrow results

---

## Batching Pattern for Large Datasets

```javascript
const { graph } = require('@forge/teamwork-graph');

const BATCH_SIZE = 100;

async function ingestAllData(connectionId, config) {
  const items = await fetchExternalData(config);

  for (let i = 0; i < items.length; i += BATCH_SIZE) {
    const batchNum = Math.floor(i / BATCH_SIZE) + 1;
    const batch = items.slice(i, i + BATCH_SIZE);
    const result = await graph.setObjects({
      connectionId,          // required in every call
      objects: batch.map(item => ({
        schemaVersion: '1.0',
        id: item.id,                      // unique per connectionId
        updateSequenceNumber: 1,
        displayName: item.title,
        url: item.url,
        createdAt: item.createdAt,
        lastUpdatedAt: item.updatedAt,
        // Replace with USER/GROUP principals if source system has access controls.
        // The id must exactly match the externalId used in graph.setUsers() / graph.setGroups().
        permissions: [{
          accessControls: [{ principals: [{ type: 'EVERYONE' }] }],
        }],
        'atlassian:document': {
          type: { category: 'DOCUMENT', mimeType: item.mimeType },
          content: { mimeType: item.mimeType, text: item.title },
        },
      })),
    });

    // Always check both success AND rejected — a call can partially fail.
    const rejected = result.results?.rejected ?? [];
    if (!result.success || rejected.length > 0) {
      console.error(`[connector] setObjects batch ${batchNum} failed`, {
        connectionId,
        acceptedCount: result.results?.accepted?.length ?? 0,
        rejectedCount: rejected.length,
        rejected,
        error: result.error,
      });
    } else {
      console.log(`[connector] Batch ${batchNum}: ${result.results?.accepted?.length ?? batch.length} accepted, 0 rejected`);
    }
  }
}
```

---

## Orchestrated Re-Ingestion (recommended)

Use orchestration when the user selects a refresh schedule. The platform invokes `taskRunner` on the configured cadence per connection — no external scheduler needed. See [Orchestration concepts](https://developer.atlassian.com/platform/teamwork-graph/orchestration-concepts/) for the full reference.

Install the `uuid` package for task ID generation:

```bash
npm install uuid
```

### Three IDs you receive in every `taskRunner` invocation

| ID | Lifetime | Use |
|---|---|---|
| `taskId` | Stable across invocations of a root task | KVS key for `TaskInfo` |
| `scanId` | One per scheduled run of a root task | Pass unchanged to `updateTaskStatus`; threads through all children |
| `taskExecutionId` | Unique per invocation attempt | Pass unchanged to `updateTaskStatus` |

### `onConnectionChange` — schedule the root task

Call `scheduleOrUpdateTask` on both `CREATED` and `UPDATED`. Reusing the same `taskId` makes the call an in-place update of the existing schedule.

```javascript
const { graph, types } = require('@forge/teamwork-graph');
const { kvs } = require('@forge/kvs');
const { v4: uuid } = require('uuid');

exports.onConnectionChangeHandler = async (request) => {
  const { action, connectionId, configProperties } = request;

  if (action === 'DELETED') {
    await kvs.deleteSecret(connectionId);
    await kvs.delete(`rootTaskId:${connectionId}`);
    // TaskInfo rows for in-flight tasks are cleaned up here or in a maintenance pass.
    return { success: true };
  }

  await kvs.setSecret(connectionId, configProperties);

  // Mint once, reuse on UPDATED — same taskId makes scheduleOrUpdateTask an update.
  let rootTaskId = await kvs.get(`rootTaskId:${connectionId}`);
  if (!rootTaskId) {
    rootTaskId = uuid();
    await kvs.set(`rootTaskId:${connectionId}`, rootTaskId);
  }

  // Write TaskInfo BEFORE scheduling (taskRunner reads this to dispatch).
  await kvs.set(`taskInfo:${rootTaskId}`, {
    taskType: types.FORGE_TASK_TYPES.ENTITY_INGESTION_FULL,
    connectionId,
    createdAt: new Date().toISOString(),
  });

  const response = await graph.scheduleOrUpdateTask({
    connectionId,
    task: {
      taskId: rootTaskId,
      taskType: types.FORGE_TASK_TYPES.ENTITY_INGESTION_FULL,
      scheduleInterval: { value: 1, timeUnit: 'day' }, // value: 1–60; timeUnit: minute|hour|day
    },
  });

  // Branch on response.error — NOT response.success (orchestration responses don't set a boolean success field).
  if (response.error) {
    console.error('[connector] scheduleOrUpdateTask failed:', response.error);
    return { success: false, message: response.error };
  }

  return { success: true };
};
```

### `taskRunner` — run ingestion with idempotency

```javascript
exports.taskRunner = async (request) => {
  const { taskId, scanId, taskExecutionId, connectionId } = request;

  // Read TaskInfo — dispatch key and idempotency state.
  const taskInfo = await kvs.get(`taskInfo:${taskId}`);
  if (!taskInfo) {
    await graph.updateTaskStatus({
      scanId, taskExecutionId, connectionId,
      status: 'failure',
      failureReason: 'ENTITY_NOT_FOUND',
      task: { taskId },
    });
    return { success: false, message: 'Task not found' };
  }

  // Short-circuit duplicate deliveries — the platform delivers at-least-once.
  if (taskInfo.completed) {
    await graph.updateTaskStatus({ scanId, taskExecutionId, connectionId, status: 'success', task: { taskId } });
    return { success: true, message: 'Already completed (duplicate delivery)' };
  }

  try {
    const config = await kvs.getSecret(connectionId);
    await ingestAllData(connectionId, config);

    // Mark completed BEFORE updateTaskStatus so a crash between the two
    // doesn't cause a duplicate invocation to re-run the full pipeline.
    await kvs.set(`taskInfo:${taskId}`, { ...taskInfo, completed: true });
    await graph.updateTaskStatus({ scanId, taskExecutionId, connectionId, status: 'success', task: { taskId } });
    return { success: true };
  } catch (err) {
    console.error('[connector] taskRunner failed:', err);
    await graph.updateTaskStatus({
      scanId, taskExecutionId, connectionId,
      status: 'failure',
      failureReason: 'INTERNAL_ERROR',
      task: { taskId },
    });
    return { success: false, message: err.message };
  }
};
```

### Task types (`types.FORGE_TASK_TYPES`)

`taskType` is a closed enum — use the SDK constants, never raw strings.

```javascript
const { types } = require('@forge/teamwork-graph');

types.FORGE_TASK_TYPES.ENTITY_INGESTION_FULL          // full re-sync of objects
types.FORGE_TASK_TYPES.ENTITY_INGESTION_INCREMENTAL   // delta sync (changes only)
types.FORGE_TASK_TYPES.USER_INGESTION_FULL
types.FORGE_TASK_TYPES.USER_INGESTION_INCREMENTAL
types.FORGE_TASK_TYPES.GROUP_INGESTION_FULL
types.FORGE_TASK_TYPES.GROUP_INGESTION_INCREMENTAL
types.FORGE_TASK_TYPES.RELATIONSHIP_INGESTION_FULL
types.FORGE_TASK_TYPES.RELATIONSHIP_INGESTION_INCREMENTAL
```

### Fan-out with child tasks (large datasets)

For large datasets, fan out from the root `taskRunner` into per-item children. Use deterministic UUIDs (`uuidv5`) for child tasks so duplicate deliveries resolve to the same `TaskInfo` row.

```javascript
const { v5: uuidv5 } = require('uuid');

const APP_NAMESPACE = '6ba7b810-9dad-11d1-80b4-00c04fd430c8'; // any stable UUID

// Inside taskRunner, after fetching item list:
for (const item of items) {
  const childTaskId = uuidv5(`${scanId}:${taskId}:${item.id}`, APP_NAMESPACE);

  await kvs.set(`taskInfo:${childTaskId}`, {
    taskType: types.FORGE_TASK_TYPES.ENTITY_INGESTION_FULL,
    connectionId,
    createdAt: new Date().toISOString(),
    metadata: { itemId: item.id },
  });

  const response = await graph.scheduleChildTask({
    connectionId,
    scanId,          // must be the current scan's scanId
    task: {
      taskId: childTaskId,
      taskType: types.FORGE_TASK_TYPES.ENTITY_INGESTION_FULL,
    },
  });

  if (response.error) {
    console.error('[connector] scheduleChildTask failed:', response.error);
  }
}
```

---

## Scheduled Re-Ingestion (legacy — prefer orchestration)

> **Prefer orchestration** (the section above) when the user wants platform-managed periodic sync. Use `scheduledTrigger` only for simple cron-style triggers where platform task tracking is not needed.

To keep data fresh with a basic scheduled trigger:

```yaml
# In manifest.yml — under modules:
scheduledTrigger:
  - key: refresh-trigger
    function: refresh-ingestion
    interval: day   # prefer 'day' or 'hour'; avoid 'fiveMinutes'

# Under function:
  - key: refresh-ingestion
    handler: index.refreshIngestionHandler
```

```javascript
const { kvs } = require('@forge/kvs');

// Track active connections in onConnectionChangeHandler:
//   await kvs.set('active-connections', [...activeConnections, connectionId]);
//   await kvs.setSecret(connectionId, configProperties);  // store credentials securely

exports.refreshIngestionHandler = async () => {
  const activeConnections = await kvs.get('active-connections') ?? [];
  for (const connectionId of activeConnections) {
    const config = await kvs.getSecret(connectionId);  // retrieve stored credentials
    if (config) await ingestAllData(connectionId, config);
  }
};
```

---

## Scripts


| Script                          | Skill directory                                   | Purpose                                                                                                                         |
| ------------------------------- | ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `scripts/scaffold_connector.py` | `skills/forge-connector/` (this skill)            | Scaffold a new connector app — generates manifest.yml, src/index.ts, installs SDK. Run: `python3 -m scripts.scaffold_connector` |
| `scripts/deploy_forge_app.py`   | `skills/forge-app-builder/` (**different skill**) | Deploy and install on Jira. Run from the forge-app-builder directory: `python3 -m scripts.deploy_forge_app`                     |


The scaffold script is in this skill's directory. The deploy script is in the **forge-app-builder** skill directory — always `cd` there (or derive the path from this SKILL.md's location) before running it.

---

## Development Best Practices

Follow these practices to avoid common issues. See the [official connector requirements](https://developer.atlassian.com/platform/teamwork-graph/connector-requirements-and-best-practices/#development-best-practices) for the full guide.

### Do not ignore ingestion errors

Always inspect the response from `setObjects`, `setUsers`, or `setGroups`. A call can fail completely **or partially reject individual items** — and `response.success` may be `true` even when some objects were rejected.

```javascript
const response = await graph.setObjects({ connectionId, objects });

const rejected = response.results?.rejected ?? [];
if (!response.success || rejected.length > 0) {
  console.error('Teamwork Graph object ingestion failed', {
    connectionId,
    acceptedCount: response.results?.accepted?.length ?? 0,
    rejectedCount: rejected.length,
    rejected,
    error: response.error,
  });
}
```

### Keep access control IDs consistent

When using `USER` or `GROUP` principals in object `permissions`, always ingest the corresponding users or groups first via `graph.setUsers()` / `graph.setGroups()`. The `id` in `accessControls` must be the **exact same string** as the `externalId` passed to those calls. Mismatched IDs silently make objects invisible to users who should have access.

```javascript
// Ingest user with externalId 'user-42'
await graph.setUsers({ connectionId, users: [{ externalId: 'user-42', displayName: 'Alex Chen', emails: [{ value: 'alex@example.com', primary: true }] }] });

// Use the same ID 'user-42' in accessControls — NOT 'accountId:user-42' or any other variant
await graph.setObjects({
  connectionId,
  objects: [{
    // ...
    permissions: [{ accessControls: [{ principals: [{ type: 'USER', id: 'user-42' }] }] }],
  }],
});
```

### Declare capabilities

Add a `capabilities` block to the `graph:connector` module. Without it, admins see _"Capabilities not declared by developer"_ on the configuration screen, which reduces confidence. Set values that accurately reflect your connector's behaviour:

| Property | Type | Values | Description |
|---|---|---|---|
| `replicatesPermissions` | boolean | `true` / `false` | Whether source-system ACLs are mirrored. If `false`, all ingested data is visible to everyone in the workspace. |
| `syncFidelity` | enum | `append` / `upsert` / `mirror` | `mirror` is recommended — syncs new objects, updates, and deletes. |
| `supportsIncrementalSync` | boolean | `true` / `false` | Whether the connector syncs only changes since the last run. |

### Data deletion responsibilities

| Approach | Behaviour | Requirement |
|---|---|---|
| **Mirror** (recommended) | Deletions synced from source — Teamwork Graph always reflects current state | Implement delete propagation |
| **Disconnect-only** | Deletions not synced — data persists until admin disconnects | Document this limitation prominently in connector docs and Marketplace listing |

When an admin disconnects, Atlassian automatically removes all ingested data. Your `onConnectionChange` handler with `action: DELETED` only needs to clean up app-side resources (stop sync jobs, remove webhooks, delete stored credentials).

---

## Troubleshooting

| Problem | Action |
| --- | --- |
| `graph:connector` not recognized in manifest | Run `forge lint` — it will identify the exact field causing the error |
| `TypeError: Cannot destructure property 'config' of 'event.payload'` | Handler using `event.payload.config` — change to `request.configProperties`. Forge passes request directly, not nested under `event.payload` |
| `TypeError: Cannot read properties of undefined (reading 'set')` | Using `storage` from `@forge/storage` — switch to `kvs` from `@forge/kvs` |
| `graph.setObjects is not a function` | Wrong import — use `const { graph } = require('@forge/teamwork-graph')` then call `graph.setObjects({ objects, connectionId })` |
| `forge lint`: invalid scopes `read/write:graph:teamwork` | Replace with `read:object:jira`, `write:object:jira`, `delete:object:jira` |
| `forge lint`: `document should NOT have additional property 'function'` | `function:` is at the top level — move it inside `modules:` |
| `forge lint`: `formConfiguration must have required property 'form'` | Replace `fields:` / `beforeYouBegin:` with `form: [{ type: header, properties: [...] }]` |
| `forge lint` warning: deprecated egress entries | Run `forge lint --fix` to auto-convert bare URL strings to `{ address: 'url' }` |
| `forge developer-spaces list` command not found | Does not exist in Forge CLI 12.x. Have user run `forge create` interactively to select a developer space |
| `forge create` fails with non-TTY error | `forge create` needs an interactive terminal — ask the user to run it; then write manifest and source files into the created directory |
| `onConnectionChange` not triggered | Verify admin clicked "Connect" in Atlassian Administration → Connected apps; run `forge tunnel` to confirm the function fires |
| Objects not appearing in Rovo Search | Wait ~5 minutes for indexing; run `forge logs -e development --since 15m` to check for `setObjects` errors |
| `setObjects` returns `success: true` but objects missing in Rovo | Check `response.results?.rejected` — individual items can be rejected even when the overall call succeeds; log the `rejected` array for per-item error details |
| Users with access can't see objects in Rovo Search | Verify the `id` in `accessControls` principals exactly matches the `externalId` used in `graph.setUsers()` / `graph.setGroups()` — mismatched IDs (e.g. `user-42` vs `accountId:user-42`) silently break access |
| 403 on `@forge/teamwork-graph` calls | Ensure `read:object:jira`, `write:object:jira`, `delete:object:jira` are in manifest scopes, then redeploy and `forge install --upgrade` |
| `forge login` required | Create API token at https://id.atlassian.com/manage/api-tokens, then run `forge login` |
| `scheduleOrUpdateTask` returns `{ status: 'ACCEPTED' }` but code reports failure | Branch on `response.error`, not `response.success` — orchestration success responses do not set a boolean `success` field |
| `task.taskType must be one of: ...` from SDK | `taskType` is a closed enum — use `types.FORGE_TASK_TYPES.*` constants from `@forge/teamwork-graph`; arbitrary strings are rejected client-side |
| `task.taskId must be a valid UUID format` | Use `uuid()` (v4) for root tasks and `uuidv5(...)` for children — free-form strings like `"my-app:sync"` are rejected |
| `Failed to schedule child tasks: Not Found - Scan not found` | `scanId` passed to `scheduleChildTask` doesn't match an active scan — ensure you're calling it from within an active `taskRunner` invocation and passing `request.scanId` unchanged |
| `taskRunner` reports `ENTITY_NOT_FOUND` after a successful run | `TaskInfo` was deleted too eagerly — switch to a `completed: true` flag and short-circuit duplicate deliveries instead of deleting the record |
| `taskMetadata` is empty in `taskRunner` | `temporalTaskMetadata`/`persistentTaskMetadata` on `scheduleChildTask` are not reliably propagated back — stash everything the handler needs in `KVS` via `TaskInfo.metadata` |
| `scheduleInterval.value` out of range error | Value must be between 1 and 60; adjust and redeploy |

---

---

## Naming and Logo Guidelines

- Use the **official service name** as the connector name (e.g. `Google Drive`, not `Drive Connector by Acme`)
- Use the **official service logo** for icons — do not modify or combine with your own branding
- These guidelines apply only to the `graph:connector` module; your Forge app itself may use your own branding

