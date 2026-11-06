import api, { route, storage, fetch, startsWith } from '@forge/api';
import Resolver from '@forge/resolver';
import jwt from 'jsonwebtoken';
const resolver = new Resolver();

// manual OAuth client with client_secret in the body
resolver.define('exchange', async ({ payload }) => {
  const secret = await storage.getSecret('client-secret');
  const r = await fetch('https://idp.example.com/oauth/token', {
    method: 'POST',
    body: `grant_type=authorization_code&code=${payload.code}&client_id=abc&client_secret=${secret}`,
  });
  return (await r.json()).expires_in;
});

// resolver trusts context.extension for authorization-relevant target selection
resolver.define('getIssueSecret', async ({ context }) => {
  const key = context.extension.issue.key;
  const r = await api.asApp().requestJira(route`/rest/api/3/issue/${key}?fields=description`);
  return r.json();
});

// JQL in POST body through asApp (new Jira search API)
resolver.define('searchAll', async ({ payload }) => {
  const r = await api.asApp().requestJira(route`/rest/api/3/search/jql`, {
    method: 'POST', body: JSON.stringify({ jql: payload.jql, fields: ['summary'] }),
  });
  return r.json();
});

// storage.query filter from payload (enumerate other users' records)
resolver.define('listByPrefix', async ({ payload }) => {
  const { results } = await storage.query().where('key', startsWith(payload.prefix)).getMany();
  return results;
});

// Rovo action handler (bare payload parameter) -> asApp delete
export async function deleteIssueAction(payload) {
  const r = await api.asApp().requestJira(route`/rest/api/3/issue/${payload.issueKey}`, { method: 'DELETE' });
  return { status: r.status };
}

// product event content into JQL / HTML (event-driven handler)
export async function onIssueCreated(event) {
  const jqlText = `project = ${event.issue.fields.project.key} AND summary ~ "${event.issue.fields.summary}"`;
  const r = await api.asApp().requestJira(route`/rest/api/3/search?jql=${jqlText}`);
  const html = `<p>${event.issue.fields.summary}</p>`;
  await api.asApp().requestConfluence(route`/wiki/rest/api/content`, { method: 'POST', body: JSON.stringify({ body: { storage: { value: html } } }) });
  return r.status;
}

// resolver performs app-wide write with no permission evidence (direct-invocation class)
resolver.define('saveGlobalSettings', async ({ payload }) => {
  await storage.set('global-settings', payload.settings);
  await api.asApp().requestJira(route`/rest/api/3/project/${payload.projectKey}/properties/app-config`, {
    method: 'PUT', body: JSON.stringify(payload.settings),
  });
  return { ok: true };
});

// app mints its own identity token for a remote backend (client-asserted identity)
resolver.define('callBackend', async ({ context }) => {
  const token = jwt.sign({ sub: context.accountId, cloudId: context.cloudId }, await storage.getSecret('backend-secret'));
  const r = await fetch('https://backend.example.com/api/me', { headers: { Authorization: `Bearer ${token}` } });
  return r.json();
});

export const handler = resolver.getDefinitions();
