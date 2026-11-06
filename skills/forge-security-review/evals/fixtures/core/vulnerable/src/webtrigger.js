import { storage } from '@forge/api';
import jwt from 'jsonwebtoken';

// forge-webtrigger-missing-auth
export const handler = async (event) => {
  const data = JSON.parse(event.body);
  await storage.set(`sync-${data.tenantId}`, data.payload);
  return { statusCode: 200, body: 'ok' };
};

// forge-jwt-literal-secret
export async function jwtHandler(event, context) {
  const token = event.headers['x-token'];
  const claims = jwt.verify(token, "secret :O", { algorithms: ['HS256'] });
  const stored = await storage.getSecret('sharedSecret');
  return { statusCode: 200, body: JSON.stringify({ sub: claims.sub, hasStored: Boolean(stored) }) };
}

// forge-webtrigger-missing-auth (second handler, reads query parameters)
export async function reportTrigger(event) {
  const params = event.queryParameters || {};
  const report = await generateReport(params.scope);
  return { statusCode: 200, body: report };
}

// forge-webtrigger-html-response-interpolation
export async function corsHandler(event) {
  const name = (event.queryParameters && event.queryParameters.name) || 'anonymous';
  const html = `<div class="greeting">Hello ${name}</div>`;
  return { statusCode: 200, headers: { 'Content-Type': ['text/html'], 'Access-Control-Allow-Origin': ['*'] }, body: html };
}

async function generateReport(scope) { return `report:${scope}`; }
