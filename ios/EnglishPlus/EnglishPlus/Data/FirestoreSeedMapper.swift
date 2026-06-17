import Foundation

struct FirestoreSeedWritePlan: Identifiable, Equatable {
    let id: String
    let path: String
    let documentKind: String
}

struct FirestoreSeedExport: Equatable {
    let writePlan: [FirestoreSeedWritePlan]
    let users: [String: FirestoreUserDocument]
    let members: [String: FirestoreMemberDocument]
    let students: [String: FirestoreStudentDocument]
    let questionBankItems: [String: FirestoreQuestionBankDocument]
}

struct FirestoreSeedMapper {
    let generatedAt: Date

    init(generatedAt: Date = Date()) {
        self.generatedAt = generatedAt
    }

    func makeExport(from snapshot: SeedDataSnapshot = SeedData.current) -> FirestoreSeedExport {
        var writePlan: [FirestoreSeedWritePlan] = []
        var users: [String: FirestoreUserDocument] = [:]
        var members: [String: FirestoreMemberDocument] = [:]
        var students: [String: FirestoreStudentDocument] = [:]
        var questionBankItems: [String: FirestoreQuestionBankDocument] = [:]

        for account in snapshot.accounts {
            let uid = account.id
            let classId = account.classId

            users[uid] = FirestoreUserDocument(
                displayName: account.displayName,
                preferredName: account.displayName,
                primaryRole: account.role,
                createdAt: account.createdAt,
                lastLoginAt: generatedAt,
                active: true
            )
            writePlan.append(.init(
                id: FirestorePath.user(uid: uid),
                path: FirestorePath.user(uid: uid),
                documentKind: "user"
            ))

            let memberPath = FirestorePath.member(classId: classId, uid: uid)
            members[memberPath] = FirestoreMemberDocument(
                uid: uid,
                role: account.role,
                displayName: account.displayName,
                active: true,
                joinedAt: account.createdAt
            )
            writePlan.append(.init(id: memberPath, path: memberPath, documentKind: "member"))

            if account.role == .student {
                let studentPath = FirestorePath.student(classId: classId, studentUid: uid)
                students[studentPath] = FirestoreStudentDocument(
                    uid: uid,
                    displayName: account.displayName,
                    gradeBand: "junior-high",
                    classCode: classId,
                    currentLevel: "foundation",
                    recommendedTrack: .repair,
                    lastMoodScore: nil,
                    lastMissionStatus: .active,
                    lastActivityAt: nil,
                    riskLevel: .low,
                    legacyAndroidId: account.id
                )
                writePlan.append(.init(id: studentPath, path: studentPath, documentKind: "student"))
            }
        }

        for item in snapshot.questionBankItems {
            let path = FirestorePath.questionBankItem(
                classId: FirebaseBackendConfig.firstClassId,
                questionId: item.id
            )
            questionBankItems[path] = FirestoreQuestionBankDocument(
                questionId: item.id,
                level: item.level,
                type: item.question.type,
                skillTags: [item.unit, item.skill],
                prompt: item.question.prompt,
                choices: item.question.options,
                answer: item.question.answer,
                acceptedAnswers: item.question.acceptedAnswers,
                explanation: item.question.explanation,
                repairHint: item.question.repairHint,
                reviewState: item.reviewState,
                source: FirestoreQuestionSource(
                    kind: "internal-seed",
                    note: item.source
                ),
                updatedAt: item.updatedAt
            )
            writePlan.append(.init(id: path, path: path, documentKind: "questionBankItem"))
        }

        return FirestoreSeedExport(
            writePlan: writePlan,
            users: users,
            members: members,
            students: students,
            questionBankItems: questionBankItems
        )
    }
}
