import api, { route, assumeTrustedRoute, storage, invokeRemote } from '@forge/api';
import Resolver from '@forge/resolver';
import { sql } from '@forge/sql';
import { Buffer } from 'buffer';
const { exec } = require('child_process');  // forge-sandbox-no-child-process
const fs = require('fs');  // forge-sandbox-no-filesystem

let cachedConfig = null;  // module-scope variable, written from a handler below
const resolver = new Resolver();

// forge-asapp-user-input-in-path
resolver.define('fetchResource', async ({ payload }) => {
  const res = await api.asApp().requestConfluence(route`/wiki/rest/api/content/${payload.resourceId}`);
  return res.json();
});

// forge-api-fetch-tainted-url
resolver.define('fetchExternal', async ({ payload }) => {
  const r = await api.fetch(payload.url);
  return r.json();
});

// forge-storage-key-user-controlled (the request supplies the whole key)
resolver.define('readKey', async ({ payload }) => {
  return storage.get(payload.key);
});

// forge-jql-cql-injection
resolver.define('search', async ({ payload }) => {
  const jql = `project = ${payload.project} AND assignee = ${payload.user}`;
  const r = await api.asUser().requestJira(route`/rest/api/3/search?jql=${payload.rawJql}`);
  return { jql, status: r.status };
});

// forge-resolver-returns-secret
resolver.define('getConfig', async () => {
  const apiKey = await storage.getSecret('external-api-key');
  return { apiKey, endpoint: 'https://api.example.com' };
});

// forge-token-in-plain-storage
resolver.define('saveToken', async ({ payload, context }) => {
  const accessToken = payload.code;
  await storage.set(`oauth-${context.accountId}`, accessToken);
  return { ok: true };
});

// forge-storage-tainted-key (constant prefix, request-controlled suffix)
resolver.define('track', async ({ payload }) => {
  await storage.set(`hit-${payload.id}`, payload);
  return { ok: true };
});

// forge-hardcoded-account-gate
resolver.define('resetAll', async ({ context }) => {
  if (context.accountId === "63749be6a593cb822e92b8dd") {
    cachedConfig = await storage.get('config');  // forge-module-state-holds-request-data
    return { reset: true };
  }
  return { reset: false };
});

// forge-assume-trusted-route-dynamic-path
resolver.define('issue', async ({ payload }) => {
  const r = await api.asUser().requestJira(assumeTrustedRoute(`/rest/api/3/issue/${payload.key}`));
  return r.json();
});

// forge-dynamic-raw-sql-query
resolver.define('userById', async ({ payload }) => {
  return sql.executeRaw(`SELECT * FROM users WHERE id = ${payload.id}`);
});

// forge-invoke-remote-dynamic-path
resolver.define('proxy', async (req) => {
  return invokeRemote(`/api/${req.payload.path}`);
});

// forge-sandbox-no-dynamic-code
resolver.define('calc', async ({ payload }) => {
  const f = new Function('x', payload.code);
  return { a: eval(payload.expr), b: f(1) };
});

// forge-process-env-mutation
resolver.define('setEnv', async ({ payload }) => {
  process.env.TOKEN = payload.token;
  return { ok: true };
});

// forge-sensitive-data-console-logging
resolver.define('debug', async ({ payload, context }) => {
  console.log('incoming payload', payload);
  console.info(JSON.stringify(context));
  return { ok: true };
});

// forge-atlassian-api-token-basic-auth
resolver.define('legacyCall', async () => {
  const apiToken = "ATATT3xFfGF0abcdefghijklmnopqrstuvwxyz0123456789";
  const encoded = Buffer.from(`user@example.com:${apiToken}`).toString('base64');
  const r = await api.fetch('https://example.atlassian.net/rest/api/3/myself', { headers: { Authorization: `Basic ${encoded}` } });
  return r.status;
});

export const handler = resolver.getDefinitions();
export { exec, fs };
