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
  History,
  LogOut,
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
import { adminApiBaseURL, firebaseConfig } from "./config.js";
import "./styles.css";

const iconSet = {
  Check,
  CheckCircle2,
  ChevronRight,
  CircleAlert,
  Clock3,
  Download,
  FileCheck2,
  History,
  LogOut,
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
const canonicalAdminOrigin = "https://englishplus-testflight.firebaseapp.com";
const shouldUseCanonicalOrigin = location.hostname === "englishplus-testflight.web.app";
const isLocalPreview =
  new URLSearchParams(location.search).get("preview") === "1" &&
  ["localhost", "127.0.0.1"].includes(location.hostname);

const state = {
  phase: "starting",
  authUser: null,
  admin: null,
  api: null,
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
    await loadApplications({ preserveSelection: false });
  } catch (error) {
    rememberError(error);
    state.phase = error.status === 403 ? "unauthorized" : "sessionError";
    render();
  }
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
  if (action === "reload") return loadApplications();
  if (action === "toggle-theme") return toggleTheme();
  if (action === "select-status") {
    state.filterStatus = trigger.dataset.status || "";
    return loadApplications({ preserveSelection: false });
  }
  if (action === "select-application") {
    state.selectedUid = trigger.dataset.uid || "";
    await loadAuditForSelection();
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
  if (form.id === "review-form") {
    const data = new FormData(form);
    return commitReview(String(data.get("note") || "").trim());
  }
}

function handleChange(event) {
  if (event.target.id === "status-filter") {
    state.filterStatus = event.target.value;
    loadApplications({ preserveSelection: false });
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
  render();
  requestAnimationFrame(() => document.querySelector("#review-dialog")?.showModal());
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
  } finally {
    state.actionLoading = false;
    render();
  }
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
        <section class="workspace-heading">
          <div><p class="eyebrow">志工資格審核</p><h1>申請工作台</h1><p>逐份確認資格證明，審核結果會同步到志工帳號。</p></div>
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
      </main>
      ${reviewDialog(application)}
    </div>`;
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

function filterControls() {
  return `<div class="rail-tools">
    <form id="search-form" class="search-box"><i data-lucide="search"></i><input name="query" type="search" value="${escapeHtml(state.filterQuery)}" placeholder="搜尋姓名、UID 或申請動機" /><button class="sr-only" type="submit">搜尋</button></form>
    <select id="status-filter" aria-label="依申請狀態篩選">${reviewStatuses.map((status) => `<option value="${status}" ${state.filterStatus === status ? "selected" : ""}>${status ? statusLabel(status) : "所有狀態"}</option>`).join("")}</select>
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

function reviewActionExplanation(action) {
  return {
    approved: "核准後，志工帳號會立即啟用；志工仍須加入服務班級後才能看到學生求助。",
    needsMoreInformation: "申請會退回待補件，志工可重新上傳證明並再次送審。",
    rejected: "申請會標記為未通過，帳號不會取得志工功能。",
    suspended: "帳號會停止使用志工功能，既有審核紀錄仍會保留。",
  }[action] || "";
}

function selectedApplication() {
  return state.applications.find((item) => item.uid === state.selectedUid) || null;
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
    async evidence() {
      return new Response("English+ local evidence preview", {
        headers: { "Content-Type": "text/plain; charset=utf-8" },
      });
    },
  };
  state.selectedUid = state.applications[0].uid;
  state.audit = [];
  render();
}

function resetPreview() {
  state.phase = "signedOut";
  render();
}
