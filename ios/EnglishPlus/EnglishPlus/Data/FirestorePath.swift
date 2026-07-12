import Foundation

enum FirestorePath {
    static let appConfigPublic = "appConfig/public"

    static func educationInstitution(institutionId: String) -> String {
        "educationInstitutions/\(segment(institutionId))"
    }

    static func teacherProfile(uid: String) -> String {
        "teacherProfiles/\(segment(uid))"
    }

    static func volunteerApplication(uid: String) -> String {
        "volunteerApplications/\(segment(uid))"
    }

    static func staffInvitation(invitationId: String) -> String {
        "staffInvitations/\(segment(invitationId))"
    }

    static func user(uid: String) -> String {
        "users/\(segment(uid))"
    }

    static func userConsent(uid: String, consentVersion: String) -> String {
        "\(user(uid: uid))/consents/\(segment(consentVersion))"
    }

    static func userMemberships(uid: String) -> String {
        "\(user(uid: uid))/classMemberships"
    }

    static func userMembership(uid: String, classId: String) -> String {
        "\(userMemberships(uid: uid))/\(segment(classId))"
    }

    static func userLearningSettings(uid: String) -> String {
        "\(user(uid: uid))/settings/learning"
    }

    static func personalCheckIn(uid: String, dateKey: String) -> String {
        "\(user(uid: uid))/personalCheckIns/\(segment(dateKey))"
    }

    static func personalDailyMission(uid: String, missionId: String) -> String {
        "\(user(uid: uid))/personalDailyMissions/\(segment(missionId))"
    }

    static func personalAnswerEvent(uid: String, eventId: String) -> String {
        "\(user(uid: uid))/personalAnswerEvents/\(segment(eventId))"
    }

    static func personalLearningEvent(uid: String, eventId: String) -> String {
        "\(user(uid: uid))/personalLearningEvents/\(segment(eventId))"
    }

    static func classDocument(classId: String) -> String {
        "classes/\(segment(classId))"
    }

    static func member(classId: String, uid: String) -> String {
        "\(classDocument(classId: classId))/members/\(segment(uid))"
    }

    static func student(classId: String, studentUid: String) -> String {
        "\(classDocument(classId: classId))/students/\(segment(studentUid))"
    }

    static func checkIn(classId: String, studentUid: String, dateKey: String) -> String {
        "\(student(classId: classId, studentUid: studentUid))/checkIns/\(segment(dateKey))"
    }

    static func studentConsent(classId: String, studentUid: String, consentVersion: String) -> String {
        "\(student(classId: classId, studentUid: studentUid))/consents/\(segment(consentVersion))"
    }

    static func deletionRequest(classId: String, studentUid: String, requestId: String) -> String {
        "\(student(classId: classId, studentUid: studentUid))/deletionRequests/\(segment(requestId))"
    }

    static func dailyMission(classId: String, studentUid: String, missionId: String) -> String {
        "\(student(classId: classId, studentUid: studentUid))/dailyMissions/\(segment(missionId))"
    }

    static func answerEvent(classId: String, studentUid: String, eventId: String) -> String {
        "\(student(classId: classId, studentUid: studentUid))/answerEvents/\(segment(eventId))"
    }

    static func learningEvent(classId: String, studentUid: String, eventId: String) -> String {
        "\(student(classId: classId, studentUid: studentUid))/learningEvents/\(segment(eventId))"
    }

    static func supportThread(classId: String, threadId: String) -> String {
        "\(classDocument(classId: classId))/supportThreads/\(segment(threadId))"
    }

    static func supportMessage(classId: String, threadId: String, messageId: String) -> String {
        "\(supportThread(classId: classId, threadId: threadId))/messages/\(segment(messageId))"
    }

    static func staffAssignment(classId: String, assignmentId: String) -> String {
        "\(classDocument(classId: classId))/staffAssignments/\(segment(assignmentId))"
    }

    static func practiceAssignment(classId: String, assignmentId: String) -> String {
        "\(classDocument(classId: classId))/practiceAssignments/\(segment(assignmentId))"
    }

    static func questionBankItem(classId: String, questionId: String) -> String {
        "\(classDocument(classId: classId))/questionBank/\(segment(questionId))"
    }

    static func report(classId: String, reportId: String) -> String {
        "\(classDocument(classId: classId))/reports/\(segment(reportId))"
    }

    static func aiUsage(classId: String, dateKey: String, uid: String) -> String {
        "\(classDocument(classId: classId))/aiUsage/\(segment(dateKey))_\(segment(uid))"
    }

    static func aiEvent(classId: String, eventId: String) -> String {
        "\(classDocument(classId: classId))/aiEvents/\(segment(eventId))"
    }

    static func privacyAuditLog(classId: String, eventId: String) -> String {
        "\(classDocument(classId: classId))/privacyAuditLogs/\(segment(eventId))"
    }

    static func syncQueueItem(classId: String, syncItemId: String) -> String {
        "\(classDocument(classId: classId))/syncQueue/\(segment(syncItemId))"
    }

    private static func segment(_ value: String) -> String {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
        return cleaned.isEmpty ? "missing" : cleaned
    }
}
