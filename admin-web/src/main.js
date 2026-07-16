import { initializeApp } from "firebase/app";
import {
  browserLocalPersistence,
  getAuth,
  onAuthStateChanged,
  sendPasswordResetEmail,
  setPersistence,
  signInWithEmailAndPassword,
  signOut,
} from "firebase/auth";
import {
  Check,
  CheckCircle2,
  ChevronRight,
  CircleAlert,
  Clock3,
  Download,
  FileCheck2,
  Flag,
  History,
  LogOut,
  MessageSquareWarning,
  Moon,
  RefreshCw,
  Search,
  ShieldCheck,
  Sun,
  UserRoundCheck,
  UsersRound,
  X,
} from "lucide";
import { createIcons } from "lucide";

import { createAdminApi, AdminApiError } from "./admin-api.js";
import {
  actionPresentation,
  availableReviewActions,
  errorMessage,
  formatBytes,
  formatDate,
  qualificationLabel,
  reviewStatuses,
  statusLabel,
  statusPresentation,
} from "./admin-state.js";
import {
  adminApiBaseURL,
  canonicalAdminOrigin,
  canonicalWebAppHost,
  firebaseConfig,
} from "./config.js";
import "./styles.css";

const iconSet = {
  Check,
  CheckCircle2,
  ChevronRight,
  CircleAlert,
  Clock3,
  Download,
  FileCheck2,
  Flag,
  History,
  LogOut,
  MessageSquareWarning,
  Moon,
  RefreshCw,
  Search,
  ShieldCheck,
  Sun,
  UserRoundCheck,
  UsersRound,
  X,
};

const appElement = document.querySelector("#app");
const toastRegion = document.querySelector("#toast-region");
const shouldUseCanonicalOrigin = location.hostname === canonicalWebAppHost;
const isLocalPreview =
  new URLSearchParams(location.search).get("preview") === "1" &&
  ["localhost", "127.0.0.1"].includes(location.hostname);

const state = {
  phase: "starting",
  authUser: null,
  admin: null,
  api: null,
  workspaceMode: "applications",
  applications: [],
  summary: emptySummary(),
  selectedUid: "",
  audit: [],
  auditLoading: false,
  listLoading: false,
  actionLoading: false,
  filterStatus: "",
  filterQuery: "",
  pendingAction: "",
  reports: [],
  reportSummary: emptyReportSummary(),
  selectedReportId: "",
  reportFilterStatus: "",
  reportFilterQuery: "",
  pendingReportAction: "",
  errorCode: "",
  errorRequestId: "",
  listErrorCode: "",
  listErrorRequestId: "",
  auditErrorCode: "",
  theme: localStorage.getItem("englishplus-admin-theme") || "system",
};

applyTheme();
appElement.addEventListener("click", handleClick);
appElement.addEventListener("submit", handleSubmit);
appElement.addEventListener("change", handleChange);

if (shouldUseCanonicalOrigin) {
  const canonicalURL = new URL(location.href);
  canonicalURL.host = new URL(canonicalAdminOrigin).host;
  location.replace(canonicalURL.toString());
} else if (isLocalPreview) {
  loadPreviewState();
} else {
  startAuthentication();
}

async function startAuthentication() {
  const firebaseApp = initializeApp(firebaseConfig);
  const auth = getAuth(firebaseApp);
  await setPersistence(auth, browserLocalPersistence);
  state.auth = auth;
  state.api = createAdminApi({
    baseURL: adminApiBaseURL,
    getToken: async (forceRefresh = false) => {
      const user = auth.currentUser;
      if (!user) throw new AdminApiError("AUTH_REQUIRED", 401);
      return user.getIdToken(forceRefresh);
    },
  });

  onAuthStateChanged(auth, async (user) => {
    state.authUser = user;
    state.errorCode = "";
    state.errorRequestId = "";
    if (!user) {
      state.phase = "signedOut";
      state.admin = null;
      state.applications = [];
      state.selectedUid = "";
      state.reports = [];
      state.selectedReportId = "";
      render();
      return;
    }
    state.phase = "verifying";
    render();
    await verifyAdministrator();
  });
}

async function verifyAdministrator() {
  try {
    const result = await state.api.session();
    state.admin = result.admin;
    state.phase = "ready";
    await loadCurrentWorkspace({ preserveSelection: false });
  } catch (error) {
    rememberError(error);
    state.phase = error.status === 403 ? "unauthorized" : "sessionError";
    render();
  }
}

function loadCurrentWorkspace(options = {}) {
  return state.workspaceMode === "reports"
    ? loadSupportReports(options)
    : loadApplications(options);
}

async function loadApplications({ preserveSelection = true } = {}) {
  state.listLoading = true;
  state.listErrorCode = "";
  state.listErrorRequestId = "";
  render();
  try {
    const result = await state.api.applications({
      status: state.filterStatus,
      query: state.filterQuery,
    });
    state.applications = result.applications || [];
    state.summary = result.summary || emptySummary();
    if (
      !preserveSelection ||
      !state.applications.some((item) => item.uid === state.selectedUid)
    ) {
      state.selectedUid = state.applications[0]?.uid || "";
    }
    await loadAuditForSelection();
  } catch (error) {
    state.listErrorCode = error?.code || "APPLICATION_LIST_FAILED";
    state.listErrorRequestId = error?.requestId || "";
  } finally {
    state.listLoading = false;
    render();
  }
}

async function loadAuditForSelection() {
  state.audit = [];
  state.auditErrorCode = "";
  if (!state.selectedUid) return;
  state.auditLoading = true;
  render();
  try {
    const result = await state.api.audit(state.selectedUid);
    state.audit = result.events || [];
  } catch (error) {
    state.auditErrorCode = error?.code || "AUDIT_LIST_FAILED";
  } finally {
    state.auditLoading = false;
  }
}

