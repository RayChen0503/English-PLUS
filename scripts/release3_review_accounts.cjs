#!/usr/bin/env node
"use strict";

const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const admin = require("../functions/node_modules/firebase-admin");

const ROOT = path.resolve(__dirname, "..");
const SPEC_PATH = path.join(ROOT, "docs", "app-store-release", "store-4", "review-seed-spec.json");
const QUESTION_BANK_PATH = path.join(
  ROOT,
  "ios",
  "EnglishPlus",
  "EnglishPlus",
  "Resources",
  "SeedData",
  "question_bank_seed.json"
);
const ADMIN_ENV_PATH = path.join(ROOT, "admin-web", ".env.production");
const PROJECT_ID = "englishplus-production";
const WORKER_BASE_URL = "https://englishplus-ai-proxy-production.englishplus-ray.workers.dev";
const CONSENT_VERSION = "privacy-v3-2026-07-16";
const RESET_POLICY = "idempotent-replace-review-scope";
const POLICY_URL = "https://sites.google.com/view/englishplus-privacy/%E9%9A%B1%E7%A7%81%E6%94%BF%E7%AD%96";

const REVIEW_ACCOUNTS = {
  student: {
    email: "englishplus.tw+review.student@gmail.com",
    displayName: "Review Student",
    role: "student",
  },
  teacher: {
    email: "englishplus.tw+review.teacher@gmail.com",
    displayName: "Review Teacher",
    role: "teacher",
  },
  volunteer: {
    email: "englishplus.tw+review.volunteer@gmail.com",
    displayName: "Review Volunteer",
    role: "volunteer",
  },
};

const QUESTION_METADATA = {
  "ios-cap-0001": {
    unit: "字彙與語意", skill: "校園與生活字彙", typeTitle: "單字", levelTitle: "基礎",
    repairHint: "先找出題目描述的場所功能，再比對最符合的單字。",
  },
  "ios-cap-0121": {
    unit: "文法與句構", skill: "be 動詞與主詞一致", typeTitle: "文法選擇", levelTitle: "基礎",
    repairHint: "先圈出主詞，再判斷人稱與單複數，選擇相符的 be 動詞。",
  },
  "ios-cap-0301": {
    unit: "文法與句構", skill: "時間介系詞與完成式", typeTitle: "填空", levelTitle: "穩定",
    explanation: "since 接時間起點；2020 是開始的年份，所以使用 since。",
    repairHint: "先判斷空格後是時間起點或一段時間；年份 2020 是起點。",
  },
  "ios-cap-0481": {
    unit: "克漏字與文意", skill: "語篇連接與邏輯", typeTitle: "克漏字", levelTitle: "會考挑戰",
    repairHint: "先看空格前後的邏輯；即使時間不多仍能閱讀，表示讓步關係。",
  },
  "ios-cap-0641": {
    unit: "閱讀理解", skill: "生活文本資訊擷取", typeTitle: "閱讀理解", levelTitle: "穩定",
    repairHint: "先找題目問的時間與地點，再回到海報定位相同資訊。",
  },
};

function fail(message) {
  throw new Error(message);
}

function parseArgs(argv) {
  const result = { apply: false, verify: false, live: false, confirm: "" };
  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    if (value === "--apply") result.apply = true;
    else if (value === "--verify") result.verify = true;
    else if (value === "--live") result.live = true;
    else if (value === "--confirm") result.confirm = argv[++index] || "";
    else fail(`Unknown argument: ${value}`);
  }
  if (!result.apply && !result.verify) fail("Choose --apply or --verify.");
  if (result.apply && result.confirm !== PROJECT_ID) {
    fail(`Apply requires --confirm ${PROJECT_ID}.`);
  }
  return result;
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function privateCredentialsPath() {
  const configured = process.env.ENGLISHPLUS_REVIEW_CREDENTIALS_FILE;
  if (!configured) fail("ENGLISHPLUS_REVIEW_CREDENTIALS_FILE is required.");
  const resolved = path.resolve(configured);
  const relative = path.relative(ROOT, resolved);
  if (!relative.startsWith("..") || path.isAbsolute(relative)) {
    fail("Review credentials must be stored outside the Git repository.");
  }
  return resolved;
}

