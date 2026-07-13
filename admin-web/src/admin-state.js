export const reviewStatuses = Object.freeze([
  "",
  "pendingReview",
  "needsMoreInformation",
  "approved",
  "rejected",
  "suspended",
  "draft",
]);

export const statusPresentation = Object.freeze({
  draft: { label: "草稿", tone: "neutral" },
  pendingReview: { label: "待審核", tone: "warning" },
  needsMoreInformation: { label: "待補件", tone: "info" },
  approved: { label: "已核准", tone: "success" },
  rejected: { label: "未通過", tone: "danger" },
  suspended: { label: "已停權", tone: "danger" },
});

export const actionPresentation = Object.freeze({
  approved: { label: "核准志工", confirm: "確認核准這位申請者？", tone: "primary" },
  needsMoreInformation: { label: "要求補件", confirm: "確認退回申請並要求補件？", tone: "secondary" },
  rejected: { label: "不予核准", confirm: "確認不予核准這份申請？", tone: "danger" },
  suspended: { label: "停用志工資格", confirm: "確認停用這個志工帳號？", tone: "danger" },
});

export function availableReviewActions(status) {
  if (status === "pendingReview") {
    return ["approved", "needsMoreInformation", "rejected"];
  }
  if (status === "approved") return ["suspended"];
  return [];
}

export function formatDate(value) {
  const date = new Date(value);
  if (!value || Number.isNaN(date.getTime())) return "尚無紀錄";
  return new Intl.DateTimeFormat("zh-TW", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: "Asia/Taipei",
  }).format(date);
}

export function formatBytes(value) {
  const bytes = Number(value) || 0;
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

export function statusLabel(status) {
  return statusPresentation[status]?.label || "未知狀態";
}

export function qualificationLabel(kind) {
  return {
    universityEnrollment: "大專院校在學證明",
    englishProficiency: "英語能力證明",
    educatorCredential: "教學相關資格",
    nonprofitOrVolunteerService: "非營利或志願服務證明",
    other: "其他證明",
  }[kind] || "證明文件";
}

export function errorMessage(code) {
  return {
    ADMIN_REQUIRED: "這個帳號沒有管理員權限。",
    AUTH_REQUIRED: "登入已失效，請重新登入。",
    STALE_REVIEW_VERSION: "申請內容已被其他管理員更新，請重新整理後再審核。",
    REVIEW_STATE_CONFLICT: "這份申請目前無法執行該操作，請重新整理。",
    REVIEW_NOTE_REQUIRED: "要求補件、不予核准或停權時必須填寫原因。",
    VOLUNTEER_APPLICATION_NOT_FOUND: "找不到這份志工申請。",
    EVIDENCE_NOT_FOUND: "證明檔已刪除或已超過保存期限。",
    APPLICATION_LIST_FAILED: "暫時無法讀取申請清單，請稍後重試。",
    AUDIT_LIST_FAILED: "暫時無法讀取審核紀錄。",
    REVIEW_COMMIT_FAILED: "審核結果未能儲存，請稍後重試。",
  }[code] || "操作未完成，請稍後重試。";
}
