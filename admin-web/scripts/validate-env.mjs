import { loadEnv } from "vite";

const mode = process.argv[2];
const environments = {
  competition: {
    projectId: "englishplus-testflight",
    workerHost: "englishplus-ai-proxy.englishplus-ray.workers.dev",
  },
  production: {
    projectId: "englishplus-production",
    workerHost: "englishplus-ai-proxy-production.englishplus-ray.workers.dev",
  },
};

const expected = environments[mode];
if (!expected) {
  throw new Error("Environment must be competition or production.");
}

const env = loadEnv(mode, process.cwd(), "");
const required = [
  "VITE_ENGLISHPLUS_ENVIRONMENT",
  "VITE_FIREBASE_PROJECT_ID",
  "VITE_FIREBASE_APP_ID",
  "VITE_FIREBASE_STORAGE_BUCKET",
  "VITE_FIREBASE_API_KEY",
  "VITE_FIREBASE_AUTH_DOMAIN",
  "VITE_FIREBASE_MESSAGING_SENDER_ID",
  "VITE_ADMIN_API_BASE_URL",
];

for (const key of required) {
  if (!env[key]?.trim()) {
    throw new Error(`Missing required English+ environment value: ${key}`);
  }
}

if (env.VITE_ENGLISHPLUS_ENVIRONMENT !== mode) {
  throw new Error(`Admin environment label does not match ${mode}.`);
}

if (env.VITE_FIREBASE_PROJECT_ID !== expected.projectId) {
  throw new Error(`Firebase project does not match ${mode}.`);
}

if (new URL(env.VITE_ADMIN_API_BASE_URL).host !== expected.workerHost) {
  throw new Error(`Admin API does not match ${mode}.`);
}

console.log(`English+ ${mode} admin environment validated.`);