function randomPassword() {
  return `${crypto.randomBytes(18).toString("base64url")}aA7!`;
}

function loadOrCreateCredentials(filePath, allowCreate) {
  if (!fs.existsSync(filePath)) {
    if (!allowCreate) fail("Private review credential file is missing.");
    fs.mkdirSync(path.dirname(filePath), { recursive: true });
    const payload = {
      schemaVersion: 1,
      projectId: PROJECT_ID,
      createdAt: new Date().toISOString(),
      accounts: Object.fromEntries(
        Object.entries(REVIEW_ACCOUNTS).map(([key, account]) => [
          key,
          { email: account.email, password: randomPassword() },
        ])
      ),
    };
    fs.writeFileSync(filePath, `${JSON.stringify(payload, null, 2)}\n`, { encoding: "utf8", mode: 0o600 });
  }
  const credentials = readJson(filePath);
  if (credentials.projectId !== PROJECT_ID) fail("Private credential file targets the wrong Firebase project.");
  for (const [key, account] of Object.entries(REVIEW_ACCOUNTS)) {
    const stored = credentials.accounts?.[key];
    if (stored?.email !== account.email || typeof stored?.password !== "string" || stored.password.length < 16) {
      fail(`Private credential entry is invalid: ${key}`);
    }
  }
  return credentials;
}

function loadServiceAccount() {
  const filePath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!filePath || !fs.existsSync(filePath)) fail("GOOGLE_APPLICATION_CREDENTIALS is missing.");
  const serviceAccount = readJson(filePath);
  if (serviceAccount.project_id !== PROJECT_ID) fail("Service account targets the wrong Firebase project.");
  return serviceAccount;
}