async function loadSupportReports({ preserveSelection = true } = {}) {
  state.listLoading = true;
  state.listErrorCode = "";
  state.listErrorRequestId = "";
  render();
  try {
    const result = await state.api.supportReports({
      status: state.reportFilterStatus,
      query: state.reportFilterQuery,
    });
    state.reports = result.reports || [];
    state.reportSummary = result.summary || emptyReportSummary();
    if (
      !preserveSelection ||
      !state.reports.some((item) => item.reportId === state.selectedReportId)
    ) {
      state.selectedReportId = state.reports[0]?.reportId || "";
    }
  } catch (error) {
    state.listErrorCode = error?.code || "SUPPORT_REPORT_LIST_FAILED";
    state.listErrorRequestId = error?.requestId || "";
  } finally {
    state.listLoading = false;
    render();
  }
}

async function handleClick(event) {
  const trigger = event.target.closest("[data-action]");
  if (!trigger) return;
  const action = trigger.dataset.action;

  if (action === "reset-password") {
    const email = document.querySelector('#email-login-form input[name="email"]')?.value;
    return resetPassword(email);
  }
  if (action === "sign-out") return state.auth ? signOut(state.auth) : resetPreview();
  if (action === "refresh-session") return verifyAdministrator();
  if (action === "reload") return loadCurrentWorkspace();
  if (action === "toggle-theme") return toggleTheme();
  if (action === "switch-workspace") {
    state.workspaceMode = trigger.dataset.workspace || "applications";
    state.filterStatus = "";
    state.filterQuery = "";
    state.reportFilterStatus = "";
    state.reportFilterQuery = "";
    return loadCurrentWorkspace({ preserveSelection: false });
  }
  if (action === "select-status") {
    state.filterStatus = trigger.dataset.status || "";
    return loadApplications({ preserveSelection: false });
  }
  if (action === "select-application") {
    state.selectedUid = trigger.dataset.uid || "";
    await loadAuditForSelection();
    return render();
  }
  if (action === "select-report-status") {
    state.reportFilterStatus = trigger.dataset.status || "";
    return loadSupportReports({ preserveSelection: false });
  }
  if (action === "select-report") {
    state.selectedReportId = trigger.dataset.reportId || "";
    return render();
  }
  if (action === "open-review") {
    state.pendingAction = trigger.dataset.reviewAction || "";
    render();
    requestAnimationFrame(() => document.querySelector("#review-dialog")?.showModal());
    return;
  }
  if (action === "close-review") {
    document.querySelector("#review-dialog")?.close();
    state.pendingAction = "";
    return;
  }
  if (action === "open-report-review") {
    state.pendingReportAction = trigger.dataset.reportAction || "";
    render();
    requestAnimationFrame(() => document.querySelector("#report-review-dialog")?.showModal());
    return;
  }
  if (action === "close-report-review") {
    document.querySelector("#report-review-dialog")?.close();
    state.pendingReportAction = "";
    return;
  }
  if (action === "open-evidence") return openEvidence(trigger.dataset.objectKey);
}

async function handleSubmit(event) {
  event.preventDefault();
  const form = event.target;
  if (form.id === "email-login-form") {
    const data = new FormData(form);
    return loginWithEmail(data.get("email"), data.get("password"));
  }
  if (form.id === "search-form") {
    const data = new FormData(form);
    state.filterQuery = String(data.get("query") || "").trim();
    return loadApplications({ preserveSelection: false });
  }
  if (form.id === "report-search-form") {
    const data = new FormData(form);
    state.reportFilterQuery = String(data.get("query") || "").trim();
    return loadSupportReports({ preserveSelection: false });
  }
  if (form.id === "review-form") {
    const data = new FormData(form);
    return commitReview(String(data.get("note") || "").trim());
  }
  if (form.id === "report-review-form") {
    const data = new FormData(form);
    return commitSupportReportReview(String(data.get("note") || "").trim());
  }
}

function handleChange(event) {
  if (event.target.id === "status-filter") {
    state.filterStatus = event.target.value;
    loadApplications({ preserveSelection: false });
  }
  if (event.target.id === "report-status-filter") {
    state.reportFilterStatus = event.target.value;
    loadSupportReports({ preserveSelection: false });
  }
}

async function loginWithEmail(email, password) {
  clearLoginError();
  try {
    await signInWithEmailAndPassword(state.auth, String(email), String(password));
  } catch (error) {
    showToast(firebaseAuthMessage(error.code), "error");
  }
}

async function resetPassword(email) {
  if (!String(email || "").trim()) {
    showToast("請先填入管理員 Email。", "error");
    return;
  }
  try {
    await sendPasswordResetEmail(state.auth, String(email).trim());
    showToast("密碼重設信已寄出，請檢查信箱。", "success");
  } catch (error) {
    showToast(firebaseAuthMessage(error.code), "error");
  }
}

async function commitReview(note) {
  const application = selectedApplication();
  const action = state.pendingAction;
  if (!application || !action) return;
  if (note.length < 3) {
    showToast("請填寫至少 3 個字的審核原因。", "error");
    return;
  }

  state.actionLoading = true;
  setDialogSubmitting("#review-dialog", true, "儲存中…");
  try {
    await state.api.review(application.uid, {
      action,
      note,
      expectedVersion: application.version,
    });
    document.querySelector("#review-dialog")?.close();
    state.pendingAction = "";
    showToast("審核結果已儲存，帳號狀態也已同步更新。", "success");
    await loadApplications();
  } catch (error) {
    showToast(errorMessage(error.code), "error");
    state.actionLoading = false;
    setDialogSubmitting("#review-dialog", false, actionPresentation[action]?.label || "儲存");
    return;
  }
  state.actionLoading = false;
  render();
}

async function commitSupportReportReview(note) {
  const report = selectedSupportReport();
  const action = state.pendingReportAction;
  if (!report || !action) return;
  if (note.length < 3) {
    showToast("請填寫至少 3 個字的處理紀錄。", "error");
    return;
  }

  state.actionLoading = true;
  setDialogSubmitting("#report-review-dialog", true, "儲存中…");
  try {
    await state.api.reviewSupportReport(report.classId, report.reportId, {
      action,
      note,
      expectedVersion: report.version,
    });
    document.querySelector("#report-review-dialog")?.close();
    state.pendingReportAction = "";
    showToast("檢舉案件狀態與處理紀錄已更新。", "success");
    await loadSupportReports();
  } catch (error) {
    showToast(supportReportErrorMessage(error?.code), "error");
    state.actionLoading = false;
    setDialogSubmitting("#report-review-dialog", false, supportReportActionPresentation(action).label);
    return;
  }
  state.actionLoading = false;
  render();
}

