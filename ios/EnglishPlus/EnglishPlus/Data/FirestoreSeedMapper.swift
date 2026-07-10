import Foundation

struct FirestoreSeedWritePlan: Identifiable, Equatable {
    let id: String
    let path: String
    let documentKind: String
}

struct FirestoreSeedExport: Equatable {
    let writePlan: [FirestoreSeedWritePlan]
    let users: [String: FirestoreUserDocument]
    let userMemberships: [String: FirestoreUserMembershipDocument]
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
        var userMemberships: [String: FirestoreUserMembershipDocument] = [:]
        var members: [String: FirestoreMemberDocument] = [:]
        var students: [String: FirestoreStudentDocument] = [:]
        var questionBankItems: [String: FirestoreQuestionBankDocument] = [:]

        for account in snapshot.accounts {
            let uid = account.id
            users[uid] = FirestoreUserDocument(
                displayName: account.displayName,
                preferredName: account.displayName,
                primaryRole: account.role,
                createdAt: account.createdAt,
                lastLoginAt: generatedAt,
                active: true,
                activeClassId: account.activeClassId
            )
            writePlan.append(.init(
                id: FirestorePath.user(uid: uid),
                path: FirestorePath.user(uid: uid),
                documentKind: "user"
            ))

            for membership in account.memberships {
                let userMembershipPath = FirestorePath.userMembership(
                    uid: uid,
                    classId: membership.classId
                )
                userMemberships[userMembershipPath] = FirestoreUserMembershipDocument(
                    classId: membership.classId,
                    className: membership.className,
                    role: membership.role,
                    groupId: membership.groupId,
                    status: membership.status,
                    joinedAt: membership.joinedAt,
                    visibilityStartsAt: membership.visibilityStartsAt,
                    leftAt: membership.leftAt
                )
                writePlan.append(.init(
                    id: userMembershipPath,
                    path: userMembershipPath,
                    documentKind: "userMembership"
                ))

                let memberPath = FirestorePath.member(classId: membership.classId, uid: uid)
                members[memberPath] = FirestoreMemberDocument(
                    uid: uid,
                    classId: membership.classId,
                    role: membership.role,
                    displayName: account.displayName,
                    status: membership.status,
                    joinedAt: membership.joinedAt,
                    visibilityStartsAt: membership.visibilityStartsAt,
                    leftAt: membership.leftAt
                )
                writePlan.append(.init(id: memberPath, path: memberPath, documentKind: "member"))

                if membership.role == .student {
                    let studentPath = FirestorePath.student(
                        classId: membership.classId,
                        studentUid: uid
                    )
                    students[studentPath] = FirestoreStudentDocument(
                        uid: uid,
                        displayName: account.displayName,
                        gradeBand: "junior-high",
                        classCode: membership.classId,
                        currentLevel: "foundation",
                        recommendedTrack: .repair,
                        lastMoodScore: nil,
                        lastMissionStatus: .active,
                        lastActivityAt: nil,
                        riskLevel: .low,
                        legacyAndroidId: account.id
                    )
                    writePlan.append(.init(
                        id: studentPath,
                        path: studentPath,
                        documentKind: "student"
                    ))
                }
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
            userMemberships: userMemberships,
            members: members,
            students: students,
            questionBankItems: questionBankItems
        )
    }
}
