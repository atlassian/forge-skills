# Forge Connector Skill

Build Atlassian Forge apps that ingest external data into the **Teamwork Graph**, making it searchable in **Rovo Search** and referenceable in **Rovo Chat**.

## What This Skill Does

Guides the agent through the full connector workflow:

1. Scaffold a `graph:connector` Forge app from scratch
2. Configure `manifest.yml` with correct module structure, scopes, and function keys
3. Implement `onConnectionChangeHandler` and `validateConnectionHandler` using `@forge/teamwork-graph`
4. Deploy and install on a Jira site
5. Connect via Atlassian Administration → Connected apps
6. Verify ingested data appears in Rovo Search

## Prerequisites

- **Node.js 22+** — `node -v`
- **Forge CLI** — `npm install -g @forge/cli`
- **Forge login** — `forge login`
- **Jira site** — connector apps must be installed in Jira (not Confluence-only)

## Quick Start

```bash
# From the forge-connector skill directory:
python3 -m scripts.scaffold_connector \
  --name my-service-connector \
  --connector-name "My Service" \
  --object-type atlassian:document \
  --dev-space-id <your-dev-space-id> \
  --directory ~/projects \
  --has-form-config \
  --api-url https://api.myservice.com
```

Then deploy (using the forge-app-builder deploy script):

```bash
python3 -m scripts.deploy_forge_app \
  --app-dir ~/projects/my-service-connector \
  --site yourcompany.atlassian.net \
  --product jira
```

## Object Types Indexed in Rovo Search

`atlassian:document` · `atlassian:message` · `atlassian:work-item` · `atlassian:project` · `atlassian:space` · `atlassian:design` · `atlassian:repository` · `atlassian:pull-request` · `atlassian:commit` · `atlassian:branch` · `atlassian:conversation` · `atlassian:video` · `atlassian:calendar-event` · `atlassian:comment` · `atlassian:customer-organization`

## SDK Reference

```typescript
import { setObjects, deleteObjectsByExternalId, getObjectByExternalId } from '@forge/teamwork-graph';

// Ingest (up to 100 objects per call)
await setObjects({ objects: [...] });

// Delete
await deleteObjectsByExternalId({ objectType: 'atlassian:document', externalIds: ['id-1'] });

// Fetch single object
const obj = await getObjectByExternalId({ externalId: 'id-1', objectType: 'atlassian:document' });
```

## Scripts

| Script | Purpose |
|---|---|
| `scripts/scaffold_connector.py` | Scaffold complete connector app boilerplate |

## Further Reading

- [graph:connector manifest reference](https://developer.atlassian.com/platform/forge/manifest-reference/modules/teamwork-graph-connector/)
- [Build a Teamwork Graph connector tutorial](https://developer.atlassian.com/platform/teamwork-graph/build-a-teamwork-graph-connector/)
- [Teamwork Graph object types](https://developer.atlassian.com/platform/teamwork-graph/object-types/)
- [Forge documentation](https://developer.atlassian.com/platform/forge/)