function parseEnv(filePath) {
  const result = {};
  if (!fs.existsSync(filePath)) return result;
  for (const rawLine of fs.readFileSync(filePath, "utf8").split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#") || !line.includes("=")) continue;
    const separator = line.indexOf("=");
    result[line.slice(0, separator).trim()] = line.slice(separator + 1).trim().replace(/^['"]|['"]$/g, "");
  }
  return result;
}

function questionMap(spec) {
  const payload = readJson(QUESTION_BANK_PATH);
  const items = Array.isArray(payload) ? payload : payload.items;
  const result = new Map(items.map((item) => [item.id, item]));
  for (const questionId of spec.assignment.questionIds) {
    const item = result.get(questionId);
    if (!item || item.reviewState !== "approved") fail(`Approved review question is missing: ${questionId}`);
    if (!QUESTION_METADATA[questionId]) fail(`Review question metadata is missing: ${questionId}`);
  }
  return result;
}

async function ensureAuthUsers(auth, credentials) {
  const users = {};
  for (const [key, account] of Object.entries(REVIEW_ACCOUNTS)) {
    const password = credentials.accounts[key].password;
    let user;
    try {
      user = await auth.getUserByEmail(account.email);
      user = await auth.updateUser(user.uid, {
        displayName: account.displayName,
        password,
        emailVerified: true,
        disabled: false,
      });
    } catch (error) {
      if (error?.code !== "auth/user-not-found") throw error;
      user = await auth.createUser({
        email: account.email,
        password,
        displayName: account.displayName,
        emailVerified: true,
        disabled: false,
      });
    }
    await auth.setCustomUserClaims(user.uid, { reviewAccount: true });
    users[key] = user;
  }
  return users;
}

async function deleteReviewScope(db, users, spec) {
  const classId = spec.scope.classId;
  await db.recursiveDelete(db.doc(`classes/${classId}`));
  const topLevelPaths = [
    `classAdmins/${classId}`,
    `classJoinCodes/${spec.scope.joinCode}`,
    `volunteerJoinCodes/${spec.scope.volunteerJoinCode}`,
    `teacherProfiles/${users.teacher.uid}`,
    `volunteerApplications/${users.volunteer.uid}`,
  ];
  await Promise.all(topLevelPaths.map((item) => db.doc(item).delete()));
  await Promise.all(Object.values(users).map((user) => db.recursiveDelete(db.doc(`users/${user.uid}`))));
}

function profileDocument(key, user, now, classId) {
  const account = REVIEW_ACCOUNTS[key];
  const source = key === "student" ? "selfServiceStudent" : key === "teacher" ? "selfServiceTeacher" : "selfServiceVolunteer";
  return {
    displayName: account.displayName,
    preferredName: account.displayName,
    primaryRole: account.role,
    activeClassId: classId,
    createdAt: now,
    updatedAt: now,
    lastLoginAt: now,
    active: true,
    accountStatus: "active",
    emailVerificationRequired: false,
    provisioningSource: source,
    studentAccessPath: key === "student" ? "age13OrOlder" : "notApplicable",
    identityProviders: ["emailPassword"],
    reviewAccount: true,
  };
}

function memberDocument(key, user, spec, now, joinedAt = now) {
  return {
    uid: user.uid,
    classId: spec.scope.classId,
    className: spec.scope.className,
    role: REVIEW_ACCOUNTS[key].role,
    displayName: REVIEW_ACCOUNTS[key].displayName,
    status: "active",
    active: true,
    joinedAt,
    visibilityStartsAt: joinedAt,
    leftAt: null,
    updatedAt: now,
  };
}

function userMembershipDocument(key, spec, now, joinedAt = now) {
  return {
    classId: spec.scope.classId,
    className: spec.scope.className,
    role: REVIEW_ACCOUNTS[key].role,
    groupId: null,
    status: "active",
    active: true,
    joinedAt,
    visibilityStartsAt: joinedAt,
    leftAt: null,
    updatedAt: now,
  };
}

function consentDocument(key, user, classId, now) {
  const categories = {
    student: ["identity", "schoolContext", "learningRecords", "moodCheckIn", "supportThreads", "aiAssistance"],
    teacher: ["identity", "schoolContext", "learningRecords", "supportThreads", "aiAssistance"],
    volunteer: ["identity", "supportThreads", "aiAssistance", "volunteerEvidence"],
  };
  return {
    version: CONSENT_VERSION,
    accepted: true,
    acceptedAt: now,
    acceptedByUid: user.uid,
    actorRole: REVIEW_ACCOUNTS[key].role,
    classId,
    consentSource: "inAppCheckbox",
    schoolApprovalRef: "",
    guardianConsentStatus: key === "student" ? "notRequired" : "notRequired",
    studentAccessPath: key === "student" ? "age13OrOlder" : "notApplicable",
    policyUrl: POLICY_URL,
    categoriesAccepted: categories[key],
  };
}

function snapshotFor(questionId, questions, selectedAnswer) {
  const item = questions.get(questionId);
  const meta = QUESTION_METADATA[questionId];
  return {
    questionId,
    prompt: item.question.prompt,
    options: item.question.options,
    questionTypeTitle: meta.typeTitle,
    levelTitle: meta.levelTitle,
    skill: meta.skill,
    selectedAnswer,
    correctAnswer: item.question.answer,
    explanation: meta.explanation || item.question.explanation,
    repairHint: meta.repairHint,
  };
}

function supportThreadDocument(input) {
  return {
    threadId: input.threadId,
    studentUid: input.student.uid,
    studentName: REVIEW_ACCOUNTS.student.displayName,
    classId: input.spec.scope.classId,
    messageContextVersion: 2,
    status: input.status,
    reason: "stuck_on_question",
    route: "humanHandoff",
    priority: "medium",
    assignedToUid: null,
    assignedRole: null,
    studentVisible: true,
    studentMessage: input.studentMessage,
    moodScore: 3,
    latestQuestionId: input.questionId,
    questionSnapshot: input.snapshot,
    studentArchivedAt: null,
    withdrawnAt: null,
    staffArchivedAt: null,
    teacherArchivedAt: null,
    volunteerArchivedAt: null,
    handledWithoutReplyAt: null,
    teacherHandledWithoutReplyAt: null,
    volunteerHandledWithoutReplyAt: null,
    handledByUid: null,
    handledByName: null,
    handledByRole: null,
    studentLastReadAt: null,
    latestMessagePreview: input.latestMessagePreview,
    createdAt: input.createdAt,
    updatedAt: input.updatedAt,
  };
}

async function writeSeed(db, users, spec, questions) {
  const now = admin.firestore.Timestamp.now();
  const earlier = admin.firestore.Timestamp.fromMillis(now.toMillis() - 15 * 60 * 1000);
  const classId = spec.scope.classId;
  const batch = db.batch();
  const set = (documentPath, data) => batch.set(db.doc(documentPath), data);

  for (const [key, user] of Object.entries(users)) {
    set(`users/${user.uid}`, profileDocument(key, user, now, classId));
    set(`users/${user.uid}/classMemberships/${classId}`, userMembershipDocument(key, spec, now, earlier));
    set(`users/${user.uid}/consents/${CONSENT_VERSION}`, consentDocument(key, user, classId, now));
    set(`classes/${classId}/members/${user.uid}`, memberDocument(key, user, spec, now, earlier));
  }

  set(`teacherProfiles/${users.teacher.uid}`, {
    uid: users.teacher.uid,
    displayName: REVIEW_ACCOUNTS.teacher.displayName,
    institutionId: "APP-REVIEW-INSTITUTION",
    institutionName: "English+ Review School",
    institutionKind: "juniorHighSchool",
    institutionSource: "userSubmitted",
    claimStatus: "selfDeclared",
    createdAt: now,
    updatedAt: now,
  });

  set(`volunteerApplications/${users.volunteer.uid}`, {
    uid: users.volunteer.uid,
    displayName: REVIEW_ACCOUNTS.volunteer.displayName,
    status: "approved",
    confirmsAge18OrOlder: true,
    acceptedConductVersion: "volunteer-conduct-v1",
    motivation: "Synthetic App Review volunteer profile.",
    evidence: [],
    submittedAt: earlier,
    updatedAt: now,
    reviewedByUid: "production-review-seed",
    reviewedAt: now,
    reviewNote: "Approved synthetic App Review account.",
    evidenceRetentionUntil: null,
    evidenceDeletedAt: now,
  });

  set(`classes/${classId}`, {
    classId,
    name: spec.scope.className,
    ownerTeacherUid: users.teacher.uid,
    active: true,
    lifecycleStatus: "active",
    deletionPending: false,
    createdAt: earlier,
    updatedAt: now,
  });
  set(`classAdmins/${classId}`, {
    classId,
    ownerTeacherUid: users.teacher.uid,
    joinCode: spec.scope.joinCode,
    volunteerJoinCode: spec.scope.volunteerJoinCode,
    active: true,
    codeVersion: 1,
    volunteerCodeVersion: 1,
    createdAt: earlier,
    updatedAt: now,
  });
  set(`classJoinCodes/${spec.scope.joinCode}`, {
    classId,
    active: true,
    codeVersion: 1,
    createdAt: earlier,
  });
  set(`volunteerJoinCodes/${spec.scope.volunteerJoinCode}`, {
    classId,
    active: true,
    codeVersion: 1,
    createdAt: earlier,
  });
  const volunteerService = {
    classId,
    className: spec.scope.className,
    volunteerUid: users.volunteer.uid,
    volunteerName: REVIEW_ACCOUNTS.volunteer.displayName,
    status: "active",
    requestedAt: earlier,
    decidedAt: now,
    joinedAt: now,
    updatedAt: now,
  };
  set(`classes/${classId}/volunteerRequests/${users.volunteer.uid}`, volunteerService);
  set(`users/${users.volunteer.uid}/volunteerServices/${classId}`, volunteerService);

  set(`classes/${classId}/students/${users.student.uid}`, {
    uid: users.student.uid,
    displayName: REVIEW_ACCOUNTS.student.displayName,
    gradeBand: "junior-high",
    classCode: classId,
    currentLevel: "A2",
    recommendedTrack: "steady",
    lastMoodScore: 3,
    lastMissionStatus: "notStarted",
    lastActivityAt: now,
    riskLevel: "low",
    membershipStatus: "active",
    legacyAndroidId: null,
    updatedAt: now,
  });
  set(`classes/${classId}/students/${users.student.uid}/consents/${CONSENT_VERSION}`, consentDocument("student", users.student, classId, now));

  for (const questionId of spec.assignment.questionIds) {
    const item = questions.get(questionId);
    const meta = QUESTION_METADATA[questionId];
    set(`classes/${classId}/questionBank/${questionId}`, {
      questionId,
      level: item.level,
      type: item.question.type,
      skillTags: [meta.unit, meta.skill],
      prompt: item.question.prompt,
      choices: item.question.options,
      answer: item.question.answer,
      acceptedAnswers: item.question.acceptedAnswers,
      explanation: meta.explanation || item.question.explanation,
      repairHint: meta.repairHint,
      reviewState: "approved",
      source: { kind: "englishPlusOriginal", note: "Synthetic App Review seed" },
      updatedAt: now,
    });
  }

  set(`classes/${classId}/practiceAssignments/${spec.assignment.id}`, {
    assignmentId: spec.assignment.id,
    classId,
    studentUid: users.student.uid,
    studentName: REVIEW_ACCOUNTS.student.displayName,
    setId: "APP-REVIEW-SET-01",
    setTitle: spec.assignment.title,
    questionIds: spec.assignment.questionIds,
    assignedByUid: users.teacher.uid,
    assignedByName: REVIEW_ACCOUNTS.teacher.displayName,
    status: "pending",
    questionResults: [],
    createdAt: earlier,
    updatedAt: now,
  });

  const answeredQuestion = questions.get(spec.learningState.completedAttemptQuestionId);
  set(`classes/${classId}/students/${users.student.uid}/answerEvents/APP-REVIEW-ANSWER-01`, {
    eventId: "APP-REVIEW-ANSWER-01",
    questionId: answeredQuestion.id,
    missionId: null,
    studentAnswer: answeredQuestion.question.answer,
    isCorrect: true,
    attemptNumber: 1,
    aiExplanation: null,
    createdAt: earlier,
  });
  set(`classes/${classId}/students/${users.student.uid}/skillMastery/APP-REVIEW-MASTERY-01`, {
    masteryId: "APP-REVIEW-MASTERY-01",
    studentUid: users.student.uid,
    curriculumKey: "vocabulary|A1|校園與生活字彙",
    unit: "字彙與語意",
    skill: spec.learningState.masterySkill,
    questionType: "vocabulary",
    level: "A1",
    attemptCount: 1,
    correctCount: 1,
    firstTryCorrectCount: 1,
    consecutiveCorrectCount: 1,
    masteryScore: 0.25,
    lastQuestionId: answeredQuestion.id,
    lastResultCorrect: true,
    lastAttemptSource: "reviewSeed",
    lastAnsweredAt: earlier,
    nextReviewAt: admin.firestore.Timestamp.fromMillis(now.toMillis() + 24 * 60 * 60 * 1000),
    updatedAt: now,
  });

  const pending = spec.supportThreads[0];
  const pendingSnapshot = snapshotFor(pending.questionId, questions, "for");
  const pendingMessage = "I am not sure whether this sentence needs since or for.";
  set(`classes/${classId}/supportThreads/${pending.id}`, supportThreadDocument({
    threadId: pending.id,
    student: users.student,
    spec,
    status: "waitingForStaff",
    questionId: pending.questionId,
    snapshot: pendingSnapshot,
    studentMessage: pendingMessage,
    latestMessagePreview: pendingMessage,
    createdAt: earlier,
    updatedAt: earlier,
  }));
  set(`classes/${classId}/supportThreads/${pending.id}/messages/APP-REVIEW-PENDING-STUDENT`, {
    messageId: "APP-REVIEW-PENDING-STUDENT",
    threadId: pending.id,
    classId,
    studentUid: users.student.uid,
    contextVersion: 2,
    authorUid: users.student.uid,
    authorName: REVIEW_ACCOUNTS.student.displayName,
    authorRole: "student",
    body: pendingMessage,
    visibility: "studentVisible",
    messageType: "studentRequest",
    createdAt: earlier,
  });

  const resolved = spec.supportThreads[1];
  const resolvedSnapshot = snapshotFor(resolved.questionId, questions, "unless");
  const resolvedStudentMessage = "I cannot tell how the two ideas are connected.";
  const resolvedReply = "Look for a contrast: students can read more despite having little free time, so even if fits.";
  set(`classes/${classId}/supportThreads/${resolved.id}`, supportThreadDocument({
    threadId: resolved.id,
    student: users.student,
    spec,
    status: "replied",
    questionId: resolved.questionId,
    snapshot: resolvedSnapshot,
    studentMessage: resolvedStudentMessage,
    latestMessagePreview: resolvedReply,
    createdAt: earlier,
    updatedAt: now,
  }));
  set(`classes/${classId}/supportThreads/${resolved.id}/messages/APP-REVIEW-RESOLVED-STUDENT`, {
    messageId: "APP-REVIEW-RESOLVED-STUDENT",
    threadId: resolved.id,
    classId,
    studentUid: users.student.uid,
    contextVersion: 2,
    authorUid: users.student.uid,
    authorName: REVIEW_ACCOUNTS.student.displayName,
    authorRole: "student",
    body: resolvedStudentMessage,
    visibility: "studentVisible",
    messageType: "studentRequest",
    createdAt: earlier,
  });
  set(`classes/${classId}/supportThreads/${resolved.id}/messages/APP-REVIEW-RESOLVED-TEACHER`, {
    messageId: "APP-REVIEW-RESOLVED-TEACHER",
    threadId: resolved.id,
    classId,
    studentUid: users.student.uid,
    contextVersion: 2,
    authorUid: users.teacher.uid,
    authorName: REVIEW_ACCOUNTS.teacher.displayName,
    authorRole: "teacher",
    body: resolvedReply,
    visibility: "studentVisible",
    messageType: "teacherReply",
    createdAt: now,
  });

  await batch.commit();
}

async function verifyFirestore(db, users, spec) {
  const requiredPaths = [
    `classes/${spec.scope.classId}`,
    `classAdmins/${spec.scope.classId}`,
    `classJoinCodes/${spec.scope.joinCode}`,
    `volunteerJoinCodes/${spec.scope.volunteerJoinCode}`,
    `classes/${spec.scope.classId}/practiceAssignments/${spec.assignment.id}`,
    `classes/${spec.scope.classId}/supportThreads/${spec.supportThreads[0].id}`,
    `classes/${spec.scope.classId}/supportThreads/${spec.supportThreads[1].id}`,
  ];
  for (const [key, user] of Object.entries(users)) {
    requiredPaths.push(`users/${user.uid}`);
    requiredPaths.push(`users/${user.uid}/consents/${CONSENT_VERSION}`);
    requiredPaths.push(`users/${user.uid}/classMemberships/${spec.scope.classId}`);
    requiredPaths.push(`classes/${spec.scope.classId}/members/${user.uid}`);
    if (key === "volunteer") requiredPaths.push(`volunteerApplications/${user.uid}`);
  }
  const snapshots = await db.getAll(...requiredPaths.map((item) => db.doc(item)));
  const missing = snapshots.filter((snapshot) => !snapshot.exists).map((snapshot) => snapshot.ref.path);
  if (missing.length) fail(`Missing review seed documents: ${missing.join(", ")}`);

  const volunteerProfile = (await db.doc(`users/${users.volunteer.uid}`).get()).data();
  const volunteerApplication = (await db.doc(`volunteerApplications/${users.volunteer.uid}`).get()).data();
  if (volunteerProfile.accountStatus !== "active" || volunteerApplication.status !== "approved") {
    fail("Volunteer review account is not approved and active.");
  }
}

async function firebasePasswordSignIn(apiKey, email, password) {
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${encodeURIComponent(apiKey)}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    }
  );
  const payload = await response.json();
  if (!response.ok || !payload.idToken) fail(`Password sign-in smoke failed for ${email}.`);
  return payload.idToken;
}