function setDialogSubmitting(dialogSelector, isSubmitting, label) {
  const dialog = document.querySelector(dialogSelector);
  const submit = dialog?.querySelector('button[type="submit"]');
  const closeButtons = dialog?.querySelectorAll('[data-action^="close-"]') || [];
  if (submit) {
    submit.disabled = isSubmitting;
    submit.textContent = label;
  }
  closeButtons.forEach((button) => {
    button.disabled = isSubmitting;
  });
}

async function openEvidence(objectKey) {
  if (!objectKey) return;
  let popup = null;
  try {
    popup = window.open("", "_blank");
    const result = await state.api.evidencePreview(objectKey);
    const previewURL = new URL(result.previewURL || "");
    const workerOrigin = new URL(adminApiBaseURL).origin;
    if (
      previewURL.origin !== workerOrigin ||
      previewURL.pathname !== "/admin/evidence-file"
    ) {
      throw new AdminApiError("INVALID_EVIDENCE_PREVIEW_URL", 502, result.requestId);
    }
    if (popup) popup.location.replace(previewURL.toString());
    else {
      const link = document.createElement("a");
      link.href = previewURL.toString();
      link.target = "_blank";
      link.rel = "noopener noreferrer";
      link.click();
    }
    // Detaching the opener before navigation makes the popup WindowProxy unusable.
    if (popup) popup.opener = null;
  } catch (error) {
    popup?.close();
    const requestReference = error?.requestId ? `（參考編號 ${error.requestId}）` : "";
    console.error("Evidence preview failed", {
      code: error?.code || "UNKNOWN",
      status: error?.status || 0,
      requestId: error?.requestId || "",
    });
    showToast(`${errorMessage(error?.code)}${requestReference}`, "error");
  }
}

function render() {
  if (["starting", "verifying"].includes(state.phase)) {
    appElement.innerHTML = loadingScreen();
  } else if (state.phase === "signedOut") {
    appElement.innerHTML = loginScreen();
  } else if (state.phase === "unauthorized") {
    appElement.innerHTML = accessDeniedScreen();
  } else if (state.phase === "sessionError") {
    appElement.innerHTML = sessionErrorScreen();
  } else {
    appElement.innerHTML = dashboardScreen();
  }
  createIcons({ icons: iconSet, attrs: { "aria-hidden": "true" } });
}

function loadingScreen() {
  return `<main class="center-screen"><div class="loading-mark" aria-label="正在確認管理員權限"></div><p>正在確認管理員權限…</p></main>`;
}

function loginScreen() {
  return `
    <main class="auth-shell">
      <section class="auth-panel" aria-labelledby="login-title">
        <div class="brand-lockup"><span class="brand-mark">E+</span><span>English+</span></div>
        <p class="eyebrow">志工申請管理</p>
        <h1 id="login-title">管理員登入</h1>
        <p class="auth-copy">僅限已獲授權的管理員使用 Email 與管理台密碼登入。</p>
        <form id="email-login-form" class="form-stack">
          <label>Email<input name="email" type="email" autocomplete="username" required /></label>
          <label>密碼<input name="password" type="password" autocomplete="current-password" minlength="8" required /></label>
          <button class="text-button forgot-password" type="button" data-action="reset-password">設定或重設管理台密碼</button>
          <button class="button primary" type="submit">登入管理台</button>
        </form>
        <p class="security-note"><i data-lucide="shield-check"></i>申請資料與證明文件只對已授權管理員開放。</p>
      </section>
    </main>`;
}

function accessDeniedScreen() {
  return messageScreen(
    "這個帳號沒有管理權限",
    "你已成功登入，但帳號尚未被授予 English+ 管理員權限。請確認 Firebase custom claim 已設定為 admin: true。",
    `<button class="button secondary" data-action="refresh-session"><i data-lucide="refresh-cw"></i>重新確認權限</button>
     <button class="button primary" data-action="sign-out"><i data-lucide="log-out"></i>改用其他帳號</button>`
  );
}

function sessionErrorScreen() {
  return messageScreen(
    "暫時無法開啟管理台",
    `${escapeHtml(errorMessage(state.errorCode))}${requestReference()}`,
    `<button class="button primary" data-action="refresh-session"><i data-lucide="refresh-cw"></i>再試一次</button>
     <button class="button secondary" data-action="sign-out">登出</button>`
  );
}

function messageScreen(title, copy, actions) {
  return `<main class="center-screen"><section class="message-panel"><i class="message-icon" data-lucide="circle-alert"></i><h1>${title}</h1><p>${copy}</p><div class="button-row">${actions}</div></section></main>`;
}

function dashboardScreen() {
  const application = selectedApplication();
  const report = selectedSupportReport();
  return `
    <div class="admin-shell">
      <header class="topbar">
        <div class="brand-lockup"><span class="brand-mark">E+</span><span>English+ 管理台</span></div>
        <div class="topbar-actions">
          <span class="admin-identity">${escapeHtml(state.admin?.email || "管理員")}</span>
          <button class="icon-button" data-action="toggle-theme" title="切換顯示模式" aria-label="切換顯示模式"><i data-lucide="${state.theme === "dark" ? "sun" : "moon"}"></i></button>
          <button class="icon-button" data-action="sign-out" title="登出" aria-label="登出"><i data-lucide="log-out"></i></button>
        </div>
      </header>
      <main class="workspace">
        ${workspaceTabs()}
        ${state.workspaceMode === "reports" ? reportWorkspace(report) : applicationWorkspace(application)}
      </main>
      ${reviewDialog(application)}
      ${supportReportReviewDialog(report)}
    </div>`;
}

