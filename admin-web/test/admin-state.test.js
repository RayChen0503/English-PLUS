import { describe, expect, test } from "vitest";

import {
  availableReviewActions,
  errorMessage,
  formatBytes,
  statusLabel,
} from "../src/admin-state.js";

describe("administrator workflow presentation", () => {
  test("only states with a valid backend transition expose review actions", () => {
    expect(availableReviewActions("pendingReview")).toEqual([
      "approved",
      "needsMoreInformation",
      "rejected",
    ]);
    expect(availableReviewActions("approved")).toEqual(["suspended"]);
    expect(availableReviewActions("needsMoreInformation")).toEqual([]);
    expect(availableReviewActions("rejected")).toEqual([]);
  });

  test("status and error messages remain understandable to administrators", () => {
    expect(statusLabel("pendingReview")).toBe("待審核");
    expect(statusLabel("unknown")).toBe("未知狀態");
    expect(errorMessage("STALE_REVIEW_VERSION")).toContain("其他管理員更新");
    expect(errorMessage("REVIEW_NOTE_REQUIRED")).toContain("必須填寫原因");
    expect(errorMessage("NETWORK_ERROR")).toContain("網路");
    expect(errorMessage("EVIDENCE_READ_FAILED")).toContain("證明檔");
  });

  test("evidence sizes are presented consistently", () => {
    expect(formatBytes(100)).toBe("100 B");
    expect(formatBytes(1536)).toBe("1.5 KB");
    expect(formatBytes(2 * 1024 * 1024)).toBe("2.0 MB");
  });
});
