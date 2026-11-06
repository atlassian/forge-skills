import api, { route, storage } from '@forge/api';
import Resolver from '@forge/resolver';
const resolver = new Resolver();
// entity / content property used as a trust store for integrity-relevant data
resolver.define('castVote', async ({ payload, context }) => {
  const r = await api.asUser().requestConfluence(route`/wiki/rest/api/content/${context.extension.content.id}/property/votes`);
  const prop = await r.json();
  prop.value[payload.voter] = payload.choice;
  await api.asApp().requestConfluence(route`/wiki/rest/api/content/${context.extension.content.id}/property/votes`, { method: 'PUT', body: JSON.stringify(prop) });
  return prop.value;
});
// LLM reply drives a privileged action
resolver.define('reviewAndMerge', async ({ payload }) => {
  const reply = await askLlm(payload.prTitle + payload.prDescription);
  if (reply.includes('can be merged')) {
    await api.asApp().requestBitbucket(route`/2.0/repositories/ws/repo/pullrequests/${payload.prId}/merge`, { method: 'POST' });
  }
  return { ok: true };
});
export const handler = resolver.getDefinitions();