async function authenticatedJson(url, idToken, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: {
      ...(options.headers || {}),
      Authorization: `Bearer ${idToken}`,
    },
  });
  const payload = await response.json();
  if (!response.ok) {
    const requestPath = new URL(url).pathname;
    fail(`Authenticated request to ${requestPath} failed with HTTP ${response.status}.`);
  }
  return payload;
}

async function expectDenied(url, idToken) {
  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${idToken}` },
  });
  if (response.status !== 403) {
    fail(`Expected an authorization denial but received HTTP ${response.status}.`);
  }
}

function firestoreDocumentUrl(documentPath) {
  const encodedPath = documentPath.split("/").map(encodeURIComponent).join("/");
  return `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/${encodedPath}`;
}

async function firestoreDocument(idToken, documentPath) {
  return authenticatedJson(firestoreDocumentUrl(documentPath), idToken);
}

async function verifyLive(credentials) {
  const apiKey = process.env.ENGLISHPLUS_FIREBASE_API_KEY || parseEnv(ADMIN_ENV_PATH).VITE_FIREBASE_API_KEY;
  if (!apiKey) fail("Production Firebase API key is unavailable for live sign-in verification.");
  const tokens = {};
  for (const [key, account] of Object.entries(REVIEW_ACCOUNTS)) {
    const idToken = await firebasePasswordSignIn(apiKey, account.email, credentials.accounts[key].password);
    tokens[key] = idToken;
    const payload = await authenticatedJson(`${WORKER_BASE_URL}/classrooms`, idToken);
    if (payload.ok !== true || !Array.isArray(payload.classrooms)) {
      fail(`Production Worker classroom smoke failed for ${key}.`);
    }
    const classroom = payload.classrooms.find((item) => item.id === "APP-REVIEW-CLASS");
    if (!classroom || classroom.role !== account.role) fail(`Review classroom role mismatch for ${key}.`);
  }

  const classId = "APP-REVIEW-CLASS";
  const studentUid = (await admin.auth().getUserByEmail(REVIEW_ACCOUNTS.student.email)).uid;
  const studentAssignment = await firestoreDocument(
    tokens.student,
    `classes/${classId}/practiceAssignments/APP-REVIEW-ASSIGNMENT-01`
  );
  if (studentAssignment.fields?.studentUid?.stringValue !== studentUid) {
    fail("Student cannot read the assigned App Review task.");
  }
  const studentResolvedThread = await firestoreDocument(
    tokens.student,
    `classes/${classId}/supportThreads/APP-REVIEW-SUPPORT-RESOLVED`
  );
  if (studentResolvedThread.fields?.status?.stringValue !== "replied") {
    fail("Student cannot read the replied App Review support thread.");
  }
  await firestoreDocument(
    tokens.student,
    `classes/${classId}/supportThreads/APP-REVIEW-SUPPORT-RESOLVED/messages/APP-REVIEW-RESOLVED-TEACHER`
  );

  const teacherStudents = await authenticatedJson(
    `${WORKER_BASE_URL}/classrooms/${classId}/students`,
    tokens.teacher
  );
  if (
    teacherStudents.ok !== true
    || !teacherStudents.students?.some((item) => item.studentUid === studentUid || item.id === studentUid)
  ) {
    fail("Teacher cannot read the App Review student roster.");
  }
  await firestoreDocument(tokens.teacher, `classes/${classId}/supportThreads/APP-REVIEW-SUPPORT-PENDING`);

  const volunteerServices = await authenticatedJson(`${WORKER_BASE_URL}/volunteer-services`, tokens.volunteer);
  if (
    volunteerServices.ok !== true
    || !volunteerServices.services?.some((item) => item.classId === classId && item.status === "active")
  ) {
    fail("Volunteer does not have active App Review classroom service authorization.");
  }
  await firestoreDocument(tokens.volunteer, `classes/${classId}/supportThreads/APP-REVIEW-SUPPORT-PENDING`);

  await expectDenied(
    firestoreDocumentUrl(`classAdmins/${classId}`),
    tokens.student
  );
  await expectDenied(
    firestoreDocumentUrl(`classes/${classId}/students/${studentUid}`),
    tokens.volunteer
  );

  const productionAdmin = await admin.auth().getUserByEmail("englishplus.tw@gmail.com");
  if (productionAdmin.customClaims?.admin !== true || productionAdmin.disabled) {
    fail("Production administrator claim is missing or disabled.");
  }
  const hostingResponse = await fetch("https://englishplus-production.web.app", { redirect: "follow" });
  if (!hostingResponse.ok) fail(`Production admin Hosting returned HTTP ${hostingResponse.status}.`);
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const spec = readJson(SPEC_PATH);
  if (
    spec.environment !== "production-only"
    || spec.containsCredentials !== false
    || spec.containsRealPeople !== false
    || spec.resetPolicy !== RESET_POLICY
  ) {
    fail("Review seed specification safety contract is invalid.");
  }
  if (!/^[A-Z0-9-]{8}$/.test(spec.scope.joinCode)) fail("Student join code must be exactly 8 characters.");
  if (!/^[A-Z0-9-]{8}$/.test(spec.scope.volunteerJoinCode)) fail("Volunteer join code must be exactly 8 characters.");
  const questions = questionMap(spec);
  const credentialsPath = privateCredentialsPath();
  const credentials = loadOrCreateCredentials(credentialsPath, args.apply);
  const serviceAccount = loadServiceAccount();

  admin.initializeApp({ credential: admin.credential.cert(serviceAccount), projectId: PROJECT_ID });
  const auth = admin.auth();
  const db = admin.firestore();
  db.settings({ ignoreUndefinedProperties: true });

  let users;
  if (args.apply) {
    users = await ensureAuthUsers(auth, credentials);
    await deleteReviewScope(db, users, spec);
    await writeSeed(db, users, spec, questions);
  } else {
    users = Object.fromEntries(
      await Promise.all(Object.entries(REVIEW_ACCOUNTS).map(async ([key, account]) => [key, await auth.getUserByEmail(account.email)]))
    );
  }

  await verifyFirestore(db, users, spec);
  if (args.live) await verifyLive(credentials);
  console.log("RELEASE-3 review account verification passed");
  console.log("- three dedicated Email/password accounts are active");
  console.log("- student, teacher and volunteer share one isolated review classroom");
  console.log("- assignment, progress and support states are ready for App Review");
  if (args.live) console.log("- live role access, denial boundaries, admin claim and Hosting all passed");
  console.log("- no credential value was printed or written inside the repository");
}

main().catch((error) => {
  console.error(`RELEASE-3 failed: ${error.message}`);
  process.exitCode = 1;
});
