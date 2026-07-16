const requiredValue = (key) => {
  const value = import.meta.env[key]?.trim();
  if (!value) {
    throw new Error(`Missing required English+ environment value: ${key}`);
  }
  return value;
};

export const deploymentEnvironment = requiredValue("VITE_ENGLISHPLUS_ENVIRONMENT");
const expectedProjectId = deploymentEnvironment === "competition"
  ? "englishplus-testflight"
  : deploymentEnvironment === "production"
    ? "englishplus-production"
    : null;

if (!expectedProjectId) {
  throw new Error("VITE_ENGLISHPLUS_ENVIRONMENT must be competition or production.");
}

export const firebaseConfig = Object.freeze({
  projectId: requiredValue("VITE_FIREBASE_PROJECT_ID"),
  appId: requiredValue("VITE_FIREBASE_APP_ID"),
  storageBucket: requiredValue("VITE_FIREBASE_STORAGE_BUCKET"),
  apiKey: requiredValue("VITE_FIREBASE_API_KEY"),
  authDomain: requiredValue("VITE_FIREBASE_AUTH_DOMAIN"),
  messagingSenderId: requiredValue("VITE_FIREBASE_MESSAGING_SENDER_ID"),
});

export const canonicalAdminOrigin = `https://${firebaseConfig.authDomain}`;
export const canonicalWebAppHost = firebaseConfig.authDomain.replace(
  ".firebaseapp.com",
  ".web.app",
);

if (firebaseConfig.projectId !== expectedProjectId) {
  throw new Error(`Firebase project does not match ${deploymentEnvironment}.`);
}

export const adminApiBaseURL = requiredValue("VITE_ADMIN_API_BASE_URL");
const expectedWorkerHost = deploymentEnvironment === "competition"
  ? "englishplus-ai-proxy.englishplus-ray.workers.dev"
  : "englishplus-ai-proxy-production.englishplus-ray.workers.dev";

if (new URL(adminApiBaseURL).host !== expectedWorkerHost) {
  throw new Error(`Admin API does not match ${deploymentEnvironment}.`);
}
