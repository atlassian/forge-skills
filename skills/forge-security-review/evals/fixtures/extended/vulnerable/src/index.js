import api, { route, storage, fetch } from '@forge/api';
import Resolver from '@forge/resolver';
import _ from 'lodash';
const resolver = new Resolver();

// prototype-pollution style merge of resolver payload into stored config
resolver.define('saveConfig', async ({ payload }) => {
  const current = (await storage.get('config')) || {};
  const merged = _.merge(current, payload);
  Object.assign(current, payload.settings);
  for (const k in payload.extra) { current[k] = payload.extra[k]; }
  await storage.set('config', merged);
  return { ok: true };
});

// client-supplied identity / role fields trusted for authorization
resolver.define('adminAction', async ({ payload, context }) => {
  if (payload.isAdmin) {
    await storage.set('settings', payload.settings);
  }
  const owner = payload.accountId;
  const rec = await storage.get(`profile-${owner}`);
  return rec;
});

// request headers / options spread from payload into product request (header injection)
resolver.define('proxyCall', async ({ payload }) => {
  const res = await api.asUser().requestJira(route`/rest/api/3/myself`, { headers: payload.headers });
  const res2 = await api.asUser().requestJira(route`/rest/api/3/myself`, { ...payload.options });
  return res.json();
});

// fetch following redirects with tainted URL (redirect-based SSRF bypass)
resolver.define('preview', async ({ payload }) => {
  const r = await fetch(`https://api.example.com/expand?u=${encodeURIComponent(payload.url)}`, { redirect: 'follow' });
  const r2 = await fetch(payload.url, { redirect: 'follow' });
  return r.status;
});

// web trigger with a hardcoded shared secret compared against the request
export const webhook = async (event) => {
  if (event.queryParameters.token[0] !== 'c0ffee-shared-secret') {
    return { statusCode: 401 };
  }
  const data = JSON.parse(event.body);
  await storage.set(`sync-${data.id}`, data);
  return { statusCode: 200 };
};

// private cross-tenant API
export const crossTenant = async () => {
  const r = await api.asApp().__requestAtlassian('/ex/jira/other-cloud-id/rest/api/3/myself');
  return r.status;
};

// manual OAuth client with client_secret in the body
export const exchange = async ({ payload }) => {
  const secret = await storage.getSecret('client-secret');
  const r = await fetch('https://idp.example.com/oauth/token', {
    method: 'POST',
    body: `grant_type=authorization_code&code=${payload.code}&client_id=abc&client_secret=${secret}`,
  });
  return (await r.json()).expires_in;
};

// display-condition-style gate only on client: resolver trusts context.extension for authz
resolver.define('getIssueSecret', async ({ context }) => {
  const key = context.extension.issue.key;
  const r = await api.asApp().requestJira(route`/rest/api/3/issue/${key}?fields=description`);
  return r.json();
});

export const handler = resolver.getDefinitions();