function workspaceTabs() {
  const pendingReports = (state.reportSummary.open || 0) + (state.reportSummary.reviewing || 0);
  return `<nav class="workspace-tabs" aria-label="管理工作區">
    <button class="workspace-tab ${state.workspaceMode === "applications" ? "active" : ""}" data-action="switch-workspace" data-workspace="applications">
      <i data-lucide="user-round-check"></i><span>志工申請</span>
    </button>
    <button class="workspace-tab ${state.workspaceMode === "reports" ? "active" : ""}" data-action="switch-workspace" data-workspace="reports">
      <i data-lucide="message-square-warning"></i><span>內容檢舉</span>${pendingReports ? `<strong class="workspace-badge">${pendingReports}</strong>` : ""}
    </button>
  </nav>`;
}

function applicationWorkspace(application) {
  return `<section aria-labelledby="application-workspace-title">
    <section class="workspace-heading">
      <div><p class="eyebrow">志工資格審核</p><h1 id="application-workspace-title">申請工作台</h1><p>逐份確認資格證明，審核結果會同步到志工帳號。</p></div>
      <button class="button secondary" data-action="reload" ${state.listLoading ? "disabled" : ""}><i data-lucide="refresh-cw"></i>重新整理</button>
    </section>
    ${summaryStrip()}
    <section class="work-grid">
      <aside class="application-rail" aria-label="申請清單">
        ${filterControls()}
        ${applicationList()}
      </aside>
      <article class="application-detail">
        ${application ? applicationDetail(application) : emptyDetail()}
      </article>
    </section>
  </section>`;
}

function reportWorkspace(report) {
  return `<section aria-labelledby="report-workspace-title">
    <section class="workspace-heading">
      <div><p class="eyebrow">使用者安全</p><h1 id="report-workspace-title">內容檢舉</h1><p>查核學生回報的老師或志工回覆，留下處理紀錄並完成案件。</p></div>
      <button class="button secondary" data-action="reload" ${state.listLoading ? "disabled" : ""}><i data-lucide="refresh-cw"></i>重新整理</button>
    </section>
    ${reportSummaryStrip()}
    <section class="work-grid">
      <aside class="application-rail" aria-label="內容檢舉清單">
        ${reportFilterControls()}
        ${supportReportList()}
      </aside>
      <article class="application-detail">
        ${report ? supportReportDetail(report) : emptyReportDetail()}
      </article>
    </section>
  </section>`;
}

function summaryStrip() {
  const items = [
    ["", "全部", state.summary.total, "users-round"],
    ["pendingReview", "待審核", state.summary.pendingReview, "clock-3"],
    ["needsMoreInformation", "待補件", state.summary.needsMoreInformation, "file-check-2"],
    ["approved", "已核准", state.summary.approved, "user-round-check"],
  ];
  return `<div class="summary-strip">${items.map(([status, label, value, icon]) => `
    <button class="summary-item ${state.filterStatus === status ? "active" : ""}" data-action="select-status" data-status="${status}">
      <i data-lucide="${icon}"></i><span><strong>${value || 0}</strong>${label}</span>
    </button>`).join("")}</div>`;
}

function reportSummaryStrip() {
  const items = [
    ["", "全部", state.reportSummary.total, "flag"],
    ["open", "待處理", state.reportSummary.open, "circle-alert"],
    ["reviewing", "處理中", state.reportSummary.reviewing, "clock-3"],
    ["resolved", "已完成", state.reportSummary.resolved, "check-circle-2"],
  ];
  return `<div class="summary-strip">${items.map(([status, label, value, icon]) => `
    <button class="summary-item ${state.reportFilterStatus === status ? "active" : ""}" data-action="select-report-status" data-status="${status}">
      <i data-lucide="${icon}"></i><span><strong>${value || 0}</strong>${label}</span>
    </button>`).join("")}</div>`;
}

function filterControls() {
  return `<div class="rail-tools">
    <form id="search-form" class="search-box"><i data-lucide="search"></i><input name="query" type="search" value="${escapeHtml(state.filterQuery)}" placeholder="搜尋姓名、UID 或申請動機" /><button class="sr-only" type="submit">搜尋</button></form>
    <select id="status-filter" aria-label="依申請狀態篩選">${reviewStatuses.map((status) => `<option value="${status}" ${state.filterStatus === status ? "selected" : ""}>${status ? statusLabel(status) : "所有狀態"}</option>`).join("")}</select>
  </div>`;
}

function reportFilterControls() {
  const statuses = ["", "open", "reviewing", "resolved", "dismissed"];
  return `<div class="rail-tools">
    <form id="report-search-form" class="search-box"><i data-lucide="search"></i><input name="query" type="search" value="${escapeHtml(state.reportFilterQuery)}" placeholder="搜尋學生、回覆者、班級或內容" /><button class="sr-only" type="submit">搜尋</button></form>
    <select id="report-status-filter" aria-label="依檢舉狀態篩選">${statuses.map((status) => `<option value="${status}" ${state.reportFilterStatus === status ? "selected" : ""}>${status ? supportReportStatusLabel(status) : "所有狀態"}</option>`).join("")}</select>
  </div>`;
}

function applicationList() {
  if (state.listLoading) return `<div class="rail-state"><div class="loading-mark small"></div><span>讀取申請中…</span></div>`;
  if (state.listErrorCode) return `<div class="rail-state error"><i data-lucide="circle-alert"></i><p>${escapeHtml(errorMessage(state.listErrorCode))}</p>${state.listErrorRequestId ? `<small class="monospace">參考編號 ${escapeHtml(state.listErrorRequestId)}</small>` : ""}<button class="text-button" data-action="reload">再試一次</button></div>`;
  if (!state.applications.length) return `<div class="rail-state"><i data-lucide="check-circle-2"></i><p>目前沒有符合條件的申請。</p></div>`;
  return `<div class="application-list">${state.applications.map((application) => {
    const presentation = statusPresentation[application.status] || { tone: "neutral" };
    return `<button class="application-row ${state.selectedUid === application.uid ? "selected" : ""}" data-action="select-application" data-uid="${escapeHtml(application.uid)}">
      <span class="row-main"><strong>${escapeHtml(application.displayName)}</strong><small>${escapeHtml(formatDate(application.submittedAt))}</small></span>
      <span class="status-pill ${presentation.tone}">${escapeHtml(statusLabel(application.status))}</span>
      <i data-lucide="chevron-right"></i>
    </button>`;
  }).join("")}</div>`;
}

