import Foundation

enum AccountIdentityProvider: String, Codable, CaseIterable {
    case emailPassword
    case google
    case apple
}

extension AccountIdentityProvider {
    var displayName: String {
        switch self {
        case .emailPassword:
            return "Email"
        case .google:
            return "Google"
        case .apple:
            return "Apple"
        }
    }
}

enum AccountProvisioningSource: String, Codable {
    case selfServiceStudent
    case selfServiceTeacher
    case selfServiceVolunteer
    case internalSeed
    case legacyMigration
}

enum EducationInstitutionKind: String, Codable, CaseIterable, Hashable {
    case elementarySchool
    case juniorHighSchool
    case seniorHighSchool
    case combinedSchool
    case experimentalEducationInstitution
    case homeschoolGroup
    case otherEducationOrganization
}

enum InstitutionRecordSource: String, Codable {
    case ministryOfEducation
    case userSubmitted
}

enum InstitutionClaimStatus: String, Codable {
    case selfDeclared
    case verified
    case disputed
}

struct EducationInstitution: Identifiable, Codable, Equatable {
    let id: String
    let officialCode: String?
    let name: String
    let city: String?
    let district: String?
    let kind: EducationInstitutionKind
    let source: InstitutionRecordSource
    let sourceDatasetId: String?
    let sourceAcademicYear: String?
    let isActive: Bool

    var searchableText: String {
        [name, officialCode, city, district]
            .compactMap { $0 }
            .joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

struct EducationInstitutionSearchQuery: Equatable {
    let text: String
    let city: String?
    let kinds: Set<EducationInstitutionKind>

    init(
        text: String,
        city: String? = nil,
        kinds: Set<EducationInstitutionKind> = []
    ) {
        self.text = text
        self.city = city
        self.kinds = kinds
    }
}

struct EducationInstitutionDirectory {
    let institutions: [EducationInstitution]

    func search(
        _ query: EducationInstitutionSearchQuery,
        limit: Int = 10
    ) -> [EducationInstitution] {
        let normalizedText = query.text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        guard normalizedText.count >= 2, limit > 0 else { return [] }

        return institutions
            .lazy
            .filter(\.isActive)
            .filter { institution in
                query.city == nil || institution.city == query.city
            }
            .filter { institution in
                query.kinds.isEmpty || query.kinds.contains(institution.kind)
            }
            .filter { $0.searchableText.localizedStandardContains(normalizedText) }
            .sorted { left, right in
                let leftStartsWithQuery = left.name
                    .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                    .hasPrefix(normalizedText)
                let rightStartsWithQuery = right.name
                    .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                    .hasPrefix(normalizedText)
                if leftStartsWithQuery != rightStartsWithQuery {
                    return leftStartsWithQuery
                }
                if left.source != right.source {
                    return left.source == .ministryOfEducation
                }
                return left.name.localizedStandardCompare(right.name) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
    }
}

struct TeacherAffiliation: Codable, Equatable {
    let institutionId: String
    let institutionName: String
    let institutionKind: EducationInstitutionKind
    let institutionSource: InstitutionRecordSource
    let claimStatus: InstitutionClaimStatus

    var isValidSelfDeclaration: Bool {
        !institutionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !institutionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && claimStatus == .selfDeclared
    }
}

enum VolunteerQualificationKind: String, Codable, CaseIterable, Hashable {
    case universityEnrollment
    case englishProficiency
    case educatorCredential
    case nonprofitOrVolunteerService
    case other
}

enum VolunteerApplicationStatus: String, Codable {
    case draft
    case submitted
    case pendingReview
    case needsMoreInformation
    case approved
    case rejected
    case withdrawn
    case suspended
}

struct VolunteerEvidenceReference: Identifiable, Codable, Equatable {
    let id: String
    let kind: VolunteerQualificationKind
    let storageObjectKey: String
    let originalFilename: String
    let mimeType: String
    let sizeBytes: Int
    let uploadedAt: Date

    var hasUsableReference: Bool {
        !id.isEmpty
            && !storageObjectKey.isEmpty
            && !originalFilename.isEmpty
            && sizeBytes > 0
    }
}

struct VolunteerApplicationInput: Codable, Equatable {
    let confirmsAge18OrOlder: Bool
    let acceptedConductVersion: String
    let motivation: String
    let evidence: [VolunteerEvidenceReference]

    var isReadyToSubmit: Bool {
        hasRequiredIdentityDetails
            && !evidence.isEmpty
            && evidence.allSatisfy(\.hasUsableReference)
    }

    var hasRequiredIdentityDetails: Bool {
        confirmsAge18OrOlder
            && !acceptedConductVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !motivation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct RoleOnboardingProfile: Equatable {
    let displayName: String
    let role: UserRole
    let teacherAffiliation: TeacherAffiliation?
    let volunteerApplication: VolunteerApplicationInput?

    var normalizedDisplayName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasRequiredRoleDetails: Bool {
        switch role {
        case .student:
            return teacherAffiliation == nil && volunteerApplication == nil
        case .teacher:
            return teacherAffiliation?.isValidSelfDeclaration == true
                && volunteerApplication == nil
        case .volunteer:
            return teacherAffiliation == nil
                && volunteerApplication?.hasRequiredIdentityDetails == true
        }
    }
}

struct AccountRegistration: Equatable {
    let email: String
    let password: String
    let displayName: String
    let role: UserRole
    let teacherAffiliation: TeacherAffiliation?
    let volunteerApplication: VolunteerApplicationInput?

    var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var normalizedDisplayName: String {
        onboardingProfile.normalizedDisplayName
    }

    var hasRequiredRoleDetails: Bool {
        onboardingProfile.hasRequiredRoleDetails
    }

    var onboardingProfile: RoleOnboardingProfile {
        RoleOnboardingProfile(
            displayName: displayName,
            role: role,
            teacherAffiliation: teacherAffiliation,
            volunteerApplication: volunteerApplication
        )
    }
}

enum FederatedIdentityCredential: Equatable {
    case google(idToken: String, accessToken: String)
    case apple(idToken: String, rawNonce: String)

    var provider: AccountIdentityProvider {
        switch self {
        case .google:
            return .google
        case .apple:
            return .apple
        }
    }
}

struct EducationInstitutionCatalogSeed: SeedLoadable, Equatable {
    static let seedFileName = "education_institutions_seed"

    let schemaVersion: Int
    let academicYear: String
    let institutions: [EducationInstitution]
}
