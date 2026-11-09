import { storage } from '@forge/api';
import crypto from 'crypto';

// Web trigger authenticated with an HMAC over the body, using a secret from storage and a
// constant-time comparison. No literal secret, no plain equality on a header.
export const handler = async (event) => {
  const secret = await storage.getSecret('webhook-secret');
  const expected = crypto.createHmac('sha256', secret).update(event.body || '').digest('hex');
  const provided = (event.headers['x-signature'] || [''])[0];
  if (provided.length !== expected.length || !crypto.timingSafeEqual(Buffer.from(provided), Buffer.from(expected))) {
    return { statusCode: 401 };
  }
  const data = JSON.parse(event.body);
  if (typeof data.id !== 'string' || !/^[a-z0-9-]{1,64}$/.test(data.id)) {
    return { statusCode: 400 };
  }
  await storage.set(`sync-${data.id}`, { receivedAt: Date.now() });
  return { statusCode: 200 };
};