function supportReportList() {
  if (state.listLoading) return `<div class="rail-state"><div class="loading-mark small"></div><span>讀取檢舉中…</span></div>`;
  if (state.listErrorCode) return `<div class="rail-state error"><i data-lucide="circle-alert"></i><p>${escapeHtml(supportReportErrorMessage(state.listErrorCode))}</p>${state.listErrorRequestId ? `<small class="monospace">參考編號 ${escapeHtml(state.listErrorRequestId)}</small>` : ""}<button class="text-button" data-action="reload">再試一次</button></div>`;
  if (!state.reports.length) return `<div class="rail-state"><i data-lucide="check-circle-2"></i><p>目前沒有符合條件的檢舉案件。</p></div>`;
  return `<div class="application-list">${state.reports.map((report) => {
    const presentation = supportReportStatusPresentation(report.status);
    return `<button class="application-row ${state.selectedReportId === report.reportId ? "selected" : ""}" data-action="select-report" data-report-id="${escapeHtml(report.reportId)}">
      <span class="row-main"><strong>${escapeHtml(report.studentName || "學生")} · ${escapeHtml(supportReportReasonLabel(report.reason))}</strong><small>${escapeHtml(report.replyAuthorName || roleLabel(report.reportedRole))} · ${escapeHtml(formatDate(report.createdAt))}</small></span>
      <span class="status-pill ${presentation.tone}">${escapeHtml(supportReportStatusLabel(report.status))}</span>
      <i data-lucide="chevron-right"></i>
    </button>`;
  }).join("")}</div>`;
}

function applicationDetail(application) {
  const actions = availableReviewActions(application.status);
  const totalBytes = application.evidence.reduce((sum, item) => sum + item.sizeBytes, 0);
  return `
    <header class="detail-header">
      <div><div class="detail-title-row"><h2>${escapeHtml(application.displayName)}</h2><span class="status-pill ${statusPresentation[application.status]?.tone || "neutral"}">${escapeHtml(statusLabel(application.status))}</span></div><p class="monospace">UID ${escapeHtml(application.uid)}</p></div>
      <div class="detail-time"><span>送出時間</span><strong>${escapeHtml(formatDate(application.submittedAt))}</strong></div>
    </header>
    <div class="detail-section facts-grid">
      <div><span>已滿 18 歲</span><strong>${application.confirmsAge18OrOlder ? "已確認" : "未確認"}</strong></div>
      <div><span>志工守則</span><strong>${application.acceptedConductVersion ? "已同意" : "未同意"}</strong></div>
      <div><span>證明文件</span><strong>${application.evidence.length} 份</strong></div>
      <div><span>檔案總量</span><strong>${formatBytes(totalBytes)}</strong></div>
    </div>
    <section class="detail-section"><h3>申請動機</h3><p class="long-copy">${escapeHtml(application.motivation || "申請者未填寫動機。")}</p></section>
    <section class="detail-section"><div class="section-heading"><h3>資格證明</h3><span>${application.evidence.length}/5 份</span></div>${evidenceList(application)}</section>
    ${application.reviewNote ? `<section class="detail-section review-note"><h3>最近一次審核備註</h3><p>${escapeHtml(application.reviewNote)}</p><small>${escapeHtml(formatDate(application.reviewedAt))}</small></section>` : ""}
    <section class="detail-section"><div class="section-heading"><h3>審核紀錄</h3><i data-lucide="history"></i></div>${auditList()}</section>
    <footer class="review-actions">${actions.length ? actions.map((action) => `<button class="button ${actionPresentation[action].tone}" data-action="open-review" data-review-action="${action}">${escapeHtml(actionPresentation[action].label)}</button>`).join("") : `<p><i data-lucide="check-circle-2"></i>這份申請目前沒有待執行的審核動作。</p>`}</footer>`;
}

function supportReportDetail(report) {
  const actions = availableSupportReportActions(report.status);
  const presentation = supportReportStatusPresentation(report.status);
  return `
    <header class="detail-header">
      <div><div class="detail-title-row"><h2>${escapeHtml(supportReportReasonLabel(report.reason))}</h2><span class="status-pill ${presentation.tone}">${escapeHtml(supportReportStatusLabel(report.status))}</span></div><p class="monospace">案件 ${escapeHtml(report.reportId)} · 班級 ${escapeHtml(report.classId)}</p></div>
      <div class="detail-time"><span>檢舉時間</span><strong>${escapeHtml(formatDate(report.createdAt))}</strong></div>
    </header>
    <div class="detail-section report-facts-grid">
      <div><span>提出學生</span><strong>${escapeHtml(report.studentName || "學生")}</strong><small class="monospace">${escapeHtml(report.studentUid)}</small></div>
      <div><span>被檢舉回覆者</span><strong>${escapeHtml(report.replyAuthorName || roleLabel(report.reportedRole))}</strong><small>${escapeHtml(roleLabel(report.reportedRole))}</small></div>
      <div><span>內容保護</span><strong>已隱藏給檢舉者</strong><small>封鎖後的後續回覆也不顯示</small></div>
    </div>
    ${report.contentUnavailable ? `<section class="detail-section"><div class="inline-state warning"><i data-lucide="circle-alert"></i>原始題目或回覆已不存在，請依現有紀錄判斷；不要在缺少內容時直接認定違規。</div></section>` : ""}
    <section class="detail-section report-context"><h3>被檢舉的回覆</h3><blockquote>${escapeHtml(report.replyBody || "目前無法取得回覆內容。")}</blockquote><p><strong>回覆者 UID</strong><span class="monospace">${escapeHtml(report.reportedUid)}</span></p></section>
    <section class="detail-section report-context"><h3>當時的學習脈絡</h3>
      <dl>
        <div><dt>題目</dt><dd>${escapeHtml(report.questionPrompt || "未保留題目快照")}</dd></div>
        <div><dt>學生答案</dt><dd>${escapeHtml(report.studentAnswer || "未記錄")}</dd></div>
        <div><dt>正確答案</dt><dd>${escapeHtml(report.correctAnswer || "未記錄")}</dd></div>
        ${report.studentMessage ? `<div><dt>學生補充</dt><dd>${escapeHtml(report.studentMessage)}</dd></div>` : ""}
      </dl>
    </section>
    ${report.moderationNote ? `<section class="detail-section review-note"><h3>最近一次處理紀錄</h3><p>${escapeHtml(report.moderationNote)}</p><small>${escapeHtml(report.moderatedByEmail || "管理員")} · ${escapeHtml(formatDate(report.moderatedAt))}</small></section>` : ""}
    <footer class="review-actions">${actions.length ? actions.map((action) => `<button class="button ${supportReportActionPresentation(action).tone}" data-action="open-report-review" data-report-action="${action}">${escapeHtml(supportReportActionPresentation(action).label)}</button>`).join("") : `<p><i data-lucide="check-circle-2"></i>這個案件已結案，處理紀錄會保留供後續稽核。</p>`}</footer>`;
}

