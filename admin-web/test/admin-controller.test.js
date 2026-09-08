import { describe, expect, test, vi } from "vitest";
import { createAdminController, reportKey } from "../src/admin-controller.js";
import { createAuthenticationInitializer } from "../src/admin-authentication.js";

const deferred = () => { let resolve, reject; const promise = new Promise((yes, no) => { resolve = yes; reject = no; }); return { promise, resolve, reject }; };
function setup(api = {}) {
  const state = { workspaceMode: "applications", filterStatus: "", filterQuery: "", reportFilterStatus: "", reportFilterQuery: "" };
  const notify = vi.fn();
  const render = vi.fn();
  const controller = createAdminController({ state, render, notify, messageForError: (code) => code });
  controller.resetSession({ uid: "admin" }, { audit: async () => ({ events: [] }), ...api });
  state.phase = "ready";
  return { state, controller, notify, render };
}

describe("administrator async ownership", () => {
  test("a session response cannot revive a signed out user", async () => {
    const session = deferred();
    const h = setup({ session: () => session.promise, applications: vi.fn() });
    const work = h.controller.verify();
    h.state.filterQuery = "old account search";
    h.controller.resetSession();
    session.resolve({ admin: { email: "old" } });
    await work;
    expect(h.state.phase).toBe("signedOut");
    expect(h.state.admin).toBeNull();
    expect(h.state.applications).toEqual([]);
    expect(h.state.filterQuery).toBe("");
  });
  test("a rejected old session cannot replace the new account", async () => {
    const session = deferred();
    const h = setup({ session: () => session.promise });
    const work = h.controller.verify();
    h.controller.resetSession({ uid: "new" }, {});
    session.reject({ code: "ADMIN_REQUIRED", status: 403 });
    await work;
    expect(h.state.authUser.uid).toBe("new");
    expect(h.state.phase).toBe("verifying");
    expect(h.state.errorCode).toBe("");
  });
  test("a slower old filter cannot replace the newest results or loading state", async () => {
    const first = deferred(), second = deferred();
    const h = setup({ applications: vi.fn().mockReturnValueOnce(first.promise).mockReturnValueOnce(second.promise) });
    const a = h.controller.load({ preserveSelection: false });
    h.state.filterStatus = "approved";
    const b = h.controller.load({ preserveSelection: false });
    first.resolve({ applications: [{ uid: "old" }] });
    await a;
    expect(h.state.listLoading).toBe(true);
    expect(h.state.applications).toEqual([]);
    second.resolve({ applications: [{ uid: "new" }] });
    await b;
    expect(h.state.selectedUid).toBe("new");
    expect(h.state.listLoading).toBe(false);
  });
  test("switching workspaces invalidates old lists and audit completions", async () => {
    const apps = deferred(), audit = deferred();
    const h = setup({ applications: () => apps.promise, audit: () => audit.promise, supportReports: async () => ({ reports: [{ classId: "c", reportId: "r" }] }) });
    h.state.selectedUid = "old";
    const a = h.controller.loadAudit();
    const b = h.controller.load();
    h.state.workspaceMode = "reports";
    await h.controller.load();
    apps.resolve({ applications: [{ uid: "old" }] });
    audit.resolve({ events: [{ note: "old" }] });
    await Promise.all([a, b]);
    expect(h.state.applications).toEqual([]);
    expect(h.state.audit).toEqual([]);
    expect(h.state.selectedReportId).toBe(reportKey({ classId: "c", reportId: "r" }));
  });
  test.each([false, true])("selection during a pending filter cannot discard its new list (reports=%s)", async (reports) => {
    const pending = deferred();
    const h = setup({ applications: () => pending.promise, supportReports: () => pending.promise });
    h.state.workspaceMode = reports ? "reports" : "applications";
    const work = h.controller.load({ preserveSelection: false });
    if (reports) h.controller.selectReport(reportKey({ classId: "old", reportId: "r" }));
    else await h.controller.selectApplication("old");
    expect(h.state.listLoading).toBe(true);
    pending.resolve(reports ? { reports: [{ classId: "new", reportId: "r" }] } : { applications: [{ uid: "new" }] });
    await work;
    expect(reports ? h.state.selectedReportId : h.state.selectedUid).toBe(reports ? reportKey({ classId: "new", reportId: "r" }) : "new");
    expect(h.state.listLoading).toBe(false);
  });
  test("audit is keyed to the selected applicant even when replies reverse", async () => {
    const first = deferred(), second = deferred();
    const h = setup({ audit: vi.fn().mockReturnValueOnce(first.promise).mockReturnValueOnce(second.promise) });
    const a = h.controller.selectApplication("a");
    const b = h.controller.selectApplication("b");
    second.resolve({ events: [{ note: "B" }] }); await b;
    first.resolve({ events: [{ note: "A" }] }); await a;
    expect(h.state.audit).toEqual([{ note: "B" }]);
    expect(h.state.selectedUid).toBe("b");
  });
  test("clearing selection clears both audit and its pending loading state", async () => {
    const pending = deferred();
    const h = setup({ audit: () => pending.promise });
    const work = h.controller.selectApplication("a");
    await h.controller.selectApplication("");
    expect(h.state.auditLoading).toBe(false);
    pending.reject({ code: "old failure" }); await work;
    expect(h.state.auditErrorCode).toBe("");
  });
  test("a report ID in two classes retains the chosen composite identity", async () => {
    const reports = [{ classId: "a", reportId: "same" }, { classId: "b", reportId: "same" }];
    const h = setup({ supportReports: async () => ({ reports }) });
    h.state.workspaceMode = "reports";
    h.state.selectedReportId = reportKey(reports[1]);
    await h.controller.load();
    expect(h.state.selectedReportId).toBe(reportKey(reports[1]));
  });
  test("confirmation keeps immutable target/version and draft through rerenders; double submit is ignored", async () => {
    const save = deferred();
    const review = vi.fn(() => save.promise);
    const h = setup({ review, applications: async () => ({ applications: [] }) });
    const target = { uid: "a", version: "v1", displayName: "A" };
    h.controller.openReview(target, "approved");
    target.version = "v2";
    h.state.selectedUid = "b";
    const work = h.controller.commit("kept draft");
    await h.controller.commit("second draft");
    h.render();
    expect(h.state.reviewNote).toBe("kept draft");
    expect(h.state.reviewTarget.uid).toBe("a");
    expect(h.state.pendingAction).toBe("approved");
    expect(review).toHaveBeenCalledExactlyOnceWith("a", { action: "approved", note: "kept draft", expectedVersion: "v1" });
    save.reject({ code: "NETWORK_ERROR" }); await work;
    expect(h.state.reviewNote).toBe("kept draft");
    expect(h.state.actionLoading).toBe(false);
  });
  test("a completed mutation after logout cannot show success or reload old data", async () => {
    const save = deferred(), applications = vi.fn();
    const h = setup({ review: () => save.promise, applications });
    h.controller.openReview({ uid: "a", version: "v1" }, "approved");
    const work = h.controller.commit("a reason");
    h.controller.resetSession();
    save.resolve({ ok: true }); await work;
    expect(h.notify).not.toHaveBeenCalled();
    expect(applications).not.toHaveBeenCalled();
    expect(h.state.pendingAction).toBe("");
  });
  test("409 reloads report version and requires a fresh explicit confirmation", async () => {
    const report = { classId: "c", reportId: "r", version: "v2" };
    const reviewSupportReport = vi.fn().mockRejectedValueOnce({ status: 409, code: "STALE_SUPPORT_REPORT_VERSION" }).mockResolvedValue({ ok: true });
    const h = setup({ reviewSupportReport, supportReports: async () => ({ reports: [report] }) });
    h.state.workspaceMode = "reports";
    h.controller.openReview({ ...report, version: "v1" }, "resolved", true);
    await h.controller.commit("review evidence", true);
    expect(h.state.reports[0].version).toBe("v2");
    expect(h.state.pendingReportAction).toBe("");
    expect(h.notify.mock.calls.at(-1)[0]).toContain("請重新選擇");
    await h.controller.commit("review evidence", true);
    expect(reviewSupportReport).toHaveBeenCalledTimes(1);
    h.controller.openReview(h.state.reports[0], "resolved", true);
    await h.controller.commit("confirmed again", true);
    expect(reviewSupportReport.mock.calls[1][2].expectedVersion).toBe("v2");
  });
  test("409 reload failure never claims latest data was loaded", async () => {
    const h = setup({ reviewSupportReport: async () => { throw { status: 409 }; }, supportReports: async () => { throw { code: "NETWORK_ERROR" }; } });
    h.state.workspaceMode = "reports";
    h.controller.openReview({ classId: "c", reportId: "r", version: "v1" }, "resolved", true);
    await h.controller.commit("a reason", true);
    expect(h.notify.mock.calls.at(-1)[0]).toContain("重新載入失敗");
    expect(h.state.pendingReportAction).toBe("");
  });
  test("persistence initialization failure is visible and retry registers one listener", async () => {
    const h = setup();
    const persist = vi.fn().mockRejectedValueOnce({ code: "auth/web-storage-unsupported" }).mockResolvedValue();
    const unsubscribe = vi.fn(), listen = vi.fn(() => unsubscribe);
    const start = createAuthenticationInitializer({ ...h, getAuth: () => ({}), persist, listen, createApi: () => ({}) });
    await start();
    expect(h.state.phase).toBe("authInitError");
    expect(h.state.errorCode).toBe("auth/web-storage-unsupported");
    expect(listen).not.toHaveBeenCalled();
    await start();
    expect(listen).toHaveBeenCalledTimes(1);
    listen.mock.calls[0][1](null);
    expect(h.state.phase).toBe("signedOut");
    await start();
    expect(unsubscribe).toHaveBeenCalledTimes(1);
  });
});
