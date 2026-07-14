#!/usr/bin/env python3
import argparse
import datetime
import json
import plistlib
import re
import sys
import time
import urllib.error
import urllib.request
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any


WORKER_BASE_URL = "https://englishplus-ai-proxy.englishplus-ray.workers.dev"
PROJECT_ID = "englishplus-testflight"
TEST_ACCOUNTS = {
    "student": ("student.demo@englishplus.test", "EnglishPlusStudent2026!"),
    "teacher": ("teacher.demo@englishplus.test", "EnglishPlusTeacher2026!"),
    "volunteer": ("volunteer.demo@englishplus.test", "EnglishPlusVolunteer2026!"),
}


@dataclass
class Response:
    status: int
    body: dict[str, Any]
    headers: dict[str, str]


def request_json(
    url: str,
    method: str = "GET",
    payload: dict[str, Any] | None = None,
    token: str | None = None,
    request_id: str | None = None,
) -> Response:
    headers = {
        "Accept": "application/json",
        "User-Agent": "EnglishPlus-Deployment-SmokeTest/1.0",
    }
    data = None
    if payload is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(payload).encode("utf-8")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if request_id:
        headers["X-EnglishPlus-Request-ID"] = request_id
    request = urllib.request.Request(
        url,
        data=data,
        headers=headers,
        method=method,
    )
    try:
        with urllib.request.urlopen(request, timeout=40) as response:
            raw = response.read()
            return Response(
                response.status,
                json.loads(raw or b"{}"),
                {key.lower(): value for key, value in response.headers.items()},
            )
    except urllib.error.HTTPError as error:
        raw = error.read()
        try:
            body = json.loads(raw or b"{}")
        except json.JSONDecodeError:
            body = {"error": "NON_JSON_RESPONSE"}
        return Response(
            error.code,
            body,
            {key.lower(): value for key, value in error.headers.items()},
        )


def firebase_sign_in(api_key: str, email: str, password: str) -> dict[str, str]:
    response = request_json(
        "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword"
        f"?key={api_key}",
        method="POST",
        payload={
            "email": email,
            "password": password,
            "returnSecureToken": True,
        },
    )
    if response.status != 200:
        message = response.body.get("error", {}).get("message", "SIGN_IN_FAILED")
        raise RuntimeError(f"Firebase sign-in failed for {email}: {message}")
    return {
        "idToken": str(response.body["idToken"]),
        "localId": str(response.body["localId"]),
    }


def firebase_sign_up(api_key: str, email: str, password: str) -> dict[str, str]:
    response = request_json(
        "https://identitytoolkit.googleapis.com/v1/accounts:signUp"
        f"?key={api_key}",
        method="POST",
        payload={
            "email": email,
            "password": password,
            "returnSecureToken": True,
        },
    )
    if response.status != 200:
        message = response.body.get("error", {}).get("message", "SIGN_UP_FAILED")
        raise RuntimeError(f"Firebase temporary account creation failed: {message}")
    return {
        "idToken": str(response.body["idToken"]),
        "localId": str(response.body["localId"]),
        "email": email,
        "password": password,
    }


def firebase_delete_temporary_account(api_key: str, id_token: str) -> Response:
    return request_json(
        "https://identitytoolkit.googleapis.com/v1/accounts:delete"
        f"?key={api_key}",
        method="POST",
        payload={"idToken": id_token},
    )


def create_temporary_student_profile(session: dict[str, str]) -> Response:
    now = datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="milliseconds").replace(
        "+00:00", "Z"
    )
    return request_json(
        "https://firestore.googleapis.com/v1/projects/"
        f"{PROJECT_ID}/databases/(default)/documents/users/{session['localId']}",
        method="PATCH",
        token=session["idToken"],
        payload={
            "fields": {
                "displayName": {"stringValue": "刪除流程測試帳號"},
                "preferredName": {"stringValue": "刪除流程測試帳號"},
                "primaryRole": {"stringValue": "student"},
                "activeClassId": {"nullValue": None},
                "createdAt": {"timestampValue": now},
                "updatedAt": {"timestampValue": now},
                "lastLoginAt": {"timestampValue": now},
                "active": {"booleanValue": True},
                "accountStatus": {"stringValue": "active"},
                "emailVerificationRequired": {"booleanValue": True},
                "provisioningSource": {"stringValue": "selfServiceStudent"},
                "identityProviders": {
                    "arrayValue": {"values": [{"stringValue": "emailPassword"}]}
                },
            }
        },
    )