function evidenceList(application) {
  if (application.evidenceDeletedAt) return `<div class="inline-state">證明文件已依保存政策刪除（${escapeHtml(formatDate(application.evidenceDeletedAt))}）。</div>`;
  if (!application.evidence.length) return `<div class="inline-state warning"><i data-lucide="circle-alert"></i>尚未附上任何資格證明，不建議核准。</div>`;
  return `<div class="evidence-list">${application.evidence.map((item) => `<button class="evidence-row" data-action="open-evidence" data-object-key="${escapeHtml(item.objectKey)}">
    <i data-lucide="file-check-2"></i><span><strong>${escapeHtml(item.filename || qualificationLabel(item.kind))}</strong><small>${escapeHtml(qualificationLabel(item.kind))} · ${formatBytes(item.sizeBytes)}</small></span><span class="download-label"><i data-lucide="download"></i>檢視</span>
  </button>`).join("")}</div>`;
}

function auditList() {
  if (state.auditLoading) return `<div class="inline-state"><div class="loading-mark small"></div>讀取紀錄中…</div>`;
  if (state.auditErrorCode) return `<div class="inline-state warning"><i data-lucide="circle-alert"></i>${escapeHtml(errorMessage(state.auditErrorCode))}</div>`;
  if (!state.audit.length) return `<div class="inline-state">尚無審核紀錄。</div>`;
  return `<ol class="audit-list">${state.audit.map((event) => `<li><span class="audit-dot"></span><div><strong>${escapeHtml(statusLabel(event.resultingStatus))}</strong><p>${escapeHtml(event.note || "未填寫備註")}</p><small>${escapeHtml(event.reviewerEmail || "管理員")} · ${escapeHtml(formatDate(event.createdAt))}</small></div></li>`).join("")}</ol>`;
}

function emptyDetail() {
  return `<div class="empty-detail"><i data-lucide="file-check-2"></i><h2>選擇一份申請</h2><p>從左側清單選擇申請者，即可檢視證明與完成審核。</p></div>`;
}

function emptyReportDetail() {
  return `<div class="empty-detail"><i data-lucide="message-square-warning"></i><h2>選擇一個檢舉案件</h2><p>從左側清單選擇案件，查核回覆內容與學習脈絡後再留下處理紀錄。</p></div>`;
}

function reviewDialog(application) {
  if (!application || !state.pendingAction) return `<dialog id="review-dialog"></dialog>`;
  const action = actionPresentation[state.pendingAction];
  return `<dialog id="review-dialog" class="review-dialog">
    <form id="review-form" method="dialog">
      <div class="dialog-heading"><div><p class="eyebrow">${escapeHtml(application.displayName)}</p><h2>${escapeHtml(action.confirm)}</h2></div><button class="icon-button" type="button" data-action="close-review" aria-label="關閉"><i data-lucide="x"></i></button></div>
      <p>${reviewActionExplanation(state.pendingAction)}</p>
      <label>審核備註（必填）<textarea name="note" rows="4" minlength="3" maxlength="1000" placeholder="說明結果與下一步；申請人會在 App 中看到這段文字" required></textarea></label>
      <div class="dialog-actions"><button class="button secondary" type="button" data-action="close-review">取消</button><button class="button ${action.tone}" type="submit" ${state.actionLoading ? "disabled" : ""}>${state.actionLoading ? "儲存中…" : escapeHtml(action.label)}</button></div>
    </form>
  </dialog>`;
}

function supportReportReviewDialog(report) {
  if (!report || !state.pendingReportAction) return `<dialog id="report-review-dialog"></dialog>`;
  const action = supportReportActionPresentation(state.pendingReportAction);
  return `<dialog id="report-review-dialog" class="review-dialog">
    <form id="report-review-form" method="dialog">
      <div class="dialog-heading"><div><p class="eyebrow">${escapeHtml(report.studentName || "學生")}的檢舉</p><h2>${escapeHtml(action.confirm)}</h2></div><button class="icon-button" type="button" data-action="close-report-review" aria-label="關閉"><i data-lucide="x"></i></button></div>
      <p>${escapeHtml(supportReportActionExplanation(state.pendingReportAction))}</p>
      <label>處理紀錄（必填）<textarea name="note" rows="4" minlength="3" maxlength="1000" placeholder="記錄查核依據與處理結果，供後續管理稽核" required></textarea></label>
      <div class="dialog-actions"><button class="button secondary" type="button" data-action="close-report-review">取消</button><button class="button ${action.tone}" type="submit" ${state.actionLoading ? "disabled" : ""}>${state.actionLoading ? "儲存中…" : escapeHtml(action.label)}</button></div>
    </form>
  </dialog>`;
}

function reviewActionExplanation(action) {
  return {
    approved: "核准後，志工帳號會立即啟用；志工仍須加入服務班級後才能看到學生求助。",
    needsMoreInformation: "申請會退回待補件，志工可重新上傳證明並再次送審。",
    rejected: "申請會標記為未通過，帳號不會取得志工功能。",
    suspended: "帳號會停止使用志工功能，既有審核紀錄仍會保留。",
  }[action] || "";
}

