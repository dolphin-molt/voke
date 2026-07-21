import { hasAdminConfig, isAdmin, json } from '../../_lib/admin-auth.js';

export async function onRequestGet(context) {
  return json({
    configured: hasAdminConfig(context.env),
    authenticated: await isAdmin(context.request, context.env),
  });
}
