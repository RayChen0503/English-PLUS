import Foundation

enum FirestorePath {
    static let appConfigPublic = "appConfig/public"

    static func user(uid: String) -> String {
        "users/\(segment(uid))"
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

    static func questionBankItem(classId: String, questionId: String) -> String {
        "\(classDocument(classId: classId))/questionBank/\(segment(questionId))"
    }

    static func report(classId: String, reportId: String) -> String {
        "\(classDocument(classId: classId))/reports/\(segment(reportId))"
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
