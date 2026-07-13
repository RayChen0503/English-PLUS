const cloudflareStub = new URL(
  "../workers/englishplus-ai-proxy/test/cloudflare-workers.stub.js",
  import.meta.url
).href;

export async function resolve(specifier, context, nextResolve) {
  if (specifier === "cloudflare:workers") {
    return { url: cloudflareStub, shortCircuit: true };
  }
  return nextResolve(specifier, context);
}
