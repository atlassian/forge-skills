import { fetch, storage } from '@forge/api';
export async function syncRepo() {
  const botToken = await storage.getSecret('bot-token');
  const encoded = Buffer.from(`bot-user:${botToken}`).toString('base64');
  const r = await fetch('https://api.bitbucket.org/2.0/repositories/ws/repo/pullrequests', { headers: { Authorization: `Basic ${encoded}` } });
  return r.status;
}
export async function headerInjection({ payload }) {
  const r = await fetch('https://api.example.com/x', { headers: { 'X-Api-Key': 'k', ...payload.headers } });
  return r.status;
}
