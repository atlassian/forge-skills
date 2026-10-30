import crypto from 'crypto';
import { storage } from '@forge/api';
import jwt from 'jsonwebtoken';

export const handler = async (event) => {
  const secret = await storage.getSecret('webhook-secret');
  const sig = event.headers['x-webhook-signature'] || '';
  const expected = crypto.createHmac('sha256', secret).update(event.body).digest('hex');
  if (sig.length !== expected.length || !crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(expected))) {
    return { statusCode: 401, body: 'unauthorized' };
  }
  const data = JSON.parse(event.body);
  await storage.set(`sync-${data.tenantId}`, data.payload);
  return { statusCode: 200, body: 'ok' };
};

export async function jwtHandler(event, context) {
  const token = event.headers['x-token'];
  const secret = await storage.getSecret('sharedSecret');
  const claims = jwt.verify(token, secret, { algorithms: ['HS256'] });
  return { statusCode: 200, body: JSON.stringify({ sub: claims.sub }) };
}

export async function reportTrigger(event) {
  const expectedKey = await storage.getSecret('report-api-key');
  const presented = (event.headers['x-api-key'] || [''])[0];
  if (presented.length !== expectedKey.length || !crypto.timingSafeEqual(Buffer.from(presented), Buffer.from(expectedKey))) {
    return { statusCode: 401, body: 'unauthorized' };
  }
  const key = event.headers['idempotency-key'];
  if (await storage.get(`idempotency-${key}`)) return { statusCode: 409, body: 'duplicate' };
  await storage.set(`idempotency-${key}`, true);
  const report = await generateReport((event.queryParameters || {}).scope);
  return { statusCode: 200, body: report };
}

export async function corsHandler(event) {
  const expectedKey = await storage.getSecret('cors-api-key');
  if ((event.headers['x-api-key'] || [''])[0] !== expectedKey) return { statusCode: 401, body: 'unauthorized' };
  const name = String((event.queryParameters && event.queryParameters.name) || 'anonymous');
  const safeName = name.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  return { statusCode: 200, headers: { 'Content-Type': ['text/html'], 'Access-Control-Allow-Origin': ['https://example.atlassian.net'] }, body: `<div class="greeting">Hello ${safeName}</div>` };
}

async function generateReport(scope) { return `report:${scope}`; }
