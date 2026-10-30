import { storage } from '@forge/api';
export const onInstall = async ({ payload, context }) => {
  await storage.setSecret('installer-token', payload.installationToken);
  return { ok: true, cloudId: context.cloudId };
};
