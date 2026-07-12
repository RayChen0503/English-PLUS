#!/usr/bin/env python3
import argparse
import json
import plistlib
import re
import sys
import urllib.error
import urllib.request
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


def request_json(
    url: str,
    method: str = "GET",
    payload: dict[str, Any] | None = None,
    token: str | None = None,
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
    request = urllib.request.Request(
        url,
        data=data,
        headers=headers,
        method=method,
    )
    try:
        with urllib.request.urlopen(request, timeout=40) as response:
            raw = response.read()
            return Response(response.status, json.loads(raw or b"{}"))
    except urllib.error.HTTPError as error:
        raw = error.read()
        try:
            body = json.loads(raw or b"{}")
        except json.JSONDecodeError:
            body = {"error": "NON_JSON_RESPONSE"}
        return Response(error.code, body)


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
    args = parser.parse_args()
    config = plistlib.loads(args.plist.read_bytes())
    api_key = config.get("API_KEY")
    if not isinstance(api_key, str) or not api_key:
        raise SystemExit("Firebase API_KEY is missing from the supplied plist.")

    results: list[dict[str, str]] = []
    health = request_json(f"{WORKER_BASE_URL}/health")
    expect(
        health.status == 200 and health.body.get("ok") is True,
        "worker_health",
        results,
        f"HTTP {health.status}",
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

        personal_ai = request_json(
            f"{WORKER_BASE_URL}/ai",
            method="POST",
            token=student["idToken"],
            payload={
                "taskType": "dailyMission",
                "classId": personal_scope_id(student["localId"]),
                "studentUid": student["localId"],
                "sessionId": "personal-mode-deployment-smoke-test",
                "qualityMode": "free",
                "locale": "zh-TW",
                "context": {
                    "moodScore": 3,
                    "availableTimeLevel": 2,
                    "wantsChallenge": False,
                    "preferredQuestionTypes": ["vocabulary", "fillBlank"],
                },
            },
        )
        personal_result = personal_ai.body.get("result", {})
        expect(
            personal_ai.status == 200
            and personal_result.get("taskType") == "dailyMission"
            and personal_result.get("fallbackUsed") is False,
            "authenticated_personal_mode_real_ai",
            results,
            (
                f"HTTP {personal_ai.status}; "
                f"fallbackUsed={personal_result.get('fallbackUsed')}"
            ),
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

    if volunteer:
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

    print(json.dumps({"tests": results}, ensure_ascii=True, indent=2))
    return 1 if any(item["status"] == "failed" for item in results) else 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, RuntimeError) as error:
        print(json.dumps({"fatal": str(error)}, ensure_ascii=True))
        raise SystemExit(1)
