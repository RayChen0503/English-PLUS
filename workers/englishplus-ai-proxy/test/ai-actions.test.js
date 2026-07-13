import assert from "node:assert/strict";
import { test } from "vitest";

import { normalizeOutput, normalizeRequest } from "../src/index.js";

test("wrong-answer AI rejects requests without a submitted answer", () => {
  const base = {
    taskType: "wrongAnswerExplanation",
    classId: "PERSONAL-TESTUSER",
    context: {
      questionPrompt: "My parents ___ at home.",
      correctAnswer: "are",
      attemptCount: 1,
    },
  };

  assert.throws(
    () => normalizeRequest(base),
    (error) => error.code === "AI_ANSWER_SUBMISSION_REQUIRED"
  );
  assert.throws(
    () => normalizeRequest({
      ...base,
      context: { ...base.context, studentAnswer: "尚未作答" },
    }),
    (error) => error.code === "AI_ANSWER_SUBMISSION_REQUIRED"
  );
  assert.throws(
    () => normalizeRequest({
      ...base,
      context: { ...base.context, studentAnswer: "is", attemptCount: 0 },
    }),
    (error) => error.code === "AI_ANSWER_SUBMISSION_REQUIRED"
  );
});

test("wrong-answer AI accepts a complete post-submission context", () => {
  const request = normalizeRequest({
    taskType: "wrongAnswerExplanation",
    classId: "PERSONAL-TESTUSER",
    context: {
      questionPrompt: "My parents ___ at home.",
      studentAnswer: "is",
      correctAnswer: "are",
      explanation: "A plural subject takes are.",
      attemptCount: 1,
    },
  });

  assert.equal(request.context.studentAnswer, "is");
  assert.equal(request.context.attemptCount, 1);
});

test("progress summary becomes a bounded executable practice plan", () => {
  const output = normalizeOutput("progressSummary", {
    summary: "先補 be 動詞，再挑戰克漏字。",
    recommendedNextAction: "直接開始這組練習。",
    practicePlan: {
      title: "be 動詞與克漏字",
      targetQuestionCount: 9,
      focusSkills: ["be 動詞", "文意推論", "多餘能力點", "不應保留"],
      questionPlan: [
        { type: "multipleChoice", difficulty: "core", targetCorrect: 5 },
        { type: "cloze", difficulty: "exam", targetCorrect: 4 },
      ],
    },
  });

  assert.equal(output.practicePlan.title, "be 動詞與克漏字");
  assert.equal(output.practicePlan.targetQuestionCount, 9);
  assert.equal(output.practicePlan.questionPlan.length, 2);
  assert.equal(
    output.practicePlan.questionPlan.reduce((total, item) => total + item.targetCorrect, 0),
    9
  );
  assert.deepEqual(output.practicePlan.focusSkills, ["be 動詞", "文意推論", "多餘能力點"]);
});

test("invalid AI plan values are replaced and capped before reaching iOS", () => {
  const output = normalizeOutput("progressSummary", {
    practicePlan: {
      title: "  ",
      targetQuestionCount: 100,
      focusSkills: ["grammar"],
      questionPlan: [
        { type: "inventedType", difficulty: "impossible", targetCorrect: 99 },
      ],
    },
  });

  assert.equal(output.practicePlan.title, "下一組個人化練習");
  assert.equal(output.practicePlan.targetQuestionCount, 6);
  assert.deepEqual(output.practicePlan.questionPlan, [
    { type: "multipleChoice", difficulty: "core", targetCorrect: 6 },
  ]);
});

test("missing practice plan still produces an executable fallback shape", () => {
  const output = normalizeOutput("progressSummary", {
    summary: "先從文法開始。",
  });

  assert.equal(output.practicePlan.targetQuestionCount, 6);
  assert.equal(output.practicePlan.questionPlan.length, 1);
  assert.equal(output.practicePlan.questionPlan[0].type, "multipleChoice");
});

test("staff draft fields stay separate for preview, adoption and next action", () => {
  const output = normalizeOutput("teacherFeedbackDraft", {
    teacherSummary: "主詞與 be 動詞對應不穩。",
    studentFacingFeedback: "先圈出主詞，再選對應的 be 動詞。",
    recommendedNextAction: "完成一題同類題後再確認。",
  });

  assert.equal(output.teacherSummary, "主詞與 be 動詞對應不穩。");
  assert.equal(output.studentFacingFeedback, "先圈出主詞，再選對應的 be 動詞。");
  assert.equal(output.recommendedNextAction, "完成一題同類題後再確認。");
});
