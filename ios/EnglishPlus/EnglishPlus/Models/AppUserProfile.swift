import Foundation

enum ConsentStatus: String, Codable {
    case demo
    case pending
    case granted
    case declined
}

enum ClassMembershipStatus: String, Codable {
    case pending
    case active
    case left
    case suspended
}

struct ClassMembership: Identifiable, Codable, Equatable {
    var id: String { classId }

    let classId: String
    let className: String?
    let role: UserRole
    let groupId: String?
    let status: ClassMembershipStatus
    let joinedAt: Date
    let visibilityStartsAt: Date
    let leftAt: Date?

    var isActive: Bool {
        status == .active && leftAt == nil
    }

    func allowsTeacherAccess(to recordCreatedAt: Date) -> Bool {
        isActive && recordCreatedAt >= visibilityStartsAt
    }
}

enum LearningScope: Equatable {
    case personal(ownerUid: String)
    case classroom(ClassMembership)

    var activeClassId: String? {
        guard case .classroom(let membership) = self else { return nil }
        return membership.classId
    }
}

struct AppUserProfile: Identifiable, Codable, Equatable {
    let id: String
    let displayName: String
    let role: UserRole
    let groupId: String?
    let consentStatus: ConsentStatus
    let isDemo: Bool
    let accountStatus: AccountProvisioningStatus
    let createdAt: Date
    let updatedAt: Date
    let memberships: [ClassMembership]
    let activeClassId: String?

    var activeMembership: ClassMembership? {
        guard let activeClassId else { return nil }
        return memberships.first {
            $0.classId == activeClassId && $0.isActive
        }
    }

    var learningScope: LearningScope {
        if let activeMembership {
            return .classroom(activeMembership)
        }
        return .personal(ownerUid: id)
    }

    var isPersonalMode: Bool {
        activeMembership == nil
    }

    // Transitional compatibility for features that still expect a non-empty
    // scope identifier. Personal data must use FirestorePath.personal* paths.
    var classId: String {
        activeMembership?.classId ?? FirebaseBackendConfig.personalScopeId(uid: id)
    }

    init(
        id: String,
        displayName: String,
        role: UserRole,
        classId: String,
        groupId: String?,
        consentStatus: ConsentStatus,
        isDemo: Bool,
        accountStatus: AccountProvisioningStatus = .active,
        createdAt: Date,
        updatedAt: Date,
        memberships: [ClassMembership]? = nil,
        activeClassId: String? = nil
    ) {
        let normalizedLegacyClassId = classId.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedMemberships: [ClassMembership]
        if let memberships {
            resolvedMemberships = memberships
        } else if !normalizedLegacyClassId.isEmpty,
                  !FirebaseBackendConfig.isPersonalScopeId(normalizedLegacyClassId) {
            resolvedMemberships = [
                ClassMembership(
                    classId: normalizedLegacyClassId,
                    className: nil,
                    role: role,
                    groupId: groupId,
                    status: .active,
                    joinedAt: createdAt,
                    visibilityStartsAt: createdAt,
                    leftAt: nil
                )
            ]
        } else {
            resolvedMemberships = []
        }

        let requestedActiveClassId = activeClassId ?? (
            resolvedMemberships.contains { $0.classId == normalizedLegacyClassId && $0.isActive }
                ? normalizedLegacyClassId
                : nil
        )

        self.id = id
        self.displayName = displayName
        self.role = role
        self.groupId = groupId
        self.consentStatus = consentStatus
        self.isDemo = isDemo
        self.accountStatus = accountStatus
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.memberships = resolvedMemberships
        self.activeClassId = resolvedMemberships.contains {
            $0.classId == requestedActiveClassId && $0.isActive
        } ? requestedActiveClassId : nil
    }

    func selectingClass(_ classId: String?) -> AppUserProfile? {
        if classId == nil {
            return AppUserProfile(
                id: id,
                displayName: displayName,
                role: role,
                classId: FirebaseBackendConfig.personalScopeId(uid: id),
                groupId: nil,
                consentStatus: consentStatus,
                isDemo: isDemo,
                accountStatus: accountStatus,
                createdAt: createdAt,
                updatedAt: Date(),
                memberships: memberships,
                activeClassId: nil
            )
        }

        guard let membership = memberships.first(where: {
            $0.classId == classId && $0.isActive
        }) else {
            return nil
        }

        return AppUserProfile(
            id: id,
            displayName: displayName,
            role: membership.role,
            classId: membership.classId,
            groupId: membership.groupId,
            consentStatus: consentStatus,
            isDemo: isDemo,
            accountStatus: accountStatus,
            createdAt: createdAt,
            updatedAt: Date(),
            memberships: memberships,
            activeClassId: membership.classId
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case role
        case classId
        case groupId
        case consentStatus
        case isDemo
        case accountStatus
        case createdAt
        case updatedAt
        case memberships
        case activeClassId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let role = try container.decode(UserRole.self, forKey: .role)
        let createdAt = try container.decode(Date.self, forKey: .createdAt)
        let legacyClassId = try container.decodeIfPresent(String.self, forKey: .classId)
            ?? FirebaseBackendConfig.personalScopeId(uid: id)

        self.init(
            id: id,
            displayName: try container.decode(String.self, forKey: .displayName),
            role: role,
            classId: legacyClassId,
            groupId: try container.decodeIfPresent(String.self, forKey: .groupId),
            consentStatus: try container.decode(ConsentStatus.self, forKey: .consentStatus),
            isDemo: try container.decode(Bool.self, forKey: .isDemo),
            accountStatus: try container.decodeIfPresent(
                AccountProvisioningStatus.self,
                forKey: .accountStatus
            ) ?? .active,
            createdAt: createdAt,
            updatedAt: try container.decode(Date.self, forKey: .updatedAt),
            memberships: try container.decodeIfPresent([ClassMembership].self, forKey: .memberships),
            activeClassId: try container.decodeIfPresent(String.self, forKey: .activeClassId)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(role, forKey: .role)
        try container.encode(classId, forKey: .classId)
        try container.encodeIfPresent(groupId, forKey: .groupId)
        try container.encode(consentStatus, forKey: .consentStatus)
        try container.encode(isDemo, forKey: .isDemo)
        try container.encode(accountStatus, forKey: .accountStatus)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(memberships, forKey: .memberships)
        try container.encodeIfPresent(activeClassId, forKey: .activeClassId)
    }
}

struct AccountsSeed: SeedLoadable {
    static let seedFileName = "accounts_seed"

    let schemaVersion: Int
    let accounts: [AppUserProfile]
}