def personal_scope_id(uid: str) -> str:
    compact = re.sub(r"[^A-Za-z0-9]+", "-", uid.upper()).strip("-")[:48]
    return f"PERSONAL-{compact}"


def expect(
    condition: bool,
    name: str,
    results: list[dict[str, str]],
    detail: str,
) -> None:
    results.append(
        {
            "name": name,
            "status": "passed" if condition else "failed",
            "detail": detail,
        }
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--plist", required=True, type=Path)
    parser.add_argument(
        "--exercise-account-deletion",
        action="store_true",
        help="Create and permanently delete one disposable Firebase account.",
    )
    parser.add_argument(
        "--account-preview-only",
        choices=tuple(TEST_ACCOUNTS),
        help="Run only one authenticated account-deletion preview for diagnosis.",
    )
    args = parser.parse_args()
    config = plistlib.loads(args.plist.read_bytes())
    api_key = config.get("API_KEY")
    if not isinstance(api_key, str) or not api_key:
        raise SystemExit("Firebase API_KEY is missing from the supplied plist.")

    if args.account_preview_only:
        email, password = TEST_ACCOUNTS[args.account_preview_only]
        session = firebase_sign_in(api_key, email, password)
        response = request_json(
            f"{WORKER_BASE_URL}/account/deletion-preview",
            token=session["idToken"],
        )
        print(json.dumps({
            "role": args.account_preview_only,
            "status": response.status,
            "body": response.body,
        }, ensure_ascii=False, indent=2))
        return 0 if response.status == 200 else 1

    results: list[dict[str, str]] = []
    health = request_json(f"{WORKER_BASE_URL}/health")
    expect(
        health.status == 200
        and health.body.get("ok") is True
        and health.body.get("quotaMode") == "internal"
        and health.body.get("aiGatewayReady") is True,
        "worker_health",
        results,
        (
            f"HTTP {health.status}; quotaMode={health.body.get('quotaMode')}; "
            f"aiGatewayReady={health.body.get('aiGatewayReady')}"
        ),
    )

    unauthenticated_ai = request_json(
        f"{WORKER_BASE_URL}/ai",
        method="POST",
        payload={"taskType": "dailyMission"},
    )
    expect(
        unauthenticated_ai.status == 401
        and unauthenticated_ai.body.get("error") == "AUTH_REQUIRED",
        "ai_requires_firebase_auth",
        results,
        f"HTTP {unauthenticated_ai.status}",
    )

    unauthenticated_classrooms = request_json(f"{WORKER_BASE_URL}/classrooms")
    expect(
        unauthenticated_classrooms.status == 401
        and unauthenticated_classrooms.body.get("error") == "AUTH_REQUIRED",
        "classroom_list_requires_firebase_auth",
        results,
        f"HTTP {unauthenticated_classrooms.status}",
    )

    unauthenticated_volunteer_services = request_json(
        f"{WORKER_BASE_URL}/volunteer-services"
    )
    expect(
        unauthenticated_volunteer_services.status == 401
        and unauthenticated_volunteer_services.body.get("error") == "AUTH_REQUIRED",
        "volunteer_service_list_requires_firebase_auth",
        results,
        f"HTTP {unauthenticated_volunteer_services.status}",
    )

    unauthenticated_quota = request_json(f"{WORKER_BASE_URL}/ai/quota")
    expect(
        unauthenticated_quota.status == 401
        and unauthenticated_quota.body.get("error") == "AUTH_REQUIRED",
        "ai_quota_requires_firebase_auth",
        results,
        f"HTTP {unauthenticated_quota.status}",
    )

    unauthenticated_evidence = request_json(
        f"{WORKER_BASE_URL}/evidence/upload-ticket",
        method="POST",
        payload={},
    )
    expect(
        unauthenticated_evidence.status == 401
        and unauthenticated_evidence.body.get("error") == "AUTH_REQUIRED",
        "evidence_binding_and_secret_require_auth",
        results,
        f"HTTP {unauthenticated_evidence.status}",
    )

    unauthenticated_deletion_preview = request_json(
        f"{WORKER_BASE_URL}/account/deletion-preview"
    )
    expect(
        unauthenticated_deletion_preview.status == 401
        and unauthenticated_deletion_preview.body.get("error") == "AUTH_REQUIRED",
        "account_deletion_preview_requires_firebase_auth",
        results,
        f"HTTP {unauthenticated_deletion_preview.status}",
    )

    unauthenticated_deletion = request_json(
        f"{WORKER_BASE_URL}/account",
        method="DELETE",
        payload={"confirmation": "DELETE", "policyVersion": "2026-07-13"},
    )
    expect(
        unauthenticated_deletion.status == 401
        and unauthenticated_deletion.body.get("error") == "AUTH_REQUIRED",
        "account_deletion_requires_firebase_auth",
        results,
        f"HTTP {unauthenticated_deletion.status}",
    )

    sessions: dict[str, dict[str, str]] = {}
    for role, (email, password) in TEST_ACCOUNTS.items():
        try:
            sessions[role] = firebase_sign_in(api_key, email, password)
            expect(True, f"firebase_{role}_sign_in", results, "ID token issued")
        except RuntimeError as error:
            expect(False, f"firebase_{role}_sign_in", results, str(error))

    student = sessions.get("student")
    teacher = sessions.get("teacher")
    volunteer = sessions.get("volunteer")

    classroom_lists: dict[str, list[dict]] = {}
    for role, session in sessions.items():
        bootstrap = request_json(
            f"{WORKER_BASE_URL}/classrooms/bootstrap",
            method="POST",
            token=session["idToken"],
            payload={},
        )
        expect(
            bootstrap.status == 200
            and isinstance(bootstrap.body.get("migrated"), bool),
            f"authenticated_{role}_classroom_bootstrap",
            results,
            f"HTTP {bootstrap.status}; migrated={bootstrap.body.get('migrated')}",
        )
        classroom_list = request_json(
            f"{WORKER_BASE_URL}/classrooms",
            token=session["idToken"],
        )
        expect(
            classroom_list.status == 200
            and isinstance(classroom_list.body.get("classrooms"), list),
            f"authenticated_{role}_classroom_list",
            results,
            f"HTTP {classroom_list.status}",
        )
        classroom_lists[role] = classroom_list.body.get("classrooms", [])

        deletion_preview = request_json(
            f"{WORKER_BASE_URL}/account/deletion-preview",
            token=session["idToken"],
        )
        expect(
            deletion_preview.status == 200
            and deletion_preview.body.get("preview", {}).get("removesIdentifiableData") is True
            and deletion_preview.body.get("preview", {}).get("retainsAnonymousAggregateOnly") is True,
            f"authenticated_{role}_account_deletion_preview",
            results,
            (
                f"HTTP {deletion_preview.status}; "
                f"error={deletion_preview.body.get('error', 'none')}"
            ),
        )

    if student:
        forbidden_volunteer_services = request_json(
            f"{WORKER_BASE_URL}/volunteer-services",
            token=student["idToken"],
        )
        expect(
            forbidden_volunteer_services.status == 403
            and forbidden_volunteer_services.body.get("error")
            == "VOLUNTEER_APPROVAL_REQUIRED",
            "student_cannot_list_volunteer_services",
            results,
            f"HTTP {forbidden_volunteer_services.status}",
        )

        quota_before = request_json(
            f"{WORKER_BASE_URL}/ai/quota",
            token=student["idToken"],
        )
        expect(
            quota_before.status == 200
            and quota_before.body.get("mode") == "internal"
            and quota_before.body.get("dailyUnitLimit") == 180
            and isinstance(quota_before.body.get("remainingUnits"), int),
            "authenticated_ai_quota_status",
            results,
            (
                f"HTTP {quota_before.status}; mode={quota_before.body.get('mode')}; "
                f"remaining={quota_before.body.get('remainingUnits')}"
            ),
        )

        forbidden_teacher_task = request_json(
            f"{WORKER_BASE_URL}/ai",
            method="POST",
            token=student["idToken"],
            payload={
                "taskType": "teacherFeedbackDraft",
                "classId": "YILAN-CHENGZHI-8A",
                "studentUid": student["localId"],
                "qualityMode": "quality",
                "locale": "zh-TW",
                "context": {"supportThreadId": "not-a-real-thread"},
            },
        )
        expect(
            forbidden_teacher_task.status == 403
            and forbidden_teacher_task.body.get("error") == "AI_TASK_ROLE_FORBIDDEN",
            "student_cannot_invoke_teacher_ai",
            results,
            f"HTTP {forbidden_teacher_task.status}",
        )

        forged_student = request_json(
            f"{WORKER_BASE_URL}/ai",
            method="POST",
            token=student["idToken"],
            payload={
                "taskType": "dailyMission",
                "classId": "YILAN-CHENGZHI-8A",
                "studentUid": "another-student-uid",
                "qualityMode": "free",
                "locale": "zh-TW",
                "context": {"moodScore": 3, "availableTimeLevel": 2},
            },
        )
        expect(
            forged_student.status == 403
            and forged_student.body.get("error") == "AI_STUDENT_IDENTITY_MISMATCH",
            "student_cannot_forge_ai_identity",
            results,
            f"HTTP {forged_student.status}",
        )

        forbidden_create = request_json(
            f"{WORKER_BASE_URL}/classrooms",
            method="POST",
            token=student["idToken"],
            payload={"name": "Smoke Test Class"},
        )
        expect(
            forbidden_create.status == 403
            and forbidden_create.body.get("error") == "TEACHER_ACCOUNT_REQUIRED",
            "student_cannot_create_classroom",
            results,
            f"HTTP {forbidden_create.status}",
        )

        forbidden_reset = request_json(
            f"{WORKER_BASE_URL}/classrooms/YILAN-CHENGZHI-8A/reset-code",
            method="POST",
            token=student["idToken"],
            payload={},
        )
        expect(
            forbidden_reset.status == 403
            and forbidden_reset.body.get("error") == "TEACHER_ACCOUNT_REQUIRED",
            "student_cannot_reset_classroom_code",
            results,
            f"HTTP {forbidden_reset.status}",
        )

    if teacher:
        forbidden_student_ai = request_json(
            f"{WORKER_BASE_URL}/ai",
            method="POST",
            token=teacher["idToken"],
            payload={
                "taskType": "dailyMission",
                "classId": "YILAN-CHENGZHI-8A",
                "studentUid": teacher["localId"],
                "qualityMode": "free",
                "locale": "zh-TW",
                "context": {"moodScore": 3, "availableTimeLevel": 2},
            },
        )
        expect(
            forbidden_student_ai.status == 403
            and forbidden_student_ai.body.get("error") == "AI_TASK_ROLE_FORBIDDEN",
            "teacher_cannot_invoke_student_ai",
            results,
            f"HTTP {forbidden_student_ai.status}",
        )

        forbidden_join = request_json(
            f"{WORKER_BASE_URL}/classrooms/join",
            method="POST",
            token=teacher["idToken"],
            payload={"code": "ABCDEFGH"},
        )
        expect(
            forbidden_join.status == 403
            and forbidden_join.body.get("error") == "STUDENT_ACCOUNT_REQUIRED",
            "teacher_cannot_join_with_student_code",
            results,
            f"HTTP {forbidden_join.status}",
        )

        teacher_classes = classroom_lists.get("teacher", [])
        if teacher_classes:
            teacher_class_id = teacher_classes[0].get("classId")
            roster = request_json(
                f"{WORKER_BASE_URL}/classrooms/{teacher_class_id}/students",
                token=teacher["idToken"],
            )
            expect(
                roster.status == 200 and isinstance(roster.body.get("students"), list),
                "teacher_can_list_owned_class_roster",
                results,
                f"HTTP {roster.status}; students={len(roster.body.get('students', []))}",
            )
            if student:
                forbidden_roster = request_json(
                    f"{WORKER_BASE_URL}/classrooms/{teacher_class_id}/students",
                    token=student["idToken"],
                )
                expect(
                    forbidden_roster.status == 403,
                    "student_cannot_list_teacher_roster",
                    results,
                    f"HTTP {forbidden_roster.status}",
                )

        missing_class_update = request_json(
            f"{WORKER_BASE_URL}/classrooms/CLS-NOT-FOUND",
            method="PATCH",
            token=teacher["idToken"],
            payload={"name": "No mutation smoke test"},
        )
        expect(
            missing_class_update.status == 404,
            "teacher_class_update_checks_ownership_before_write",
            results,
            f"HTTP {missing_class_update.status}",
        )

    if student:
        ai = request_json(
            f"{WORKER_BASE_URL}/ai",
            method="POST",
            token=student["idToken"],
            payload={
                "taskType": "dailyMission",
                "classId": "YILAN-CHENGZHI-8A",
                "studentUid": student["localId"],
                "sessionId": "deployment-smoke-test",
                "qualityMode": "free",
                "locale": "zh-TW",
                "context": {
                    "moodScore": 3,
                    "availableTimeLevel": 3,
                    "wantsChallenge": True,
                    "preferredQuestionTypes": ["fillBlank", "cloze"],
                },
            },
        )
        result = ai.body.get("result", {})
        expect(
            ai.status == 200
            and result.get("taskType") == "dailyMission"
            and result.get("fallbackUsed") is False,
            "authenticated_real_ai",
            results,
            f"HTTP {ai.status}; fallbackUsed={result.get('fallbackUsed')}",
        )

        practice_ai = request_json(
            f"{WORKER_BASE_URL}/ai",
            method="POST",
            token=student["idToken"],
            payload={
                "taskType": "progressSummary",
                "classId": personal_scope_id(student["localId"]),
                "studentUid": student["localId"],
                "sessionId": "round10-practice-plan-smoke",
                "qualityMode": "free",
                "locale": "zh-TW",
                "context": {
                    "recentAccuracy": 0.62,
                    "recentWeakSkills": ["be 動詞", "文意推論"],
                    "preferredQuestionTypes": ["multipleChoice", "cloze"],
                    "supportReason": "practiceRecommendation",
                },
            },
        )
        practice_result = practice_ai.body.get("result", {})
        practice_plan = practice_result.get("output", {}).get("practicePlan", {})
        practice_items = practice_plan.get("questionPlan", [])
        planned_count = sum(
            int(item.get("targetCorrect", 0))
            for item in practice_items
            if isinstance(item, dict)
        )
        expect(
            practice_ai.status == 200
            and practice_result.get("taskType") == "progressSummary"
            and practice_result.get("fallbackUsed") is False
            and 6 <= practice_plan.get("targetQuestionCount", 0) <= 10
            and planned_count == practice_plan.get("targetQuestionCount")
            and len(practice_items) >= 1,
            "authenticated_ai_returns_executable_practice_plan",
            results,
            (
                f"HTTP {practice_ai.status}; fallbackUsed={practice_result.get('fallbackUsed')}; "
                f"target={practice_plan.get('targetQuestionCount')}; planned={planned_count}"
            ),
        )

        wrong_answer_ai = request_json(
            f"{WORKER_BASE_URL}/ai",
            method="POST",
            token=student["idToken"],
            payload={
                "taskType": "wrongAnswerExplanation",
                "classId": personal_scope_id(student["localId"]),
                "studentUid": student["localId"],
                "sessionId": "round10-wrong-answer-smoke",
                "qualityMode": "free",
                "locale": "zh-TW",
                "context": {
                    "questionType": "multipleChoice",
                    "questionPrompt": "Amy and Ben ___ ready for class.",
                    "studentAnswer": "is",
                    "correctAnswer": "are",
                    "explanation": "複數主詞要搭配 are。",
                    "attemptCount": 1,
                },
            },
        )
        wrong_answer_result = wrong_answer_ai.body.get("result", {})
        wrong_answer_output = wrong_answer_result.get("output", {})
        expect(
            wrong_answer_ai.status == 200
            and wrong_answer_result.get("taskType") == "wrongAnswerExplanation"
            and wrong_answer_result.get("fallbackUsed") is False
            and bool(wrong_answer_output.get("whyWrong"))
            and bool(wrong_answer_output.get("nextHint"))
            and wrong_answer_output.get("tryAgain") is True,
            "authenticated_ai_returns_actionable_wrong_answer_repair",
            results,
            (
                f"HTTP {wrong_answer_ai.status}; fallbackUsed={wrong_answer_result.get('fallbackUsed')}; "
                f"tryAgain={wrong_answer_output.get('tryAgain')}"
            ),
        )

        replay_request_id = f"smoke-{uuid.uuid4()}"
        personal_ai_payload = {
            "taskType": "dailyMission",
            "classId": personal_scope_id(student["localId"]),
            "studentUid": student["localId"],
            "sessionId": "personal-mode-deployment-smoke-test",
            "qualityMode": "quality",
            "locale": "zh-TW",
            "context": {
                "moodScore": 3,
                "availableTimeLevel": 2,
                "wantsChallenge": False,
                "preferredQuestionTypes": ["vocabulary", "fillBlank"],
            },
        }
        personal_ai = request_json(
            f"{WORKER_BASE_URL}/ai",
            method="POST",
            token=student["idToken"],
            payload=personal_ai_payload,
            request_id=replay_request_id,
        )
        personal_result = personal_ai.body.get("result", {})
        expect(
            personal_ai.status == 200
            and personal_result.get("taskType") == "dailyMission"
            and personal_result.get("qualityMode") == "free"
            and personal_result.get("fallbackUsed") is False,
            "authenticated_personal_ai_blocks_client_quality_escalation",
            results,
            (
                f"HTTP {personal_ai.status}; "
                f"qualityMode={personal_result.get('qualityMode')}; "
                f"fallbackUsed={personal_result.get('fallbackUsed')}"
            ),
        )

        request_id = personal_ai.headers.get("x-englishplus-request-id", "")
        expect(
            request_id == personal_result.get("requestId")
            and len(request_id) >= 8,
            "ai_request_id_is_correlated",
            results,
            f"requestId={request_id or 'missing'}",
        )

        replayed_ai = request_json(
            f"{WORKER_BASE_URL}/ai",
            method="POST",
            token=student["idToken"],
            payload=personal_ai_payload,
            request_id=replay_request_id,
        )
        expect(
            replayed_ai.status == 409
            and replayed_ai.body.get("error") == "AI_REQUEST_ID_REUSED",
            "ai_request_id_replay_is_rejected",
            results,
            f"HTTP {replayed_ai.status}",
        )

        student_evidence = request_json(
            f"{WORKER_BASE_URL}/evidence/upload-ticket",
            method="POST",
            token=student["idToken"],
            payload={
                "filename": "not-allowed.pdf",
                "mimeType": "application/pdf",
                "sizeBytes": 128,
                "qualificationKind": "other",
            },
        )
        expect(
            student_evidence.status == 403,
            "student_cannot_upload_volunteer_evidence",
            results,
            f"HTTP {student_evidence.status}",
        )

        own_profile = request_json(
            "https://firestore.googleapis.com/v1/projects/"
            f"{PROJECT_ID}/databases/(default)/documents/users/{student['localId']}",
            token=student["idToken"],
        )
        expect(
            own_profile.status in (200, 404),
            "firestore_self_profile_read",
            results,
            (
                "profile document readable"
                if own_profile.status == 200
                else "read allowed; demo profile document not created"
            ),
        )

    if student and teacher:
        cross_profile = request_json(
            "https://firestore.googleapis.com/v1/projects/"
            f"{PROJECT_ID}/databases/(default)/documents/users/{teacher['localId']}",
            token=student["idToken"],
        )
        expect(
            cross_profile.status == 403,
            "firestore_blocks_cross_user_profile_read",
            results,
            f"HTTP {cross_profile.status}",
        )

        admin_list = request_json(
            f"{WORKER_BASE_URL}/admin/volunteer-applications",
            token=teacher["idToken"],
        )
        expect(
            admin_list.status in (200, 403),
            "admin_endpoint_enforces_claim",
            results,
            "admin claim active" if admin_list.status == 200 else "ordinary teacher rejected",
        )

        admin_session = request_json(
            f"{WORKER_BASE_URL}/admin/session",
            token=teacher["idToken"],
        )
        expect(
            admin_session.status == 403
            and admin_session.body.get("error") == "ADMIN_REQUIRED",
            "admin_session_rejects_ordinary_teacher",
            results,
            f"HTTP {admin_session.status}",
        )

    if volunteer:
        volunteer_services = request_json(
            f"{WORKER_BASE_URL}/volunteer-services",
            token=volunteer["idToken"],
        )
        expect(
            volunteer_services.status == 200
            and isinstance(volunteer_services.body.get("services"), list),
            "approved_volunteer_can_list_service_classes",
            results,
            (
                f"HTTP {volunteer_services.status}; "
                f"services={len(volunteer_services.body.get('services', []))}"
            ),
        )

        forbidden_student_ai = request_json(
            f"{WORKER_BASE_URL}/ai",
            method="POST",
            token=volunteer["idToken"],
            payload={
                "taskType": "dailyMission",
                "classId": "YILAN-CHENGZHI-8A",
                "studentUid": volunteer["localId"],
                "qualityMode": "free",
                "locale": "zh-TW",
                "context": {"moodScore": 3, "availableTimeLevel": 2},
            },
        )
        expect(
            forbidden_student_ai.status == 403
            and forbidden_student_ai.body.get("error") == "AI_TASK_ROLE_FORBIDDEN",
            "volunteer_cannot_invoke_student_ai",
            results,
            f"HTTP {forbidden_student_ai.status}",
        )

        volunteer_ticket = request_json(
            f"{WORKER_BASE_URL}/evidence/upload-ticket",
            method="POST",
            token=volunteer["idToken"],
            payload={
                "filename": "status-check.pdf",
                "mimeType": "application/pdf",
                "sizeBytes": 128,
                "qualificationKind": "other",
            },
        )
        expect(
            volunteer_ticket.status in (200, 403),
            "volunteer_upload_state_gate",
            results,
            f"HTTP {volunteer_ticket.status}",
        )
        if volunteer_ticket.status == 200:
            object_key = volunteer_ticket.body.get("objectKey")
            cleanup = request_json(
                f"{WORKER_BASE_URL}/evidence/object",
                method="DELETE",
                token=volunteer["idToken"],
                payload={"objectKey": object_key},
            )
            expect(
                isinstance(object_key, str) and cleanup.status == 200,
                "volunteer_ticket_reservation_cleanup",
                results,
                f"HTTP {cleanup.status}",
            )

    if args.exercise_account_deletion:
        suffix = uuid.uuid4().hex
        temporary = firebase_sign_up(
            api_key,
            f"account-delete-{suffix}@englishplus.test",
            f"EnglishPlus-{suffix}!A1",
        )
        profile_create = create_temporary_student_profile(temporary)
        expect(
            profile_create.status == 200,
            "temporary_deletion_account_profile_created",
            results,
            f"HTTP {profile_create.status}",
        )

        deletion_preview = request_json(
            f"{WORKER_BASE_URL}/account/deletion-preview",
            token=temporary["idToken"],
        )
        expect(
            deletion_preview.status == 200
            and deletion_preview.body.get("preview", {}).get("classMembershipCount") == 0,
            "temporary_account_deletion_preview",
            results,
            f"HTTP {deletion_preview.status}",
        )

        deletion_attempts = 0
        while deletion_attempts < 120:
            deletion_attempts += 1
            deletion = request_json(
                f"{WORKER_BASE_URL}/account",
                method="DELETE",
                token=temporary["idToken"],
                payload={"confirmation": "DELETE", "policyVersion": "2026-07-13"},
            )
            if deletion.status != 202:
                break
            time.sleep(0.25)
        expect(
            deletion.status == 200
            and deletion.body.get("result", {}).get("completed") is True
            and deletion.body.get("result", {}).get("retainedData") == "anonymousAggregateOnly",
            "temporary_account_deleted_across_worker_and_firebase_auth",
            results,
            (
                f"HTTP {deletion.status}; attempts={deletion_attempts}; "
                f"result={deletion.body.get('result')}"
            ),
        )
        if deletion.status != 200 or deletion.body.get("result", {}).get("completed") is not True:
            emergency_cleanup = firebase_delete_temporary_account(
                api_key,
                temporary["idToken"],
            )
            expect(
                emergency_cleanup.status == 200,
                "failed_deletion_test_account_is_still_cleaned_up",
                results,
                f"HTTP {emergency_cleanup.status}",
            )

        sign_in_after_delete = request_json(
            "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword"
            f"?key={api_key}",
            method="POST",
            payload={
                "email": temporary["email"],
                "password": temporary["password"],
                "returnSecureToken": True,
            },
        )
        expect(
            sign_in_after_delete.status == 400,
            "deleted_account_cannot_sign_in_again",
            results,
            f"HTTP {sign_in_after_delete.status}",
        )

        deleted_profile = request_json(
            "https://firestore.googleapis.com/v1/projects/"
            f"{PROJECT_ID}/databases/(default)/documents/users/{temporary['localId']}",
            token=temporary["idToken"],
        )
        expect(
            deleted_profile.status == 404,
            "deleted_account_profile_is_absent",
            results,
            f"HTTP {deleted_profile.status}",
        )

    print(json.dumps({"tests": results}, ensure_ascii=True, indent=2))
    return 1 if any(item["status"] == "failed" for item in results) else 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, RuntimeError) as error:
        print(json.dumps({"fatal": str(error)}, ensure_ascii=True))
        raise SystemExit(1)
