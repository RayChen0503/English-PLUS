// Async workspace state belongs to one authenticated session and one request.
export const reportKey = (report) => JSON.stringify([report.classId, report.reportId]);

export function createAdminController({ state, render, notify, messageForError }) {
  let epoch = 0;
  const generations = new Map();
  const begin = (channel) => {
    const generation = (generations.get(channel) || 0) + 1;
    generations.set(channel, generation);
    const session = epoch;
    const api = state.api;
    return { api, current: () => epoch === session && generations.get(channel) === generation && state.api === api };
  };
  const invalidate = (channel) => generations.set(channel, (generations.get(channel) || 0) + 1);
  function resetSession(user = null, api = null) {
    epoch += 1;
    generations.clear();
    Object.assign(state, {
      authUser: user, api, admin: null, phase: user ? "verifying" : "signedOut",
      applications: [], reports: [], audit: [], selectedUid: "", selectedReportId: "",
      summary: {}, reportSummary: {}, listLoading: false, auditLoading: false, actionLoading: false,
      pendingAction: "", pendingReportAction: "", reviewTarget: null, reportReviewTarget: null,
      reviewNote: "", reportReviewNote: "", errorCode: "", errorRequestId: "",
      filterStatus: "", filterQuery: "", reportFilterStatus: "", reportFilterQuery: "",
      listErrorCode: "", listErrorRequestId: "", auditErrorCode: "",
    });
    render();
  }
  async function verify() {
    if (!state.api) return;
    invalidate("list");
    invalidate("audit");
    state.listLoading = false;
    state.auditLoading = false;
    const ticket = begin("session");
    state.phase = "verifying";
    render();
    try {
      const result = await ticket.api.session();
      if (!ticket.current()) return;
      state.admin = result.admin;
      state.phase = "ready";
      await load({ preserveSelection: false });
    } catch (error) {
      if (!ticket.current()) return;
      state.errorCode = error?.code || "UNKNOWN";
      state.errorRequestId = error?.requestId || "";
      state.phase = error?.status === 403 ? "unauthorized" : "sessionError";
      render();
    }
  }
  async function loadAudit() {
    const ticket = begin("audit");
    const uid = state.selectedUid;
    state.audit = [];
    state.auditErrorCode = "";
    state.auditLoading = Boolean(uid);
    render();
    if (!uid) return;
    try {
      const result = await ticket.api.audit(uid);
      if (ticket.current() && state.selectedUid === uid) state.audit = result.events || [];
    } catch (error) {
      if (ticket.current() && state.selectedUid === uid) state.auditErrorCode = error?.code || "AUDIT_LIST_FAILED";
    } finally {
      if (ticket.current() && state.selectedUid === uid) { state.auditLoading = false; render(); }
    }
  }
  async function load({ preserveSelection = true } = {}) {
    if (!state.api) return false;
    const ticket = begin("list");
    invalidate("audit");
    state.audit = [];
    state.auditLoading = false;
    const reports = state.workspaceMode === "reports";
    const mode = state.workspaceMode;
    const requestedSelection = reports ? state.selectedReportId : state.selectedUid;
    const filter = reports ? { status: state.reportFilterStatus, query: state.reportFilterQuery } : { status: state.filterStatus, query: state.filterQuery };
    const current = () => ticket.current() && state.workspaceMode === mode;
    state.listLoading = true;
    state.listErrorCode = "";
    state.listErrorRequestId = "";
    render();
    try {
      const result = await (reports ? ticket.api.supportReports(filter) : ticket.api.applications(filter));
      if (!current()) return false;
      if (reports) {
        state.reports = result.reports || [];
        state.reportSummary = result.summary || {};
        if ((!preserveSelection && state.selectedReportId === requestedSelection) || !state.reports.some((item) => reportKey(item) === state.selectedReportId)) state.selectedReportId = state.reports[0] ? reportKey(state.reports[0]) : "";
      } else {
        state.applications = result.applications || [];
        state.summary = result.summary || {};
        if ((!preserveSelection && state.selectedUid === requestedSelection) || !state.applications.some((item) => item.uid === state.selectedUid)) state.selectedUid = state.applications[0]?.uid || "";
        await loadAudit();
      }
      return current();
    } catch (error) {
      if (!current()) return false;
      state.listErrorCode = error?.code || (reports ? "SUPPORT_REPORT_LIST_FAILED" : "APPLICATION_LIST_FAILED");
      state.listErrorRequestId = error?.requestId || "";
      return false;
    } finally {
      if (current()) { state.listLoading = false; render(); }
    }
  }
  function selectApplication(uid) {
    state.selectedUid = uid;
    return loadAudit();
  }
  function openReview(target, action, reports = false) {
    if (!target || state.actionLoading) return;
    state[reports ? "reportReviewTarget" : "reviewTarget"] = Object.freeze({ ...target });
    state[reports ? "pendingReportAction" : "pendingAction"] = action;
    state[reports ? "reportReviewNote" : "reviewNote"] = "";
    render();
  }
  function selectReport(key) {
    state.selectedReportId = key;
    render();
  }
  function closeReview(reports = false) {
    if (state.actionLoading) return;
    state[reports ? "pendingReportAction" : "pendingAction"] = "";
    state[reports ? "reportReviewTarget" : "reviewTarget"] = null;
    state[reports ? "reportReviewNote" : "reviewNote"] = "";
    render();
  }
  async function commit(note, reports = false) {
    const target = state[reports ? "reportReviewTarget" : "reviewTarget"];
    const action = state[reports ? "pendingReportAction" : "pendingAction"];
    if (!target || !action || state.actionLoading) return;
    if (note.trim().length < 3) { notify("請填寫至少 3 個字的處理原因。", "error"); return; }
    const ticket = begin("action");
    state[reports ? "reportReviewNote" : "reviewNote"] = note;
    state.actionLoading = true;
    render();
    try {
      const payload = { action, note, expectedVersion: target.version };
      await (reports ? ticket.api.reviewSupportReport(target.classId, target.reportId, payload) : ticket.api.review(target.uid, payload));
      if (!ticket.current()) return;
      state.actionLoading = false;
      closeReview(reports);
      notify(reports ? "檢舉案件狀態與處理紀錄已更新。" : "審核結果已儲存，帳號狀態也已同步更新。", "success");
      await load();
    } catch (error) {
      if (!ticket.current()) return;
      state.actionLoading = false;
      if (error?.status === 409) {
        closeReview(reports);
        const loaded = await load();
        if (!ticket.current()) return;
        notify(loaded ? "資料已被其他管理員更新，已載入最新狀態。請重新選擇處理動作並確認。" : "資料已被其他管理員更新；重新載入失敗，請重新整理後再確認處理動作。", "error");
      } else notify(messageForError(error?.code, reports), "error");
    } finally {
      if (ticket.current()) { state.actionLoading = false; render(); }
    }
  }
  return { resetSession, verify, load, loadAudit, selectApplication, selectReport, openReview, closeReview, commit, sessionTicket: () => { const session = epoch; return () => session === epoch; } };
}
