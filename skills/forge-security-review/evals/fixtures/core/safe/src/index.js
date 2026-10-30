import api, { route, storage, startsWith } from '@forge/api';
import Resolver from '@forge/resolver';
import { sql } from '@forge/sql';
import { z } from 'zod';

const CONFIG_KEY = 'config';
const REPORT_URL = 'https://api.example.com/data/summary';
const resolver = new Resolver();

resolver.define('fetchResource', async ({ context }) => {
  const pageId = context.extension.content.id;
  const res = await api.asUser().requestConfluence(route`/wiki/rest/api/content/${pageId}`);
  return res.json();
});

resolver.define('fetchExternal', async () => {
  const r = await api.fetch(REPORT_URL);
  return r.json();
});

resolver.define('readMine', async ({ context }) => {
  return storage.get(`prefs-${context.accountId}`);
});

resolver.define('listMine', async ({ context }) => {
  const { results } = await storage.query().where('key', startsWith(`user-${context.accountId}-`)).getMany();
  return results;
});

resolver.define('search', async ({ payload }) => {
  const VALID_KEY = /^[A-Z][A-Z0-9]+$/;
  if (!VALID_KEY.test(payload.project)) throw new Error('Invalid project key');
  const r = await api.asUser().requestJira(route`/rest/api/3/search?jql=assignee%20%3D%20currentUser()%20AND%20resolution%20%3D%20Unresolved&fields=summary&maxResults=20`);
  return { status: r.status };
});

resolver.define('getConfig', async () => {
  const apiKey = await storage.getSecret('external-api-key');
  const r = await api.fetch(REPORT_URL, { headers: { Authorization: `Bearer ${apiKey}` } });
  return { user: (await r.json()).user };
});

resolver.define('saveToken', async ({ payload, context }) => {
  const accessToken = payload.code;
  await storage.setSecret(`oauth-${context.accountId}`, accessToken);
  return { ok: true };
});

const UserSchema = z.object({ id: z.string().max(64), name: z.string().max(100) }).strict();
resolver.define('track', async ({ payload, context }) => {
  if (!context.accountId) throw new Error('Authentication required');
  const user = UserSchema.parse(payload);
  await storage.set(`hit-${context.accountId}-${user.id}`, user);
  return { ok: true };
});

resolver.define('resetAll', async ({ context }) => {
  const perms = await api.asUser().requestJira(route`/rest/api/3/mypermissions?permissions=ADMINISTER`);
  const body = await perms.json();
  if (!body.permissions.ADMINISTER.havePermission) throw new Error('Forbidden');
  await storage.delete(CONFIG_KEY);
  return { reset: true };
});

resolver.define('issue', async ({ payload }) => {
  if (!/^[A-Z]+-\d+$/.test(payload.key)) throw new Error('Invalid key');
  const r = await api.asUser().requestJira(route`/rest/api/3/issue/${payload.key}`);
  return r.json();
});

resolver.define('userById', async ({ payload }) => {
  const q = sql.prepare('SELECT * FROM users WHERE id = ?');
  return q.bindParams(Number(payload.id)).execute();
});

resolver.define('debug', async ({ payload }) => {
  console.log('debug call', { user: payload.user });
  return { ok: true };
});

export const handler = resolver.getDefinitions();
