import { defineConfig } from "vitest/config";
import { fileURLToPath } from "node:url";

export default defineConfig({
  resolve: {
    alias: {
      "cloudflare:workers": fileURLToPath(new URL("./test/cloudflare-workers.stub.js", import.meta.url)),
    },
  },
  test: {
    environment: "node",
    include: [
      "test/account-deletion.test.js",
      "test/ai-actions.test.js",
      "test/security.test.js",
    ],
  },
});
