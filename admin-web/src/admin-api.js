export class AdminApiError extends Error {
  constructor(code, status, requestId = "") {
    super(code || "REQUEST_FAILED");
    this.name = "AdminApiError";
    this.code = code || "REQUEST_FAILED";
    this.status = status;
    this.requestId = requestId;
  }
}

export function createAdminApi({ baseURL, getToken, fetchImpl = fetch }) {
  async function request(path, options = {}, retry = true) {
    const token = await getToken(!retry);
    const requestId = crypto.randomUUID();
    const response = await fetchImpl(new URL(path, baseURL), {
      ...options,
      headers: {
        Accept: "application/json",
        Authorization: `Bearer ${token}`,
        "X-EnglishPlus-Request-ID": requestId,
        ...(options.body ? { "Content-Type": "application/json" } : {}),
        ...options.headers,
      },
    });

    if (response.status === 401 && retry) {
      return request(path, options, false);
    }

    const responseRequestId =
      response.headers.get("X-EnglishPlus-Request-ID") || requestId;
    if (!response.ok) {
      let payload = {};
      try {
        payload = await response.json();
      } catch {
        // A non-JSON upstream error still maps to a stable user-facing code.
      }
      throw new AdminApiError(
        payload.error || `HTTP_${response.status}`,
        response.status,
        payload.requestId || responseRequestId
      );
    }
    return response;
  }

  return Object.freeze({
    async session() {
      return (await request("/admin/session")).json();
    },
    async applications({ status = "", query = "" } = {}) {
      const url = new URL("/admin/volunteer-applications", baseURL);
      url.searchParams.set("scope", "all");
      if (status) url.searchParams.set("status", status);
      if (query) url.searchParams.set("query", query);
      return (await request(`${url.pathname}${url.search}`)).json();
    },
    async audit(uid) {
      const path = `/admin/volunteer-audit?uid=${encodeURIComponent(uid)}`;
      return (await request(path)).json();
    },
    async review(uid, { action, note, expectedVersion }) {
      return (
        await request(`/admin/volunteer-review/${encodeURIComponent(uid)}`, {
          method: "POST",
          body: JSON.stringify({ action, note, expectedVersion }),
        })
      ).json();
    },
    async evidence(objectKey) {
      const path = `/admin/evidence?objectKey=${encodeURIComponent(objectKey)}`;
      return request(path, { headers: { Accept: "*/*" } });
    },
  });
}
