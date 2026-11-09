import { invoke, view } from '@forge/bridge';
export async function init() {
  const { sharedSecret, identityToken } = await invoke('getClientCredentials');
  console.log('shared secret', sharedSecret);
  console.debug('identity token', identityToken);
  const ctx = await view.getContext();
  document.getElementById('name').innerHTML = ctx.extension.issue.summary;
}
