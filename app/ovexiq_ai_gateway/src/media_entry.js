import existingWorker, { authenticateBetaDeviceSession, findTesterId } from './index.js';
import { proxyMedia } from './media_proxy.js';
export { BetaAccount, BetaDailyQuota } from './index.js';

export default {
  fetch(request, env, ctx) {
    if (new URL(request.url).pathname.startsWith('/v1/media/')) {
      return proxyMedia(request, env, { authenticate: authenticateBetaDeviceSession, findTester: findTesterId });
    }
    return existingWorker.fetch(request, env, ctx);
  },
};
