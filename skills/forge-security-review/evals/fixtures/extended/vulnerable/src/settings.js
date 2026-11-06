import api, { route, storage } from '@forge/api';
import Resolver from '@forge/resolver';
const resolver = new Resolver();
// vulnerable: platform identifier with a client fallback
resolver.define('getRepoSettings', async ({ payload, context }) => {
  const repoId = context.extension?.repository?.uuid ?? payload.uuid;
  const workspace = context.extension.workspace.uuid || payload.workspaceUuid;
  const who = context.accountId || payload.accountId;
  return storage.get(`settings-${repoId}-${workspace}-${who}`);
});
resolver.define('getRepoSettings2', async (req) => {
  const repoId = req.context.extension.repository.uuid ?? req.payload.uuid;
  return storage.get(`settings-${repoId}`);
});
// safe: context only, fail closed
resolver.define('getRepoSettingsSafe', async ({ context }) => {
  const repoId = context.extension?.repository?.uuid;
  if (!repoId) throw new Error('missing context');
  return storage.get(`settings-${repoId}`);
});
