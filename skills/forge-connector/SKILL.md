---

## name: forge-connector
description: >
  Guides building and deploying Atlassian Forge Teamwork Graph connector apps that ingest
  external data into Atlassian's Teamwork Graph, making it searchable in Rovo Search and
  surfaced in Rova Chat. Use when the user wants to build a Forge connector, ingest external
  data into Atlassian, connect a third-party tool (e.g. Google Drive, ServiceNow, Salesforce)
  to Atlassian, make external content searchable in Rovo, build a graph:connector module,
  use the @forge/teamwork-graph SDK, or implement onConnectionChange / validateConnection
  functions. Requires Forge Connector EAP enrollment.
license: Apache-2.0
labels:
  - forge
  - rovo
  - jira
  - atlassian
  - teamwork-graph
  - connector
maintainer: amoore
namespace: cloud

# Forge Connector

Builds a `graph:connector` Forge app that ingests external data into Atlassian's Teamwork Graph so it appears in **Rovo Search** and **Rova Chat**.

## Critical Rules

1. **EAP required** — The `graph:connector` module is gated behind the Forge Connector Early Access Program. If the user is not enrolled, direct them to [express interest](https://developer.atlassian.com/platform/forge/manifest-reference/modules/teamwork-graph-connector/). Do not proceed without EAP access.
2. **Must install in Jira** — Apps using Teamwork Graph modules must be installed on a Jira site. Confluence-only installs will not work.
3. **Never ask for credentials in chat** — Direct users to run `forge login` in their own terminal.
4. **Always run the scaffold script yourself** — Do not only give manual instructions; run `scripts/scaffold_connector.py` to generate the boilerplate.
5. **Always ask the user for their Atlassian site URL** when install is needed — never discover or guess it.
6. **Atlassian deletes data on disconnect** — When `action = 'DELETED'`, the app only needs to clean up local state; Atlassian removes the Teamwork Graph data automatically.

## MCP Prerequisites


| MCP Server    | Purpose                                           |
| ------------- | ------------------------------------------------- |
| **Forge MCP** | Manifest syntax, module config, deployment guides |
| **ADS MCP**   | Atlaskit components (only if adding Custom UI)    |


---

## Agent Workflow — Complete Steps 0–5 in Order

### Step 0: Prerequisites

Check Node.js (`node -v`, requires 22+), Forge CLI (`forge --version`), and login (`forge whoami`). Install missing tools:

```bash
npm install -g @forge/cli
```

Tell the user to run `forge login` in their terminal if not authenticated.

### Step 1: Discover Developer Spaces

```bash
forge developer-spaces list --json
```

Present the list and ask the user to choose one. Never pick on their behalf.

### Step 2: Scaffold the Connector App

Run from the **skill directory** (the directory containing this SKILL.md):

```bash
python3 -m scripts.scaffold_connector \
  --name <app-name> \
  --connector-name "<Human Readable Name>" \
  --object-type atlassian:document \
  --dev-space-id <selected-id> \
  --directory <parent-directory>
```

**Object type selection** — pick the type that best matches the content being ingested (see Object Types table). For mixed content, use `atlassian:document` as the default.

**Form config flag** — add `--has-form-config` if the admin must provide API credentials or connection details (typical for external systems). Omit it for apps that operate entirely within Atlassian (no external credentials needed).

### Step 3: Customize the Generated Code

After scaffolding:

```bash
cd <app-name>
npm install
```

Open `src/index.ts` and replace the placeholder `fetchExternalData()` function with real API calls to your external system. The scaffold generates working handler skeletons; fill in your business logic.

#### Key files to edit


| File           | What to change                                                      |
| -------------- | ------------------------------------------------------------------- |
| `src/index.ts` | `fetchExternalData()` — replace with your API calls                 |
| `manifest.yml` | Add `permissions.external.fetch.backend` URLs for any external APIs |


#### setObjects — ingest data into Teamwork Graph

```typescript
import { setObjects } from '@forge/teamwork-graph';

const result = await setObjects({
  objects: [
    {
      externalId: 'unique-id-from-source',    // must be unique per connectionId
      objectType: 'atlassian:document',
      name: 'My Document Title',
      url: 'https://source-system.example.com/doc/123',
      createdAt: '2024-01-15T10:00:00Z',      // ISO 8601
      lastModifiedAt: '2024-01-20T14:30:00Z',
      properties: {                            // max 5 key-value pairs
        author: 'Jane Smith',
        department: 'Engineering',
      },
    },
  ],
});
// Check for rejections
if (result.results.rejected.length > 0) {
  console.error('Rejected objects:', JSON.stringify(result.results.rejected));
}
```

- Max **100 objects per call** — batch large datasets with a loop
- `externalId` must be globally unique per connector connection; prefix with `connectionId` to avoid collisions

#### deleteObjectsByExternalId — remove objects

```typescript
import { deleteObjectsByExternalId } from '@forge/teamwork-graph';

await deleteObjectsByExternalId({
  objectType: 'atlassian:document',
  externalIds: ['id-1', 'id-2'],  // max 100 per call
});
```

#### getObjectByExternalId — look up a single object

```typescript
import { getObjectByExternalId } from '@forge/teamwork-graph';

const obj = await getObjectByExternalId({
  externalId: 'unique-id-from-source',
  objectType: 'atlassian:document',
});
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

---

## Manifest Reference

### Minimal connector (no admin config, no OAuth)

Use when the app operates entirely within Atlassian — no external credentials needed.

```yaml
app:
  id: <generated-by-forge-create>

permissions:
  scopes:
    - read:graph:teamwork
    - write:graph:teamwork

modules:
  graph:connector:
    - key: my-connector
      name: My Service
      icons:
        24x24: https://cdn.example.com/logo-24.png
        48x48: https://cdn.example.com/logo-48.png
      objectTypes:
        - atlassian:document
      datasource:
        onConnectionChange:
          function: on-connection-change

function:
  - key: on-connection-change
    handler: index.onConnectionChangeHandler
```

### Connector with admin form config (API key / URL)

Use when the admin must provide credentials to connect to an external system.

```yaml
app:
  id: <generated-by-forge-create>

permissions:
  scopes:
    - read:graph:teamwork
    - write:graph:teamwork
  external:
    fetch:
      backend:
        - 'https://api.your-service.com'

modules:
  graph:connector:
    - key: my-connector
      name: My Service
      icons:
        24x24: https://cdn.example.com/logo-24.png
        48x48: https://cdn.example.com/logo-48.png
      objectTypes:
        - atlassian:document
      datasource:
        formConfiguration:
          beforeYouBegin: |
            Provide your My Service API credentials below.
            You can find these in My Service → Settings → API.
          fields:
            - key: api-url
              type: string
              label: API URL
              isRequired: true
            - key: api-key
              type: string
              label: API Key
              isRequired: true
          validateConnection:
            function: validate-connection
        onConnectionChange:
          function: on-connection-change

function:
  - key: on-connection-change
    handler: index.onConnectionChangeHandler
  - key: validate-connection
    handler: index.validateConnectionHandler
```

---

## Handler Signatures

### onConnectionChange

```typescript
export async function onConnectionChangeHandler(event: {
  context: { cloudId: string; moduleKey: string };
  payload: {
    action: 'CREATED' | 'UPDATED' | 'DELETED';
    connectionId: string;
    config: Record<string, string>;  // matches your formConfiguration fields
  };
}) {
  const { action, connectionId, config } = event.payload;

  if (action === 'DELETED') {
    // Atlassian removes Teamwork Graph data automatically.
    // Only clean up your own local state (e.g. stored credentials).
    await storage.delete(`conn:${connectionId}`);
    return;
  }

  // CREATED or UPDATED — persist config and ingest data
  await storage.set(`conn:${connectionId}`, config);
  await ingestAllData(connectionId, config);
}
```

### validateConnection

```typescript
export async function validateConnectionHandler(event: {
  context: { cloudId: string; moduleKey: string };
  payload: { config: Record<string, string> };
}) {
  const { config } = event.payload;

  // Throw an Error to reject the connection with a user-visible message.
  // Return (any value) to accept.
  const response = await api.fetch(`${config['api-url']}/health`, {
    headers: { Authorization: `Bearer ${config['api-key']}` },
  });
  if (!response.ok) {
    throw new Error('Invalid API credentials. Please check your API URL and key.');
  }
}
```

---

## Object Types

Objects in **bold** are indexed in Rovo Search and Rova Chat.


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

## Rovo Search / Rova Chat Surfacing

Once ingested:

- Objects appear in **Rovo Search** under a subfilter named after the connector's nickname (set by admin at connection time)
- **Rova Chat** can reference and cite connector objects in responses when queried about topics related to the ingested content
- Data is not available immediately — allow a few minutes for indexing after `onConnectionChange` fires

To verify ingestion is working:

1. Open Rovo Search on the Jira site
2. Search for text that appears in an ingested object's `name` or `properties`
3. Filter by the connector nickname to narrow results

---

## Batching Pattern for Large Datasets

```typescript
const BATCH_SIZE = 100;

async function ingestAllData(connectionId: string, config: Record<string, string>) {
  const items = await fetchExternalData(config);

  for (let i = 0; i < items.length; i += BATCH_SIZE) {
    const batch = items.slice(i, i + BATCH_SIZE);
    const result = await setObjects({
      objects: batch.map(item => ({
        externalId: `${connectionId}:${item.id}`,
        objectType: 'atlassian:document',
        name: item.title,
        url: item.url,
        createdAt: item.createdAt,
        lastModifiedAt: item.updatedAt,
        properties: { source: config['api-url'] ?? 'external' },
      })),
    });
    if (result.results.rejected.length > 0) {
      console.error('[connector] rejected objects:', JSON.stringify(result.results.rejected));
    }
  }
}
```

---

## Scheduled Re-Ingestion (optional)

To keep data fresh, add a scheduled trigger that re-runs ingestion periodically:

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

```typescript
export async function refreshIngestionHandler() {
  // List all active connections from storage and re-ingest each
  const connectionIds: string[] = await storage.get('active-connections') ?? [];
  for (const connectionId of connectionIds) {
    const config = await storage.get(`conn:${connectionId}`);
    if (config) await ingestAllData(connectionId, config);
  }
}
```

---

## Scripts


| Script                          | Skill directory                                   | Purpose                                                                                                                         |
| ------------------------------- | ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `scripts/scaffold_connector.py` | `skills/forge-connector/` (this skill)            | Scaffold a new connector app — generates manifest.yml, src/index.ts, installs SDK. Run: `python3 -m scripts.scaffold_connector` |
| `scripts/deploy_forge_app.py`   | `skills/forge-app-builder/` (**different skill**) | Deploy and install on Jira. Run from the forge-app-builder directory: `python3 -m scripts.deploy_forge_app`                     |


The scaffold script is in this skill's directory. The deploy script is in the **forge-app-builder** skill directory — always `cd` there (or derive the path from this SKILL.md's location) before running it.

---

## Troubleshooting


| Problem                                      | Action                                                                                                                                      |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `graph:connector` not recognized in manifest | Confirm EAP enrollment; `forge lint` will show unknown module                                                                               |
| `onConnectionChange` not triggered           | Verify admin clicked "Connect" in Atlassian Administration → Connected apps                                                                 |
| Objects not appearing in Rovo Search         | Wait ~5 minutes for indexing; check `forge logs` for `setObjects` errors                                                                    |
| `setObjects` returns rejected objects        | Check `objectType` is a valid value; check `externalId` uniqueness                                                                          |
| 403 on `@forge/teamwork-graph` calls         | Ensure `read:graph:teamwork` and `write:graph:teamwork` scopes are in manifest, then redeploy and `forge install --upgrade`                 |
| `forge create` fails                         | See forge-app-builder skill for error handling table                                                                                        |
| `forge login` required                       | Create API token at [https://id.atlassian.com/manage/api-tokens](https://id.atlassian.com/manage/api-tokens), run `forge login` in terminal |


---

## Naming and Logo Guidelines

- Use the **official service name** as the connector name (e.g. `Google Drive`, not `Drive Connector by Acme`)
- Use the **official service logo** for icons — do not modify or combine with your own branding
- These guidelines apply only to the `graph:connector` module; your Forge app itself may use your own branding

