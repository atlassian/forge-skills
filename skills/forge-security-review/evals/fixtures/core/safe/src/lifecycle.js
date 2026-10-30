import { storage } from '@forge/api';
export const onInstall = async ({ context }) => {
  await storage.set(`install:${context.cloudId}`, { installedAt: Date.now() });
  return { ok: true };
};
