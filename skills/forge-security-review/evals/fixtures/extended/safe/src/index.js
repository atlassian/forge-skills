// Safe twin of ../../vulnerable: the same features written the way the coverage rules expect.
// Every rule in assets/opengrep-rules/forge-security-rules.yaml must stay silent on this app.
import api, { route, storage, fetch } from '@forge/api';
import Resolver from '@forge/resolver';
import { z } from 'zod';
import pick from 'lodash/pick';

const resolver = new Resolver();

const SettingsSchema = z.object({ theme: z.string(), language: z.string() }).strict();

async function requireAdmin(context) {
  const r = await api.asUser().requestJira(route`/rest/api/3/mypermissions?permissions=ADMINISTER`);
  const perms = await r.json();
  if (!perms.permissions.ADMINISTER.havePermission) {
    throw new Error('Forbidden');
  }
}

// Config is merged from an allowlisted, schema-validated copy of the payload, never the raw object.
resolver.define('saveConfig', async ({ payload, context }) => {
  await requireAdmin(context);
  const current = (await storage.get('config')) || {};
  const settings = SettingsSchema.parse(payload.settings);
  const merged = { ...current, ...pick(settings, ['theme', 'language']) };
  await storage.set('config', merged);
  return { ok: true };
});

// Identity comes from the invocation context only; the client cannot choose the record.
resolver.define('getProfile', async ({ context }) => {
  const owner = context.accountId;
  if (!owner) throw new Error('missing context');
  return storage.get(`profile-${owner}`);
});

// Request options are built from constants; nothing from the payload reaches the headers.
resolver.define('proxyCall', async () => {
  const res = await api.asUser().requestJira(route`/rest/api/3/myself`, {
    headers: { Accept: 'application/json' },
  });
  return res.json();
});

// JQL is assembled from validated, server-controlled parts and sent as the caller.
resolver.define('searchAll', async ({ payload }) => {
  if (!/^[A-Z][A-Z0-9]{1,9}$/.test(payload.projectKey)) throw new Error('invalid project key');
  const r = await api.asUser().requestJira(route`/rest/api/3/search/jql`, {
    method: 'POST',
    body: JSON.stringify({ jql: `project = ${payload.projectKey} ORDER BY created DESC`, fields: ['summary'] }),
  });
  return r.json();
});

// Installation-wide write guarded by an explicit permission check.
resolver.define('saveGlobalSettings', async ({ payload, context }) => {
  await requireAdmin(context);
  const settings = SettingsSchema.parse(payload.settings);
  await storage.set('global-settings', settings);
  return { ok: true };
});

// Platform identifier used on its own, failing closed when it is missing.
resolver.define('getRepoSettings', async ({ context }) => {
  const repoId = context.extension?.repository?.uuid;
  if (!repoId) throw new Error('missing context');
  return storage.get(`settings-${repoId}`);
});

// Model output is advisory; the privileged action needs a human decision carried in the context.
resolver.define('reviewPullRequest', async ({ payload, context }) => {
  await requireAdmin(context);
  const reply = await askLlm(payload.prTitle);
  return { suggestion: reply };
});

// Bitbucket access uses the Forge-issued app identity, not a stored bot credential.
export async function listPullRequests() {
  const r = await api.asApp().requestBitbucket(route`/2.0/repositories/ws/repo/pullrequests`);
  return r.status;
}

// Outbound call to a declared host with a constant URL and constant headers.
export async function notifyBackend() {
  const r = await fetch('https://backend.example.com/api/notify', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ event: 'settings-saved' }),
  });
  return r.status;
}

async function askLlm(text) {
  return `summary of ${text}`;
}

export const handler = resolver.getDefinitions();