function supportReportActionPresentation(action) {
  return {
    reviewing: { label: "開始查核", confirm: "將案件標記為處理中？", tone: "secondary" },
    resolved: { label: "確認完成", confirm: "完成這個檢舉案件？", tone: "primary" },
    dismissed: { label: "不成立", confirm: "將案件標記為不成立？", tone: "secondary" },
  }[action] || { label: "更新", confirm: "更新案件？", tone: "secondary" };
}

function supportReportActionExplanation(action) {
  return {
    reviewing: "代表管理員已開始查核，案件仍會留在待處理工作區。",
    resolved: "代表已完成必要查核與處置；封鎖狀態不會因結案自動解除。",
    dismissed: "代表依現有脈絡未發現需要進一步處置的內容；檢舉與查核紀錄仍會保留。",
  }[action] || "";
}

function availableSupportReportActions(status) {
  if (status === "open") return ["reviewing", "resolved", "dismissed"];
  if (status === "reviewing") return ["resolved", "dismissed"];
  return [];
}

function supportReportStatusPresentation(status) {
  return {
    open: { tone: "warning" },
    reviewing: { tone: "info" },
    resolved: { tone: "success" },
    dismissed: { tone: "neutral" },
  }[status] || { tone: "neutral" };
}

function supportReportStatusLabel(status) {
  return {
    open: "待處理",
    reviewing: "處理中",
    resolved: "已完成",
    dismissed: "不成立",
  }[status] || "未知狀態";
}

function supportReportReasonLabel(reason) {
  return {
    inappropriateContent: "內容不適當",
    privacyConcern: "隱私疑慮",
    harassment: "騷擾或不舒服的互動",
    other: "其他問題",
  }[reason] || "內容問題";
}

function roleLabel(role) {
  return { teacher: "老師", volunteer: "志工", student: "學生" }[role] || "使用者";
}

function selectedApplication() {
  return state.applications.find((item) => item.uid === state.selectedUid) || null;
}

function selectedSupportReport() {
  return state.reports.find((item) => item.reportId === state.selectedReportId) || null;
}

function rememberError(error) {
  state.errorCode = error?.code || "REQUEST_FAILED";
  state.errorRequestId = error?.requestId || "";
}

function clearLoginError() {
  state.errorCode = "";
  state.errorRequestId = "";
}

function requestReference() {
  return state.errorRequestId
    ? `<br><small class="monospace">參考編號 ${escapeHtml(state.errorRequestId)}</small>`
    : "";
}

function showToast(message, tone = "neutral") {
  const toast = document.createElement("div");
  toast.className = `toast ${tone}`;
  toast.textContent = message;
  toastRegion.append(toast);
  setTimeout(() => toast.remove(), 4500);
}

function toggleTheme() {
  const current = document.documentElement.dataset.theme;
  state.theme = current === "dark" ? "light" : "dark";
  localStorage.setItem("englishplus-admin-theme", state.theme);
  applyTheme();
  render();
}

function applyTheme() {
  const systemDark = matchMedia("(prefers-color-scheme: dark)").matches;
  const resolved = state.theme === "system" ? (systemDark ? "dark" : "light") : state.theme;
  document.documentElement.dataset.theme = resolved;
  document.querySelector('meta[name="theme-color"]')?.setAttribute("content", resolved === "dark" ? "#0f171a" : "#f5f7f9");
}

function firebaseAuthMessage(code) {
  const message = {
    "auth/invalid-credential": "Email 或密碼不正確。",
    "auth/popup-closed-by-user": "登入視窗已關閉。",
    "auth/popup-blocked": "瀏覽器封鎖了登入視窗，請允許彈出視窗後重試。",
    "auth/redirect-cancelled-by-user": "Google 登入已取消，請重新嘗試。",
    "auth/unauthorized-domain": "這個網址尚未獲得 Firebase 登入授權。",
    "auth/operation-not-allowed": "Google 登入尚未在 Firebase 啟用。",
    "auth/web-storage-unsupported": "瀏覽器目前無法保存登入狀態，請允許 Cookie 後重試。",
    "auth/too-many-requests": "嘗試次數過多，請稍後再試。",
    "auth/network-request-failed": "網路連線失敗，請確認網路後重試。",
  }[code];
  return message || `登入未完成（${String(code || "unknown")}），請再試一次。`;
}

