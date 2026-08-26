const durableObjectShim = `
  export class DurableObject {
    constructor(ctx, env) {
      this.ctx = ctx;
      this.env = env;
    }
  }
`;

export async function resolve(specifier, context, nextResolve) {
  if (specifier === "cloudflare:workers") {
    return {
      shortCircuit: true,
      url: `data:text/javascript,${encodeURIComponent(durableObjectShim)}`,
    };
  }

  return nextResolve(specifier, context);
}
