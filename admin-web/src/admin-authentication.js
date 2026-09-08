export function createAuthenticationInitializer({ state, controller, render, getAuth, persist, listen, createApi }) {
  let attempt = 0;
  let unsubscribe;
  return async function startAuthentication() {
    const current = ++attempt;
    unsubscribe?.();
    unsubscribe = null;
    controller.resetSession();
    state.phase = "starting";
    render();
    try {
      const auth = getAuth();
      state.auth = auth;
      await persist(auth);
      if (current !== attempt) return;
      unsubscribe = listen(auth, (user) => {
        if (current !== attempt) return;
        controller.resetSession(user, user ? createApi(auth, user) : null);
        if (user) void controller.verify();
      });
    } catch (error) {
      if (current !== attempt) return;
      state.phase = "authInitError";
      state.errorCode = error?.code || "auth/initialization-failed";
      render();
    }
  };
}
