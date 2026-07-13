import assert from "node:assert/strict";
import { env } from "cloudflare:workers";
import { test } from "vitest";

import {
  aiQuotaPolicy,
  aiTaskCost,
  assertAiTaskRole,
  personalScopeIdForUid,
  reserveAiQuota,
} from "../src/index.js";

test("internal testing mode is lenient while public mode is deliberately stricter", () => {
  assert.deepEqual(aiQuotaPolicy("internal"), {
    dailyUnitLimit: 180,
    burstLimit: 30,
    burstPeriodSeconds: 60,
  });
  assert.deepEqual(aiQuotaPolicy("public"), {
    dailyUnitLimit: 60,
    burstLimit: 8,
    burstPeriodSeconds: 60,
  });
  assert.equal(aiTaskCost("dailyMission", "free"), 4);
  assert.equal(aiTaskCost("teacherFeedbackDraft", "quality"), 6);
});

test("AI tasks are least-privilege by authenticated role", () => {
  assert.doesNotThrow(() => assertAiTaskRole("student", "dailyMission"));
  assert.doesNotThrow(() => assertAiTaskRole("student", "wrongAnswerExplanation"));
  assert.doesNotThrow(() => assertAiTaskRole("teacher", "teacherFeedbackDraft"));
  assert.doesNotThrow(() => assertAiTaskRole("volunteer", "volunteerReplyCoach"));

  assert.throws(
    () => assertAiTaskRole("student", "teacherFeedbackDraft"),
    (error) => error.code === "AI_TASK_ROLE_FORBIDDEN"
  );
  assert.throws(
    () => assertAiTaskRole("teacher", "dailyMission"),
    (error) => error.code === "AI_TASK_ROLE_FORBIDDEN"
  );
  assert.throws(
    () => assertAiTaskRole("volunteer", "teacherFeedbackDraft"),
    (error) => error.code === "AI_TASK_ROLE_FORBIDDEN"
  );
});

test("personal AI scope is deterministic and bound to the Firebase uid", () => {
  assert.equal(
    personalScopeIdForUid("student.demo+1@example.test"),
    "PERSONAL-STUDENT-DEMO-1-EXAMPLE-TEST"
  );
  assert.equal(personalScopeIdForUid("a".repeat(80)), `PERSONAL-${"A".repeat(48)}`);
});

test("Durable Object quota is atomic, retry-safe and resets at Taipei midnight", async () => {
  const stub = env.AI_QUOTA.getByName(`quota-test-${crypto.randomUUID()}`);
  const firstDay = Date.parse("2026-07-13T12:00:00.000Z");
  const nextDay = Date.parse("2026-07-13T16:00:01.000Z");

  const first = await stub.reserve({
    mode: "public",
    taskType: "dailyMission",
    requestId: "request-first",
    cost: 20,
    nowMs: firstDay,
  });
  assert.equal(first.allowed, true);
  assert.equal(first.usedUnits, 20);
  assert.equal(first.remainingUnits, 40);
  assert.equal(first.resetAt, "2026-07-13T16:00:00.000Z");

  const duplicate = await stub.reserve({
    mode: "public",
    taskType: "dailyMission",
    requestId: "request-first",
    cost: 20,
    nowMs: firstDay,
  });
  assert.equal(duplicate.allowed, true);
  assert.equal(duplicate.duplicate, true);
  assert.equal(duplicate.usedUnits, 20);
  assert.equal(duplicate.callCount, 1);

  for (const requestId of ["request-second", "request-third"]) {
    const accepted = await stub.reserve({
      mode: "public",
      taskType: "wrongAnswerExplanation",
      requestId,
      cost: 20,
      nowMs: firstDay,
    });
    assert.equal(accepted.allowed, true);
  }

  const denied = await stub.reserve({
    mode: "public",
    taskType: "progressSummary",
    requestId: "request-over-limit",
    cost: 1,
    nowMs: firstDay,
  });
  assert.equal(denied.allowed, false);
  assert.equal(denied.usedUnits, 60);
  assert.equal(denied.remainingUnits, 0);
  assert.equal(denied.callCount, 3);

  const reset = await stub.reserve({
    mode: "public",
    taskType: "progressSummary",
    requestId: "request-next-day",
    cost: 3,
    nowMs: nextDay,
  });
  assert.equal(reset.allowed, true);
  assert.equal(reset.dateKey, "2026-07-14");
  assert.equal(reset.usedUnits, 3);
  assert.equal(reset.callCount, 1);
  assert.equal(reset.resetAt, "2026-07-14T16:00:00.000Z");
});

test("Cloudflare rate limiting bindings are present in the runtime contract", () => {
  assert.equal(typeof env.AI_INTERNAL_BURST_LIMITER?.limit, "function");
  assert.equal(typeof env.AI_PUBLIC_BURST_LIMITER?.limit, "function");
});

test("replaying a request id cannot call the provider without consuming quota", async () => {
  const runtimeEnv = {
    AI_QUOTA: env.AI_QUOTA,
    AI_QUOTA_MODE: "internal",
  };
  const uid = `replay-test-${crypto.randomUUID()}`;
  const request = { taskType: "wrongAnswerExplanation", qualityMode: "free" };
  const requestId = "replay-request-id";

  const first = await reserveAiQuota(runtimeEnv, uid, request, requestId);
  assert.equal(first.allowed, true);
  assert.equal(first.duplicate, false);

  await assert.rejects(
    () => reserveAiQuota(runtimeEnv, uid, request, requestId),
    (error) => error.status === 409 && error.code === "AI_REQUEST_ID_REUSED"
  );
});