function supportReportErrorMessage(code) {
  return {
    SUPPORT_REPORT_LIST_FAILED: "暫時無法讀取內容檢舉，請稍後再試。",
    FIRESTORE_QUERY_FAILED: "內容檢舉查詢暫時失敗，請確認資料庫索引與服務狀態。",
    SUPPORT_REPORT_NOT_FOUND: "這個檢舉案件已不存在或已被移除。",
    STALE_SUPPORT_REPORT_VERSION: "案件剛被其他管理員更新，已重新載入最新狀態。",
    SUPPORT_REPORT_TRANSITION_NOT_ALLOWED: "這個案件已結案，不能再執行目前的動作。",
    SUPPORT_REPORT_NOTE_REQUIRED: "請填寫至少 3 個字的處理紀錄。",
    INVALID_SUPPORT_REPORT_ACTION: "無法辨識這個處理動作。",
    ADMIN_REQUIRED: "這個帳號沒有管理員權限。",
    NETWORK_ERROR: "目前無法連上管理服務，請確認連線後再試。",
  }[code] || errorMessage(code);
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function emptySummary() {
  return { total: 0, actionable: 0, draft: 0, pendingReview: 0, needsMoreInformation: 0, approved: 0, rejected: 0, suspended: 0 };
}

function emptyReportSummary() {
  return { total: 0, open: 0, reviewing: 0, resolved: 0, dismissed: 0 };
}

function loadPreviewState() {
  state.phase = "ready";
  state.admin = { email: "admin@englishplus.tw", displayName: "English+ 管理員" };
  state.summary = { total: 12, actionable: 4, draft: 1, pendingReview: 3, needsMoreInformation: 1, approved: 6, rejected: 1, suspended: 0 };
  state.applications = [
    {
      uid: "preview-volunteer-001",
      displayName: "陳怡安",
      status: "pendingReview",
      motivation: "希望運用英文能力陪伴偏鄉學生，協助學生理解錯題，也願意接受老師安排的服務班級與時段。",
      confirmsAge18OrOlder: true,
      acceptedConductVersion: "volunteer-conduct-v1",
      submittedAt: "2026-07-14T03:20:00Z",
      reviewedAt: "",
      reviewNote: "",
      version: "2026-07-14T03:20:00.000000Z",
      evidenceDeletedAt: "",
      evidence: [
        { id: "e1", kind: "universityEnrollment", objectKey: "preview", filename: "在學證明.pdf", sizeBytes: 482304 },
        { id: "e2", kind: "englishProficiency", objectKey: "preview", filename: "英語能力證明.jpg", sizeBytes: 1248307 },
      ],
    },
    { uid: "preview-volunteer-002", displayName: "林子晴", status: "needsMoreInformation", motivation: "想參與線上陪讀。", confirmsAge18OrOlder: true, acceptedConductVersion: "volunteer-conduct-v1", submittedAt: "2026-07-13T08:40:00Z", reviewedAt: "2026-07-13T10:00:00Z", reviewNote: "請補上可辨識姓名的在學證明。", version: "2026-07-13T10:00:00.000000Z", evidenceDeletedAt: "", evidence: [] },
  ];
  state.previewApplications = state.applications;
  state.reportSummary = { total: 3, open: 1, reviewing: 1, resolved: 1, dismissed: 0 };
  state.reports = [
    {
      reportId: "preview-report-001",
      classId: "YILAN-CHENGZHI-8A",
      reporterUid: "student-preview-001",
      studentUid: "student-preview-001",
      studentName: "小安",
      reportedUid: "volunteer-preview-001",
      reportedRole: "volunteer",
      replyAuthorName: "林志工",
      threadId: "thread-preview-001",
      messageId: "message-preview-001",
      reason: "inappropriateContent",
      status: "open",
      createdAt: "2026-07-16T02:10:00Z",
      questionPrompt: "My parents ___ at home.",
      studentAnswer: "is",
      correctAnswer: "are",
      studentMessage: "我不知道複數主詞要怎麼判斷。",
      replyBody: "這麼簡單也不會，你應該先把答案背起來。",
      contentUnavailable: false,
      version: "2026-07-16T02:10:00.000Z",
      moderationNote: "",
      moderatedAt: "",
      moderatedByEmail: "",
    },
    {
      reportId: "preview-report-002",
      classId: "YILAN-CHENGZHI-8A",
      reporterUid: "student-preview-002",
      studentUid: "student-preview-002",
      studentName: "小晴",
      reportedUid: "teacher-preview-001",
      reportedRole: "teacher",
      replyAuthorName: "陳老師",
      threadId: "thread-preview-002",
      messageId: "message-preview-002",
      reason: "privacyConcern",
      status: "reviewing",
      createdAt: "2026-07-15T08:30:00Z",
      questionPrompt: "請將「我昨天完成作業」翻譯成英文。",
      studentAnswer: "I finish homework yesterday.",
      correctAnswer: "I finished my homework yesterday.",
      studentMessage: "不確定過去式怎麼用。",
      replyBody: "你可以把完整姓名和學校班級傳給我，我再幫你看。",
      contentUnavailable: false,
      version: "2026-07-15T09:00:00.000Z",
      moderationNote: "已開始確認是否涉及不必要的個人資料索取。",
      moderatedAt: "2026-07-15T09:00:00Z",
      moderatedByEmail: "admin@englishplus.tw",
    },
  ];
  state.previewReports = state.reports;
  state.previewAudits = new Map();
  state.api = {
    async applications({ status = "", query = "" } = {}) {
      const normalizedQuery = query.toLocaleLowerCase("zh-TW");
      const applications = state.previewApplications.filter((application) =>
        (!status || application.status === status) &&
        (!normalizedQuery || [application.displayName, application.uid, application.motivation]
          .join(" ")
          .toLocaleLowerCase("zh-TW")
          .includes(normalizedQuery))
      );
      return { applications, summary: state.summary };
    },
    async audit(uid) {
      return { events: state.previewAudits.get(uid) || [] };
    },
    async review(uid, { action, note }) {
      const application = state.previewApplications.find((item) => item.uid === uid);
      if (!application) throw new AdminApiError("VOLUNTEER_APPLICATION_NOT_FOUND", 404);
      const previousStatus = application.status;
      application.status = action;
      application.reviewNote = note;
      application.reviewedAt = new Date().toISOString();
      state.previewAudits.set(uid, [
        {
          id: crypto.randomUUID(),
          reviewerEmail: state.admin.email,
          previousStatus,
          resultingStatus: action,
          note,
          createdAt: application.reviewedAt,
        },
        ...(state.previewAudits.get(uid) || []),
      ]);
      return { ok: true };
    },
    async evidencePreview() {
      return { previewURL: `${adminApiBaseURL}/admin/evidence-file?ticket=preview` };
    },
    async supportReports({ status = "", query = "" } = {}) {
      const normalizedQuery = query.toLocaleLowerCase("zh-TW");
      const reports = state.previewReports.filter((report) =>
        (!status || report.status === status) &&
        (!normalizedQuery || [report.studentName, report.classId, report.replyAuthorName, report.replyBody]
          .join(" ")
          .toLocaleLowerCase("zh-TW")
          .includes(normalizedQuery))
      );
      return { reports, summary: state.reportSummary };
    },
    async reviewSupportReport(classId, reportId, { action, note }) {
      const report = state.previewReports.find((item) => item.classId === classId && item.reportId === reportId);
      if (!report) throw new AdminApiError("SUPPORT_REPORT_NOT_FOUND", 404);
      report.status = action;
      report.moderationNote = note;
      report.moderatedAt = new Date().toISOString();
      report.moderatedByEmail = state.admin.email;
      return { ok: true };
    },
  };
  state.selectedUid = state.applications[0].uid;
  state.selectedReportId = state.reports[0].reportId;
  state.audit = [];
  render();
}

function resetPreview() {
  state.phase = "signedOut";
  render();
}
