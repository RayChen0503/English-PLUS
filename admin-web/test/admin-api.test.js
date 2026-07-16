import { describe, expect, test, vi } from "vitest";

import { AdminApiError, createAdminApi } from "../src/admin-api.js";

describe("administrator API client", () => {
  test("adds a Firebase bearer token and requests all application states", async () => {
    const fetchImpl = vi.fn(async () =>
      new Response(JSON.stringify({ ok: true, applications: [] }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      })
    );
    const api = createAdminApi({
      baseURL: "https://worker.example/",
      getToken: async () => "firebase-token",
      fetchImpl,
    });

    await api.applications({ status: "approved", query: "Ray" });

    const [url, options] = fetchImpl.mock.calls[0];
    expect(url.toString()).toBe(
      "https://worker.example/admin/volunteer-applications?scope=all&status=approved&query=Ray"
    );
    expect(options.headers.Authorization).toBe("Bearer firebase-token");
    expect(options.headers["X-EnglishPlus-Request-ID"]).toBeTruthy();
  });

  test("refreshes an expired ID token once after a 401", async () => {
    const fetchImpl = vi
      .fn()
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ error: "AUTH_REQUIRED" }), {
          status: 401,
          headers: { "Content-Type": "application/json" },
        })
      )
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ ok: true, admin: { uid: "admin" } }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      );
    const getToken = vi.fn(async (forceRefresh) =>
      forceRefresh ? "fresh-token" : "cached-token"
    );
    const api = createAdminApi({
      baseURL: "https://worker.example/",
      getToken,
      fetchImpl,
    });

    await expect(api.session()).resolves.toMatchObject({ ok: true });
    expect(getToken.mock.calls).toEqual([[false], [true]]);
    expect(fetchImpl.mock.calls[1][1].headers.Authorization).toBe("Bearer fresh-token");
  });

  test("maps backend failures to stable errors with request references", async () => {
    const fetchImpl = vi.fn(async () =>
      new Response(
        JSON.stringify({
          ok: false,
          error: "STALE_REVIEW_VERSION",
          requestId: "request-123",
        }),
        { status: 409, headers: { "Content-Type": "application/json" } }
      )
    );
    const api = createAdminApi({
      baseURL: "https://worker.example/",
      getToken: async () => "token",
      fetchImpl,
    });

    await expect(
      api.review("volunteer-123", {
        action: "approved",
        note: "",
        expectedVersion: "2026-07-14T00:00:00Z",
      })
    ).rejects.toMatchObject({
      name: "AdminApiError",
      code: "STALE_REVIEW_VERSION",
      status: 409,
      requestId: "request-123",
    });
  });

  test("maps token and network failures without hiding the diagnostic request id", async () => {
    const tokenFailureApi = createAdminApi({
      baseURL: "https://worker.example/",
      getToken: async () => {
        throw new Error("expired");
      },
      fetchImpl: vi.fn(),
    });
    await expect(tokenFailureApi.session()).rejects.toMatchObject({
      code: "AUTH_TOKEN_UNAVAILABLE",
      status: 0,
      requestId: expect.any(String),
    });

    const networkFailureApi = createAdminApi({
      baseURL: "https://worker.example/",
      getToken: async () => "token",
      fetchImpl: async () => {
        throw new TypeError("offline");
      },
    });
    await expect(networkFailureApi.evidencePreview("volunteer-evidence/u/file.pdf")).rejects.toMatchObject({
      code: "NETWORK_ERROR",
      status: 0,
      requestId: expect.any(String),
    });
  });

  test("requests a short-lived evidence preview link instead of fetching binary data", async () => {
    const fetchImpl = vi.fn(async () =>
      new Response(
        JSON.stringify({
          ok: true,
          previewURL: "https://worker.example/admin/evidence-file?ticket=signed",
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      )
    );
    const api = createAdminApi({
      baseURL: "https://worker.example/",
      getToken: async () => "token",
      fetchImpl,
    });

    await expect(api.evidencePreview("volunteer-evidence/user/file.pdf")).resolves.toMatchObject({
      ok: true,
    });
    expect(fetchImpl.mock.calls[0][0].toString()).toContain(
      "/admin/evidence-ticket?objectKey=volunteer-evidence%2Fuser%2Ffile.pdf"
    );
    expect(fetchImpl.mock.calls[0][1].headers.Accept).toBe("application/json");
  });

  test("lists and reviews support reports through administrator-only endpoints", async () => {
    const fetchImpl = vi.fn(async () =>
      new Response(JSON.stringify({ ok: true, reports: [] }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      })
    );
    const api = createAdminApi({
      baseURL: "https://worker.example/",
      getToken: async () => "token",
      fetchImpl,
    });

    await api.supportReports({ status: "open", query: "teacher-1" });
    expect(fetchImpl.mock.calls[0][0].toString()).toBe(
      "https://worker.example/admin/support-reports?status=open&query=teacher-1"
    );

    await api.reviewSupportReport("CLASS-8A", "report-1", {
      action: "resolved",
      note: "已完成查核與處理。",
      expectedVersion: "2026-07-16T00:00:00.000Z",
    });
    const [url, options] = fetchImpl.mock.calls[1];
    expect(url.toString()).toBe(
      "https://worker.example/admin/support-report/CLASS-8A/report-1"
    );
    expect(options.method).toBe("POST");
    expect(JSON.parse(options.body)).toMatchObject({
      action: "resolved",
      note: "已完成查核與處理。",
    });
  });

  test("AdminApiError keeps the original backend status", () => {
    expect(new AdminApiError("ADMIN_REQUIRED", 403, "r1")).toMatchObject({
      code: "ADMIN_REQUIRED",
      status: 403,
      requestId: "r1",
    });
  });
});
